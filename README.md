# Latency Arbitrage Bot — Polymarket × Kalshi × Coinbase

> Multi-venue prediction market latency arbitrage in **pure Elixir/OTP** (no Python, no Node).

**⚠️ NOT FINANCIAL ADVICE. See [RISKS_AND_DISCLAIMERS.md](./RISKS_AND_DISCLAIMERS.md) before using.**

---

## Project Status

| Phase | Status | Description |
|-------|--------|-------------|
| 1 — Feasibility Study | ✅ Complete | [PHASE_1_FEASIBILITY.md](./PHASE_1_FEASIBILITY.md) |
| 2 — Architecture & Scaffold | 🔨 In Progress | This repo |
| 3 — Implementation & Paper Trade | ⏳ Pending | — |
| 4 — Validation & Packaging | ⏳ Pending | — |

**Current verdict:** Polymarket taker-only strategy has marginal edge after the March 30, 2026 fee change (1.80% taker). Paper trading required to validate. Kalshi/Coinbase not accessible via retail API.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              LatencyArbitrageBot (OTP App)          │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌─────────────────┐     ┌────────────────────┐     │
│  │  PriceOracle    │────▶│   EdgeEngine       │     │
│  │  (GenServer)    │     │   (GenServer)      │     │
│  └────────┬────────┘     └─────────┬──────────┘     │
│           │                        │                │
│   Binance │ Coinbase WS           │ risk checks    │
│   feeds   │                       ▼                │
│           │              ┌────────────────────┐    │
│           │              │   RiskManager      │    │
│           │              │   (GenServer)      │    │
│           │              └─────────┬──────────┘    │
│           │                        │              │
│           │         ┌───────────────┴────────┐     │
│           │         ▼                        ▼     │
│  ┌────────┴───┐                         ┌──┴──┐  │
│  │ Polymarket │                         │ KALSHI│  │
│  │ Adapter    │                         │future│  │
│  └────────────┘                         └──────┘  │
│   Polygon CLOB WS+REST                      │
│   EIP-712 signing                           │
└─────────────────────────────────────────────────┘
```

## Getting Started

### Prerequisites

- **Elixir 1.14+** / **Erlang/OTP 25+**
- **Polygon RPC endpoint** (Alchemy, Infura, or self-hosted)
- **Polygon wallet** with USDC on Polygon PoS
- **Kalshi institutional account** (for future Phase 3)

### Setup

```bash
# Clone
git clone https://github.com/crypes/latency_arbitrage_bot.git
cd latency_arbitrage_bot

# Install dependencies
mix deps.get

# Configure environment
cp .env.example .env
# Edit .env with your private key and RPC URL

# Validate syntax
mix compile --warnings-as-errors

# Run tests
mix test

# Start (paper trading by default)
mix run --no-halt
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `POLYGON_RPC_URL` | Polygon RPC endpoint (required) |
| `POLYMARKET_PRIVATE_KEY` | Wallet private key (hex, no 0x prefix recommended) |
| `POLYMARKET_FUNDER_ADDR` | Optional funder address for gas abstraction |

---

## Project Structure

```
latency_arbitrage_bot/
├── lib/
│   └── latency_arbitrage_bot/
│       ├── application.ex          # OTP Application + supervision tree
│       ├── core/                   # Strategy core (future)
│       ├── data/                   # Data pipeline: PriceOracle, EdgeEngine, RiskManager
│       ├── support/                # Telemetry, HTTP endpoint, utilities
│       └── venues/                 # Venue adapters
│           ├── polymarket/         # Polymarket CLOB adapter + EIP-712 signer
│           ├── kalshi/             # Kalshi adapter (institutional only)
│           └── coinbase/           # Coinbase Predictions (no public API)
├── config/
│   ├── config.exs                  # Base config + fee schedule
│   ├── dev.exs
│   └── prod.exs
├── test/
│   ├── latency_arbitrage_bot/      # Unit tests
│   └── support/                    # Test fixtures
├── mix.exs                         # Project definition + dependencies
└── RISKS_AND_DISCLAIMERS.md        # Full risk disclosure (read this first)
```

---

## Fee Schedule (Effective March 30, 2026)

| Market Category | Taker Fee (Peak) | Maker Rebate |
|----------------|-----------------|--------------|
| BTC / ETH Crypto | 1.80% | Rebated to MMs |
| Economics | 1.50% | Rebated to MMs |
| Politics | 1.00% | Rebated to MMs |
| Other / Geopolitics | 0% | — |

*Source: [Polymarket Fee Expansion, March 2026](https://bitcoinethereumnews.com/tech/polymarket-expands-taker-fees-to-8-new-market-categories-starting-march-30-2026/)*

---

## License

MIT — See [LICENSE](./LICENSE).
