import Config

config :latency_arbitrage_bot, :kalshi,
  key_id: "d2d7dc84-fda7-4d8d-a8dc-f4896f9ba63b",
  private_key: System.get_env("KALSHI_PRIVATE_KEY") ||
    File.read!("config/kalshi_private_key.pem") |> String.trim()

config :latency_arbitrage_bot, :polymarket,
  private_key: System.get_env("POLYMARKET_PRIVATE_KEY") ||
    "YOUR_POLYMARKET_SIGNING_KEY_HEX"

# Production read-only key (no private key needed for reads)
config :latency_arbitrage_bot, :kalshi_prod,
  key_id: "6e412beb-8b0e-4a2f-9a1b-6bb2c8f0d3a4",
  api_url: "https://api.kalshi.com"
