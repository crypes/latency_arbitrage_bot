import asyncio, time, base64, json
import httpx
from latency_arbitrage.rate_limiter import rate_limited
from latency_arbitrage.config import KALSHI_KEY_ID, KALSHI_PRIVATE_KEY_PEM, BASE_URL

API_BASE = BASE_URL

class KalshiAdapter:
    def __init__(self):
        self.key_id = KALSHI_KEY_ID
        self.pem = KALSHI_PRIVATE_KEY_PEM
        from latency_arbitrage.rate_limiter import RateLimiter
        self.limiter = RateLimiter(9.5)

    def _sign(self, method, path, ts, body=""):
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import padding
        from cryptography.hazmat.backends import default_backend
        msg = f"{ts}{method.upper()}{path}{body}".encode()
        key = serialization.load_pem_private_key(
            self.pem.encode(), password=None, backend=default_backend())
        sig = key.sign(msg, padding.PKCS1v15(), hashes.SHA256())
        return base64.b64encode(sig).decode()

    def _headers(self, method, path, body=""):
        ts = str(int(time.time()))
        return {
            "KALSHI-KEY-ID": self.key_id,
            "KALSHI-SIGNATURE": self._sign(method, path, ts, body),
            "KALSHI-TIMESTAMP": ts,
            "Content-Type": "application/json",
        }

    def _get(self, path):
        h = self._headers("GET", path)
        r = httpx.get(API_BASE + path, headers=h, timeout=10.0)
        r.raise_for_status()
        return r.json()

    @rate_limited
    async def get_market(self, market_id):
        return self._get(f"/markets/{market_id}")

    @rate_limited
    async def get_orderbook(self, market_id):
        return self._get(f"/markets/{market_id}/orderbook")

    @rate_limited
    async def list_markets(self, series_ticker, limit=100):
        return self._get(f"/markets?series_ticker={series_ticker}&limit={limit}")

    @rate_limited
    async def get_events(self, series_ticker):
        return self._get(f"/events?series_ticker={series_ticker}&limit=1")

    @rate_limited
    async def get_balance(self):
        return self._get("/portfolio/balance")
