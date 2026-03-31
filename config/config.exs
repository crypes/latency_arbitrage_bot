import Config

# ─── Runtime environment ─────────────────────────────────────────────────────
# 3 environments: :dev (default), :test, :prod

config :latency_arbitrage_bot,
  env: :dev,
  log_level: :debug

# ─── Polymarket ───────────────────────────────────────────────────────────────
config :latency_arbitrage_bot, :polymarket,
  clob_ws: "wss://clob.polymarket.com/ws",
  clob_rest: "https://clob.polymarket.com",
  rpc_url: System.get_env("POLYGON_RPC_URL", "https://polygon-rpc.com"),
  private_key: System.get_env("POLYMARKET_PRIVATE_KEY"),
  # Dynamic taker fee schedule (effective March 30, 2026):
  # https://bitcoinethereumnews.com/tech/polymarket-expands-taker-fees/
  fee_schedule: %{
    crypto: %{peak: 0.018, categories: ["BTC", "ETH"]},   # 1.80% peak
    economics: %{peak: 0.015, categories: []},           # 1.50% peak
    politics: %{peak: 0.010, categories: []},             # 1.00% peak
    default: 0.0
  }

# ─── Upstream price feeds ──────────────────────────────────────────────────────
config :latency_arbitrage_bot, :feeds,
  binance_ws: "wss://stream.binance.com:9443/ws/!miniTicker@arr",
  coinbase_ws: "wss://advanced-trade-ws.coinbase.com",
  kraken_ws: "wss://ws.kraken.com",
  # Latency budget (ms): total pipeline must stay under this
  latency_budget_ms: 80

# ─── Edge Engine ───────────────────────────────────────────────────────────────
config :latency_arbitrage_bot, :edge_engine,
  thresholds: %{
    BTC: 0.008,   # 0.8% minimum edge before considering a trade
    ETH: 0.008
  },
  window_ms: 500  # spike must persist 500ms before triggering

# ─── Risk Manager ─────────────────────────────────────────────────────────────
config :latency_arbitrage_bot, :risk,
  max_notional_per_symbol: Decimal.new(50),   # $50 per leg
  max_total_notional: Decimal.new(200),       # $200 across all positions
  max_trades_per_minute: 10,
  daily_loss_limit: Decimal.new(-20),         # stop at -$20 daily P&L
  max_position_age_ms: 15 * 60 * 1000

# ─── Telemetry / Observability ─────────────────────────────────────────────────
config :latency_arbitrage_bot, :telemetry,
  enabled: true,
  export_interval_ms: 30_000

# ─── Dev-only settings ─────────────────────────────────────────────────────────
if config_env() == :dev do
  config :latency_arbitrage_bot, :dev, forcePaperTrading: true
end
