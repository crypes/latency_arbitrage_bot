# Latency Arbitrage Bot — Python Edition

Async Python rewrite of the multi-venue latency arbitrage engine for prediction markets.

## Architecture

```
latency_arbitrage/
  config.py          # Env var config + validation
  data/
    price_oracle.py   # Unified price feed (all venues)
    edge_engine.py    # Spread + momentum signal detection
    risk_manager.py   # Position sizing + circuit breakers
  venues/
    kalshi/
      adapter.py     # Kalshi REST + WS adapter (production)
      signer.py       # RSA-256 SHA-256 request signer
    polymarket/
      adapter.py     # Polymarket CLOB REST + WebSocket adapter
    coinbase/         # Coinbase Predictions (stub — not yet active)
  execution/
    order_executor.py  # Venue-agnostic async order placer
  cli.py             # CLI entry point
```

## Status

| Venue         | API Access | Live Data | Notes                                         |
|---------------|-----------|-----------|-----------------------------------------------|
| Kalshi Demo   | ✅        | ✅        | `demo-api.kalshi.com` — synthetic markets    |
| Kalshi Prod   | ✅        | ✅        | `KXBTC15M` series found, markets `initialized` |
| Polymarket    | ⚠️        | ⚠️        | Needs CLOB credentials                       |
| Coinbase      | 🔜       | 🔜       | Not yet available                            |

## Quick Start

```bash
# Install deps
pip install httpx websockets python-dotenv cryptography

# Configure (copy and fill in)
cp .env.example .env

# Run
python -m latency_arbitrage
```

## API Base URLs

- **Kalshi Demo:** `https://demo-api.kalshi.com`
- **Kalshi Production:** `https://api.elections.kalshi.com`
- **Polymarket:** `https://clob.polymarket.com`

## Key Findings (Phase 1)

- KXBTC15M series confirmed active in production
- All BTC markets are in `initialized` status (awaiting open)
- Read-only key cannot place orders (write key required for trading)
- Polymarket 8% dynamic taker fees as of March 2026
- No Coinbase Predictions markets detected yet
