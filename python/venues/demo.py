"""Kalshi demo venue."""
from latency_arbitrage_python.config import KalshiDemoAdapter

class DemoKalshiVenue:
    """Demo environment – market data only, no trading."""
    def __init__(self, rate: float = 9.0):
        self._adapter = KalshiDemoAdapter()
        self.name = "kalshi-demo"

    async def connect(self):
        pass  # no connection needed

    async def disconnect(self):
        await self._adapter.close()

    async def get_markets(self, series_ticker: str = "KXBTC15M"):
        return await self._adapter.get_markets(series_ticker)

    async def get_market(self, ticker: str):
        return await self._adapter.get_market(ticker)

    async def get_orderbook(self, ticker: str):
        return await self._adapter.get_orderbook(ticker)

    async def place_order(self, **kwargs):
        return None

    async def get_balance(self) -> None:
        return None
