# Latency Arbitrage Bot – Python

## Quick Start

```bash
cd python
cp .env.example .env          # add your API keys
pip install -r requirements.txt
python main.py               # demo mode (market data only)
```

## Demo vs Production

| Feature | Demo | Production |
|---------|------|------------|
| Market data | ✅ | ✅ |
| Order placement | ❌ | ✅ |
| Balance | ❌ | ✅ |

## Key Files

- `venues/kalshi.py` – Production venue (requires R/W API key)
- `venues/demo.py`  – Demo venue (market data only)
- `config/__init__.py` – Shared rate-limiter + signer

## Adding Venues

1. Create `venues/<name>.py` with `Venue` class
2. Add to `venues/__init__.py`
3. Update `main.py` import
