"""Application configuration - loaded from environment."""
import os

def load_config():
    """Load all config from environment variables."""
    return {
        # Mode
        "mode": os.getenv("APP_MODE", "dry_run"),  # dry_run | live

        # Logging
        "log_level": os.getenv("LOG_LEVEL", "INFO"),

        # Risk
        "max_position_size": float(os.getenv("MAX_POSITION_SIZE", "50.0")),
        "max_daily_loss": float(os.getenv("MAX_DAILY_LOSS", "25.0")),
        "bankroll": float(os.getenv("BANKROLL", "500.0")),

        # Edge engine
        "min_edge_bps": float(os.getenv("MIN_EDGE_BPS", "50.0")),

        # Rate limiting
        "max_rps": float(os.getenv("MAX_RPS", "5.0")),
    }
