"""RSA-256 SHA-256 request signer for the Kalshi API."""
import hashlib, base64, time, ecdsa, httpx
from cryptography.hazmat.primitives import serialization


class KalshiSigner:
    def __init__(self, key_id: str, private_key_path: str):
        self.key_id = key_id
        self._pk = self._load_pem(private_key_path)

    @staticmethod
    def _load_pem(path: str):
        with open(path, "rb") as f:
            pem = f.read()
        return serialization.load_pem_private_key(pem, password=None)

    def _sign(self, message: str) -> str:
        from cryptography.hazmat.primitives.asymmetric import padding
        from cryptography.hazmat.primitives import hashes
        sig = self._pk.sign(
            message.encode(),
            padding.PKCS1v15(),
            hashes.SHA256()
        )
        return base64.b64encode(sig).decode()

    def sign_headers(self, method: str, path: str, body: str, ts: float) -> dict:
        ts_str = str(int(ts))
        msg = f"{ts_str}{method.upper()}{path}{body}"
        sig = self._sign(msg)
        return {
            "KALSHI-KEY-ID": self.key_id,
            "KALSHI-SIGNATURE": sig,
            "KALSHI-TIMESTAMP": ts_str,
            "Content-Type": "application/json",
        }

    async def sign_request(self, method: str, path: str, body: str = "") -> httpx.Request:
        ts = time.time()
        headers = self.sign_headers(method, path, body, ts)
        return httpx.Request(method.upper(), path, headers=headers, content=body.encode())
