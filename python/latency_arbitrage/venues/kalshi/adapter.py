"""Kalshi exchange adapter."""
import asyncio, httpx, time
from typing import Optional
from .signer import KalshiSigner


BASE_URL = "https://api.elections.kalshi.com"


class KalshiAdapter:

    def __init__(self, key_id: str, private_key_path: str, target_series: str = "KXBTC15M"):
        self.signer = KalshiSigner(key_id, private_key_path)
        self.target_series = target_series
        self.http = None

    # ── HTTP client ──────────────────────────────────────────────

    async def _start(self):
        self.http = httpx.AsyncClient(base_url=BASE_URL, timeout=10.0)

    async def _stop(self):
        if self.http:
            await self.http.aclose()

    async def _get(self, path: str, params: dict = None) -> dict:
        headers = self.signer.sign_headers("GET", path, "", time.time())
        resp = await self.http.get(path, headers=headers, params=params)
        resp.raise_for_status()
        return resp.json()

    # ── Market data ──────────────────────────────────────────────

    async def list_markets(self, status: str = None, limit: int = 20) -> list:
        params = {"series_ticker": self.target_series, "limit": limit}
        if status:
            params["status"] = status
        data = await self._get("/trade-api/v2/markets", params)
        return data.get("markets", [])

    async def get_market(self, ticker: str) -> dict:
        data = await self._get(f"/trade-api/v2/markets/{ticker}")
        return data.get("market", {})

    async def get_orderbook(self, ticker: str) -> dict:
        data = await self._get(f"/trade-api/v2/markets/{ticker}/orderbook")
        return data.get("orderbook_fp", {})

    async def get_series(self) -> dict:
        data = await self._get(f"/trade-api/v2/series/{self.target_series}")
        return data.get("series", {})

    # ── Execution ────────────────────────────────────────────────

    async def place_order(self, ticker: str, side: str, yes_bid: float, amount: int) -> dict:
        path = f"/trade-api/v2/markets/{ticker}/orders"
        body = {"side": side, "yes_bid": yes_bid, "amount": amount}
        headers = self.signer.sign_headers("POST", path, str(body), time.time())
        resp = await self.http.post(path, headers=headers, json=body)
        resp.raise_for_status()
        return resp.json()

    async def get_positions(self) -> list:
        data = await self._get("/trade-api/v2/portfolio/positions")
        return data.get("positions", [])
