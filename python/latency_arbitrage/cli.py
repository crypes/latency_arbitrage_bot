"""CLI entry point for the latency arbitrage bot."""
import asyncio, logging, sys
from latency_arbitrage.config import load_config
from latency_arbitrage.kalshi.adapter import KalshiAdapter
from latency_arbitrage.edge_engine import EdgeEngine, EdgeEngineConfig
from latency_arbitrage.risk_manager import RiskManager, RiskConfig

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger(__name__)


async def main():
    cfg = load_config()
    risk_cfg = RiskConfig(
        max_position_size=cfg["max_position_size"],
        max_daily_loss=cfg["max_daily_loss"],
        bankroll=cfg["bankroll"],
    )
    edge_cfg = EdgeEngineConfig(min_edge_bps=cfg["min_edge_bps"])

    risk = RiskManager(risk_cfg)
    edge = EdgeEngine(edge_cfg)

    # Only one venue: Kalshi
    kalshi = KalshiAdapter(rate_limit=cfg["max_rps"])
    venues = [kalshi]

    logger.info("=== Latency Arbitrage Bot ===")
    logger.info("Mode: %s | Bankroll: $%.2f | Max pos: $%.2f",
                 cfg["mode"], cfg["bankroll"], cfg["max_position_size"])
    logger.info("Kalshi target: KXBTC15M (15-min BTC close markets)")
    logger.info("Rate limit: %.1f rps", cfg["max_rps"])

    if cfg["mode"] == "dry_run":
        logger.info("DRY RUN MODE - no real orders will be placed")

    # Show Kalshi status
    markets = await kalshi.list_markets(limit=10)
    logger.info("Kalshi connected. %d markets visible.", len(markets))

    for m in markets:
        logger.info("  %s | %s | status=%s",
                    m.get("market_ticker", ""),
                    m.get("status", ""),
                    m.get("question", "")[:60])

    # Run edge loop
    logger.info("\nEdge engine running. Ctrl+C to stop.")
    try:
        await edge.run_loop(venues)
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        logger.info("Risk status: %s", risk.status())

    print("\nFinal risk report:")
    for k, v in risk.status().items():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    asyncio.run(main())
