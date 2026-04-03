import time, httpx
from .signer import KalshiSigner

BASE_URL = "https://api.elections.kalshi.com/trade-api"


class KalshiAdapter:
    def __init__(self, key_id: str, private_key_path: str, target_series: str = "KXBTC15M"):
        self.key_id = key_id
        self.signer = KalshiSigner(key_id, private_key_path)
        self.target_series = target_series
        self.base_url = BASE_URL
        self._http: httpx.AsyncClient = None

    async def _ensure_http(self):
        if self._http is None:
            self._http = httpx.AsyncClient(base_url=self.base_url, timeout=10.0, http2=False)

    async def _get(self, path: str, params: dict = None) -> dict:
        await self._ensure_http()
        headers = self.signer.sign_headers("GET", path, "", time.time())
        resp = await self._http.get(path + ("?" + "&".join(f"{k}={v}" for k,v in (params or {}).items()) if params else ""), headers=headers)
        resp.raise_for_status()
        return resp.json()

    # ── Market data ────────────────────────────────────────────────

    async def list_markets(self, status: str = None, limit: int = 20) -> list:
        params = {"series_ticker": self.target_series, "limit": limit}
        if status:
            params["status"] = status
        data = await self._get("/v2/markets", params)
        return data.get("markets", [])

    async def get_market(self, ticker: str) -> dict:
        data = await self._get(f"/v2/markets/{ticker}")
        return data.get("market", {})

    async def get_orderbook(self, ticker: str) -> dict:
        data = await self._get(f"/v2/markets/{ticker}/orderbook")
        return data.get("orderbook_fp", {})

    async def get_series(self) -> dict:
        data = await self._get(f"/v2/series/{self.target_series}")
        return data.get("series", {})

    # ── Execution ──────────────────────────────────────────────────

    async def place_order(self, ticker: str, side: str, yes_bid: float, amount: int) -> dict:
        await self._ensure_http()
        path = f"/v2/markets/{ticker}/orders"
        body = {"side": side, "yes_bid": yes_bid, "amount": amount}
        headers = self.signer.sign_headers("POST", path, str(body), time.time())
        resp = await self._http.post(path, headers=headers, json=body)
        resp.raise_for_status()
        return resp.json()

    async def get_positions(self) -> list:
        data = await self._get("/v2/portfolio/positions")
        return data.get("positions", [])

    # ── Lifecycle ──────────────────────────────────────────────────

    async def close(self):
        if self._http:
            await self._http.aclose()
            self._http = None
