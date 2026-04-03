"""Kalshi adapter using httpx with a 10-calls/sec rate limiter."""

import asyncio, time, base64
import httpx
from latency_arbitrage.rate_limiter import RateLimiter
from latency_arbitrage.config import KALSHI_KEY_ID, KALSHI_PRIVATE_KEY_PEM, get_base_url

def _sign(method, path, key_id, private_key_pem):
    from cryptography.hazmat.primitives import serialization, hashes
    from cryptography.hazmat.primitives.asymmetric import padding
    from cryptography.hazmat.backends import default_backend
    ts = str(int(time.time()))
    pk = serialization.load_pem_private_key(
        private_key_pem.encode(), password=None, backend=default_backend())
    msg = f"{key_id}{ts}{method.upper()}{path}".encode()
    sig = pk.sign(msg, padding.PKCS1v15(), hashes.SHA256())
    return {
        "KALSHI-KEY-ID": key_id,
        "KALSHI-TIMESTAMP": ts,
        "KALSHI-SIGNATURE": base64.b64encode(sig).decode(),
        "Content-Type": "application/json",
    }, ts

class RateLimitedHTTP:
    _client = None

    def __init__(self, calls_per_second=10.0):
        self._limiter = RateLimiter(calls_per_second)

    async def request(self, method, url, **kwargs):
        await self._limiter.acquire()
        if RateLimitedHTTP._client is None:
            RateLimitedHTTP._client = httpx.AsyncClient(http2=True, timeout=10.0)
        return await RateLimitedHTTP._client.request(method, url, **kwargs)

class KalshiAdapter:
    RATE = 10  # calls per second

    def __init__(self, env="prod"):
        self.key_id = KALSHI_KEY_ID
        self.private_key_pem = KALSHI_PRIVATE_KEY_PEM
        self.base_url = get_base_url(env)
        self.http = RateLimitedHTTP(self.RATE)

    def _headers(self, path):
        h, _ = _sign("GET", path, self.key_id, self.private_key_pem)
        return h

    async def _get(self, path):
        url = f"{self.base_url}{path}"
        resp = await self.http.request("GET", url, headers=self._headers(path))
        resp.raise_for_status()
        return resp.json()

    async def list_markets(self, series_ticker="KXBTC15M", status=None, limit=20):
        path = f"/trade-api/v2/markets?series_ticker={series_ticker}&limit={limit}"
        if status:
            path += f"&status={status}"
        return (await self._get(path)).get("markets", [])

    async def get_series(self, series_ticker):
        return await self._get(f"/trade-api/v2/series/{series_ticker}")

    async def get_market_orderbook(self, market_ticker):
        return await self._get(f"/trade-api/v2/markets/{market_ticker}/orderbook")

    async def get_balance(self):
        return await self._get("/trade-api/v2/portfolio/balance")

    async def place_order(self, market_ticker, side, price):
        path = "/trade-api/v2/orders"
        headers, _ = _sign("POST", path, self.key_id, self.private_key_pem)
        body = {"market_ticker": market_ticker, "side": side,
                "type": "limit", "price": price, "count": 1}
        url = f"{self.base_url}{path}"
        resp = await self.http.request("POST", url, headers=headers, json=body)
        resp.raise_for_status()
        return resp.json()

    async def get_fills(self, market_ticker=None, limit=50):
        params = f"?limit={limit}"
        if market_ticker:
            params += f"&market_ticker={market_ticker}"
        return (await self._get(f"/trade-api/v2/fills{params}")).get("fills", [])

def create(env="prod"):
    return KalshiAdapter(env=env)
