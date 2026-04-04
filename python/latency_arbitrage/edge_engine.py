"""Cross-venue edge detection and signal generation."""
import asyncio, logging
from dataclasses import dataclass, field
from typing import Optional

logger = logging.getLogger(__name__)


@dataclass
class EdgeSignal:
    """A detected trading edge."""
    timestamp: float
    market_id: str
    venue: str
    yes_price: float
    edge_bps: float  # basis points vs fair value
    confidence: float
    expires_at: float


@dataclass
class EdgeEngineConfig:
    min_edge_bps: float = 50.0   # minimum edge to act (bps)
    max_age_ms: int = 500        # max age of signal before expiry
    lookback_seconds: int = 60     # rolling window for consensus


class EdgeEngine:
    """Detects and validates trading edges across venues."""

    def __init__(self, config: EdgeEngineConfig):
        self.config = config
        self._signals: list[EdgeSignal] = []
        self._last_consensus: Optional[dict] = None

    async def evaluate(self, market_data: dict) -> Optional[EdgeSignal]:
        """
        Evaluate market data and return a signal if edge is found.
        Returns None if no actionable edge.
        """
        now = asyncio.get_event_loop().time()

        # Age out old signals
        self._signals = [s for s in self._signals if now - s.timestamp < self.config.max_age_ms / 1000]

        yes_price = market_data.get("yes_price")
        market_id = market_data.get("market_id", "unknown")
        venue = market_data.get("venue", "unknown")

        if yes_price is None:
            return None

        # Conservative: only generate signal if price is extreme (near 0 or near 1)
        # and we have enough historical data to trust the edge
        if not (yes_price < 0.15 or yes_price > 0.85):
            return None

        confidence = self._compute_confidence(market_id, now)
        if confidence < 0.6:
            return None

        # Compute rough edge based on distance from 0.5
        fair_value = 0.5
        edge_bps = abs(yes_price - fair_value) / fair_value * 10000

        if edge_bps < self.config.min_edge_bps:
            return None

        signal = EdgeSignal(
            timestamp=now,
            market_id=market_id,
            venue=venue,
            yes_price=yes_price,
            edge_bps=edge_bps,
            confidence=confidence,
            expires_at=now + self.config.max_age_ms / 1000,
        )
        self._signals.append(signal)
        return signal

    def _compute_confidence(self, market_id: str, now: float) -> float:
        """Confidence based on number of recent signals for this market."""
        recent = [s for s in self._signals
                  if s.market_id == market_id and now - s.timestamp < self.config.lookback_seconds]
        if len(recent) == 0:
            return 0.0
        return min(1.0, len(recent) / 5.0)

    async def run_loop(self, venues: list):
        """
        Main loop: poll venues, detect edges, emit signals.
        venues: list of venue adapters with .get_markets() and .get_market(market_id)
        """
        logger.info("Edge engine loop starting")
        while True:
            try:
                for venue in venues:
                    markets = await venue.list_markets(limit=50)
                    for mkt in markets:
                        signal = await self.evaluate({**mkt, "venue": venue.name})
                        if signal:
                            logger.info(
                                "EDGE DETECTED: %s %s price=%.4f edge=%.1fbps confidence=%.2f",
                                signal.venue, signal.market_id,
                                signal.yes_price, signal.edge_bps, signal.confidence
                            )
                await asyncio.sleep(1.0)
            except Exception as e:
                logger.error("Edge loop error: %s", e)
                await asyncio.sleep(5)
