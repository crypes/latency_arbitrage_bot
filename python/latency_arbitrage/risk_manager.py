"""Position and loss-limit risk manager."""
import asyncio, logging
from dataclasses import dataclass
from datetime import datetime, timezone

logger = logging.getLogger(__name__)


@dataclass
class RiskConfig:
    max_positions: int = 3
    max_position_size: float = 50.0       # USD per position
    max_daily_loss: float = 25.0           # USD
    max_drawdown_pct: float = 0.02         # 2% of bankroll
    bankroll: float = 500.0               # starting capital


class RiskManager:
    """Tracks P&L, enforces loss limits, approves/rejects trades."""

    def __init__(self, config: RiskConfig):
        self.config = config
        self._daily_pnl = 0.0
        self._peak_equity = config.bankroll
        self._equity = config.bankroll
        self._open_positions: dict = {}
        self._date = datetime.now(timezone.utc).date()

    def check_trade(self, market_id: str, price: float, size: float) -> tuple[bool, str]:
        """Returns (approved, reason). Call before placing any order."""
        today = datetime.now(timezone.utc).date()
        if today > self._date:
            self._daily_pnl = 0.0
            self._date = today
            logger.info("New trading day - P&L reset")

        cost = price * size
        if cost > self.config.max_position_size:
            return False, f"Position size ${cost:.2f} exceeds max ${self.config.max_position_size}"

        if len(self._open_positions) >= self.config.max_positions:
            return False, "Max open positions reached"

        if self._daily_pnl <= -self.config.max_daily_loss:
            return False, f"Daily loss limit ${self.config.max_daily_loss} hit"

        drawdown = (self._peak_equity - self._equity) / self._peak_equity
        if drawdown >= self.config.max_drawdown_pct:
            return False, f"Drawdown {drawdown*100:.1f}% exceeds {self.config.max_drawdown_pct*100:.0f}% limit"

        return True, "approved"

    def record_trade(self, market_id: str, side: str, price: float, size: float, pnl: float = 0.0):
        """Record a completed trade and update equity."""
        if side == "buy":
            self._open_positions[market_id] = {"price": price, "size": size}
            self._equity -= price * size
        else:
            if market_id in self._open_positions:
                del self._open_positions[market_id]
            self._equity += pnl

        self._equity += pnl
        self._peak_equity = max(self._peak_equity, self._equity)
        self._daily_pnl += pnl

        logger.info(
            "Trade recorded: %s %s %.4fx$%.2f pnl=$%.2f | equity=$%.2f daily=$%.2f",
            side, market_id, size, price, pnl, self._equity, self._daily_pnl
        )

    def status(self) -> dict:
        return {
            "equity": round(self._equity, 2),
            "daily_pnl": round(self._daily_pnl, 2),
            "open_positions": len(self._open_positions),
            "peak_equity": round(self._peak_equity, 2),
            "drawdown_pct": round((self._peak_equity - self._equity) / self._peak_equity * 100, 2),
        }
