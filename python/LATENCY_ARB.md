
## Demo Environment Findings (2026-04-04)

### What's supported on `https://demo-api.kalshi.co`

| Endpoint | Status | Notes |
|---|---|---|
| `GET /markets` | ✅ 200 | Market listing (public) |
| `GET /markets/{ticker}` | ✅ 200 | Single market data (public) |
| `GET /markets/{ticker}/orderbook` | ✅ 200 | Order book (public) |
| `GET /events` | ✅ 200 | Event listing (public) |
| `GET /series` | ✅ 200 | Series listing (public) |
| `GET /balance` | ❌ 404 | Not available in demo |
| `GET /positions` | ❌ 404 | Not available in demo |
| `POST /orders` | ❌ 404 | Not available in demo |
| `GET /orders` | ❌ 404 | Not available in demo |

### Auth mechanism (confirmed working)
- Base URL: `https://demo-api.kalshi.co/trade-api/v2`
- Headers: `KALSHI-ACCESS-KEY`, `KALSHI-ACCESS-SIGNATURE`, `KALSHI-ACCESS-TIMESTAMP`
- Signature: RSA-PSS (salt_length=DIGEST_LENGTH), message = `timestamp + METHOD + path`
- SDK: `kalshi_python_async` uses RSA-PSS (NOT PKCS1v15)
- The SDK hardcodes `api.elections.kalshi.com` — **not usable for demo**

### Demo = read-only. Trading requires production API.
