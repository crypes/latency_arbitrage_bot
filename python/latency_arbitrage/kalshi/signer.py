"""RSA-SHA256 signer for Kalshi API authentication."""
import base64, hashlib, os, time
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.backends import default_backend

TSIG_ALGO = hashes.SHA256()


def _load_private_keyPem(pem_str: str):
    """Load an RSA private key from a PEM string."""
    # Strip any surrounding whitespace
    pem_str = pem_str.strip()
    if pem_str.startswith("-----BEGIN RSA PRIVATE KEY-----"):
        # PKCS#1 format - use load_ssh_key or generic loader
        try:
            from cryptography.hazmat.primitives.serialization import load_pem_private_key
            return load_pem_private_key(pem_str.encode(), password=None, backend=default_backend())
        except Exception:
            pass
    # Try PKCS#8 / openssl format
    from cryptography.hazmat.primitives.serialization import load_pem_private_key
    return load_pem_private_key(pem_str.encode(), password=None, backend=default_backend())


class KalshiSigner:
    """
    Signs Kalshi API requests using RSA-SHA256.

    Signs:    timestamp + method + path [+ body]
    Header:   KALSHI-KEY-ID, KALSHI-TIMESTAMP, KALSHI-SIGNATURE (Base64)
    Docs:     https://docs.kalshi.com/docs/authentication
    """

    def __init__(self, key_id: str, private_key: str):
        self.key_id = key_id
        self._key = _load_private_keyPem(private_key) if private_key else None

    def sign(self, message: str) -> str:
        """Create a raw RSA-SHA256 signature, return Base64-encoded string."""
        if self._key is None:
            raise ValueError("No private key loaded")
        sig = self._key.sign(message.encode(), padding.PKCS1v15(), TSIG_ALGO)
        return base64.b64encode(sig).decode()

    def sign_headers(
        self,
        method: str,
        path: str,
        timestamp: str,
        body: str = "",
    ) -> dict[str, str]:
        """
        Build the signed headers dict for an HTTP request.

        Canonical message: timestamp + method + path + body
        All parts are concatenated as plain strings.
        """
        if method == "GET":
            message = timestamp + "GET" + path
        else:
            import json
            body_str = json.dumps(body, separators=(",", ":")) if isinstance(body, dict) else body
            message = timestamp + method + path + body_str

        signature = self.sign(message) if self._key else "no_key"
        return {
            "KALSHI-KEY-ID": self.key_id,
            "KALSHI-TIMESTAMP": timestamp,
            "KALSHI-SIGNATURE": signature,
        }
