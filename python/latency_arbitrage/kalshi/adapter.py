"""Kalshi adapter with rate limiting and RSA signature auth."""
import asyncio, json, logging, time, random, httpx
from .signer import KalshiSigner

logger = logging.getLogger(__name__)
BASE_URL = "https://api.elections.kalshi.com/trade-api/v2"


class RateLimiter:
    def __init__(self, calls_per_second: float):
        self.rate = calls_per_second
        self.tokens = calls_per_second
        self.last_refill = time.monotonic()
        self.lock = asyncio.Lock()

    async def acquire(self):
        async with self.lock:
            now = time.monotonic()
            self.tokens = min(self.rate, self.tokens + (now - self.last_refill) * self.rate)
            self.last_refill = now
            if self.tokens < 1:
                await asyncio.sleep((1 - self.tokens) / self.rate + random.uniform(0, 0.05))
                self.tokens = 0
            else:
                self.tokens -= 1


class KalshiAdapter:
    name = "kalshi"

    def __init__(self, key_id: str = "", private_key: str = "", rate_limit: float = 5.0):
        self.key_id = key_id
        self.signer = KalshiSigner(key_id, private_key)
        self.rl = RateLimiter(rate_limit)
        self._http: httpx.AsyncClient = None

    async def _get_client(self) -> httpx.AsyncClient:
        if self._http is None:
            self._http = httpx.AsyncClient(
                base_url=BASE_URL,
                timeout=httpx.Timeout(10.0),
                limits=httpx.Limits(max_connections=10, max_keepalive_connections=5),
                http2=False,
            )
        return self._http

    async def _get(self, path: str) -> dict:
        await self.rl.acquire()
        client = await self._get_client()
        ts = str(int(time.time()))
        headers = self.signer.sign_headers("GET", path, ts)
        resp = await client.get(path, headers=headers)
        if resp.status_code == 429:
            raise Exception("Kalshi rate limit hit")
        if resp.status_code == 401:
            raise Exception("Kalshi auth failed (401)")
        if resp.status_code != 200:
            raise Exception(f"Kalshi API error {resp.status_code}: {resp.text[:200]}")
        return resp.json()

    async def list_markets(self, series_ticker: str = "KXBTC15M", limit: int = 50) -> list[dict]:
        data = await self._get(
            f"/markets?series_ticker={series_ticker}&limit={limit}"
        )
        return data.get("markets", [])

    async def get_market(self, market_ticker: str) -> dict:
        data = await self._get(f"/markets/{market_ticker}")
        return data.get("market", {})

    async def get_market_orderbook(self, market_ticker: str) -> dict:
        return await self._get(f"/markets/{market_ticker}/orderbook")

    async def place_order(
        self,
        market_ticker: str,
        side: str,
        price: float,
        size: int,
        dry_run: bool = True,
    ) -> dict:
        if dry_run:
            logger.info("[DRY] Would place: %s %s %.4f x%d", side, market_ticker, price, size)
            return {"order_id": "dry_run", "status": "simulated"}
        await self.rl.acquire()
        client = await self._get_client()
        body = {"market_ticker": market_ticker, "side": side, "yes_price": price, "size": size}
        path = "/orders"
        ts = str(int(time.time()))
        headers = self.signer.sign_headers("POST", path, ts, body)
        resp = await client.post(path, json=body, headers=headers)
        if resp.status_code != 200:
            raise Exception(f"Order failed {resp.status_code}: {resp.text[:200]}")
        return resp.json()

    async def close(self):
        if self._http:
            await self._http.aclose()
