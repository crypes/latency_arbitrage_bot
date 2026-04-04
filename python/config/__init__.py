"""Kalshi Demo Adapter – market data via demo-api.kalshi.co."""
import os, time, base64, asyncio, httpx
from typing import Optional, List
from dataclasses import dataclass
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.backends import default_backend

BASE_URL = "https://demo-api.kalshi.co/trade-api/v2"

# Path to PEM key (set via KALSHI_DEMO_KEY_PATH, or use default)
_pem_path = os.environ.get("KALSHI_DEMO_KEY_PATH",
    os.path.join(os.path.dirname(__file__), "..", "config", "kalshi_demo_private_key.pem"))

_key_id = os.environ.get("KALSHI_DEMO_KEY_ID", "7099ccd8-c6cd-4286-affc-a6aa40b9519a")

# ── Signer ──────────────────────────────────────────────────────────────────

def _load_key():
    pem = open(os.environ.get("KALSHI_DEMO_PRIVATE_KEY_FILE", _pem_path)).read().strip()
    return serialization.load_pem_private_key(pem.encode(), password=None, backend=default_backend())

def _sign(ts: str, method: str, path: str) -> str:
    msg = ts + method + path
    key = _load_key()
    return base64.b64encode(
        key.sign(msg.encode(), padding.PKCS1v15(), hashes.SHA256())
    ).decode()

def _headers(method: str, path: str) -> dict:
    ts = str(int(time.time()))
    return {
        "KALSHI-ACCESS-KEY": os.environ.get("KALSHI_DEMO_KEY_ID", _key_id),
        "KALSHI-ACCESS-SIGNATURE": _sign(ts, method, path),
        "KALSHI-ACCESS-TIMESTAMP": ts,
    }

# ── Rate limiter ─────────────────────────────────────────────────────────────

class RateLimiter:
    def __init__(self, rate: float = 9.0):
        self.interval = 1.0 / rate
        self.last_call = 0.0

    async def wait(self):
        elapsed = time.monotonic() - self.last_call
        await asyncio.sleep(max(0, self.interval - elapsed) + 0.02)
        self.last_call = time.monotonic()

# ── Market ───────────────────────────────────────────────────────────────────

@dataclass
class Market:
    ticker: str
    close_time: str
    status: str
    yes_bid: Optional[float] = None
    yes_ask: Optional[float] = None
    volume: Optional[float] = None

# ── Adapter ─────────────────────────────────────────────────────────────────

class KalshiDemoAdapter:
    BASE_URL = BASE_URL
    RATE = 9.0

    def __init__(self, pem_path: Optional[str] = None):
        if pem_path:
            os.environ["KALSHI_DEMO_PRIVATE_KEY_FILE"] = pem_path
        self._client: Optional[httpx.AsyncClient] = None
        self._limiter = RateLimiter(self.RATE)

    async def _get(self, path: str) -> dict:
        await self._limiter.wait()
        if self._client is None:
            self._client = httpx.AsyncClient(base_url=self.BASE_URL, timeout=15.0)
        r = await self._client.get(path, headers=_headers("GET", path))
        r.raise_for_status()
        return r.json()

    async def close(self):
        if self._client:
            await self._client.aclose()

    async def get_markets(self, series_ticker: str = "KXBTC15M", status: Optional[str] = None) -> List[Market]:
        path = f"/markets?series_ticker={series_ticker}"
        if status:
            path += f"&status={status}"
        data = await self._get(path)
        return [self._m(m) for m in data.get("markets", [])]

    async def get_market(self, ticker: str) -> Optional[Market]:
        try:
            data = await self._get(f"/markets/{ticker}")
            return self._m(data.get("market", {}))
        except Exception:
            return None

    async def get_orderbook(self, ticker: str) -> dict:
        return await self._get(f"/markets/{ticker}/orderbook")

    def _m(self, m: dict) -> Market:
        ob = m.get("orderbook", {})
        return Market(
            ticker=m.get("ticker", ""),
            close_time=m.get("close_time", ""),
            status=m.get("status", ""),
            yes_bid=ob.get("yes_bid"),
            yes_ask=ob.get("yes_ask"),
            volume=m.get("volume"),
        )

    def format_market(self, m: Market) -> str:
        bid = f"{m.yes_bid:.4f}" if m.yes_bid else "N/A"
        ask = f"{m.yes_ask:.4f}" if m.yes_ask else "N/A"
        vol = str(m.volume) if m.volume else "N/A"
        return f"{m.ticker} | {m.status} | bid={bid} ask={ask} | vol={vol}"

    # ── Trading (not available via demo API – returns None) ─────────────────

    async def place_order(self, **kwargs) -> None:
        return None

    async def get_balance(self) -> None:
        return None
