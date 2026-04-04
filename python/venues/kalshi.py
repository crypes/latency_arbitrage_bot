"""Kalshi production venue."""
import os
from latency_arbitrage_python.kalshi import KalshiAdapter

class KalshiVenue:
    """Production Kalshi – requires R/W API key."""
    def __init__(self, rate: float = 9.0):
        self._adapter = KalshiAdapter(rate=rate)
        self.name = "kalshi-prod"

    async def connect(self):
        await self._adapter._ensure_client()

    async def disconnect(self):
        await self._adapter.close()

    async def get_markets(self, series_ticker: str = "KXBTC15M"):
        return await self._adapter.get_markets(series_ticker)

    async def get_market(self, ticker: str):
        return await self._adapter.get_market(ticker)

    async def get_orderbook(self, ticker: str):
        return await self._adapter.get_orderbook(ticker)

    async def place_order(self, market_ticker: str, side: str,
                          type_: str, price: float, count: int) -> dict:
        return await self._adapter.place_order(market_ticker, side, type_, price, count)

    async def get_balance(self) -> dict:
        return await self._adapter.get_balance()
