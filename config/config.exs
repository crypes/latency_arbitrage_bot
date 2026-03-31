import Config
import_config "secrets.exs"

# ─── Environment ──────────────────────────────────────────────────────────────
config :latency_arbitrage_bot, env: :dev

# ─── Logging ──────────────────────────────────────────────────────────────────
config :logger, level: :info

# ─── Polling / Timing ─────────────────────────────────────────────────────────
config :latency_arbitrage_bot, :polling,
  price_refetch_ms: 500,        # how often to re-fetch reference prices
  edge_check_ms: 100            # how often to evaluate cross-venue edges

# ─── Execution ─────────────────────────────────────────────────────────────────
config :latency_arbitrage_bot, :execution,
  slippage_tolerance_bps: 5,    # 5 basis points max adverse slippage
  order_timeout_ms: 2_000       # 2-second timeout for REST fill check

# ─── Risk limits (applied in RiskManager) ────────────────────────────────────
config :latency_arbitrage_bot, :risk,
  max_notional_per_symbol: 50,
  max_total_notional: 200,
  daily_loss_limit: -20,
  max_position_age_ms: 15 * 60 * 1_000

# ─── Polymarket ───────────────────────────────────────────────────────────────
config :latency_arbitrage_bot, :polymarket,
  env: :demo,
  base_url: "https://clob.polymarket.com",
  ws_url: "wss://clob.polymarket.com/ws",
  markets_url: "https://clob.polymarket.com/markets"

# ─── Kalshi ───────────────────────────────────────────────────────────────────
config :latency_arbitrage_bot, :kalshi,
  env: :demo,
  base_url: "https://demo-api.kalshi.co/trade-api/v2",
  ws_url: "wss://demo-api.kalshi.co/trade-api/v2/ws",
  signing_ts_offset_ms: -30_000   # Kalshi allows ±30 s clock skew
