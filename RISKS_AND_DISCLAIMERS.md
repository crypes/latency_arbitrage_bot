# Risks & Disclaimers

> **⚠️ NOT FINANCIAL ADVICE. FOR EDUCATIONAL AND RESEARCH PURPOSES ONLY.**
> **YOU ARE RESPONSIBLE FOR YOUR OWN DECISIONS. SEEK INDEPENDENT FINANCIAL AND LEGAL COUNSEL BEFORE USING ANY CODE IN THIS REPOSITORY.**

---

## 1. General Disclaimers

- **Not financial advice:** Nothing in this repository constitutes, or should be construed as, financial, investment, legal, or tax advice. This is experimental research software.
- **Past performance ≠ future results:** Backtested, simulated, or paper-traded results do not guarantee real-world profitability. Markets adapt; edges disappear.
- **Possibility of total capital loss:** Trading prediction markets and deploying automated trading systems involves substantial risk of loss. You can lose your entire stake.
- **No guarantees:** The maintainers make no representations or warranties of any kind, express or implied, about the completeness, accuracy, or reliability of this software.
- **Use at your own risk:** Any use of the code, strategies, or concepts described herein is solely at your own risk.

---

## 2. Regulatory Considerations by Venue

### Polymarket
- **CFTC-regulated (US return, November 2025):** Polymarket secured amended CFTC approval to allow US retail access through futures commission merchants and brokerages starting 2026.
- **US Persons:** May face restrictions depending on state of residence and how access is structured. Verify your eligibility before trading.
- **EIP-712 on-chain orders:** All orders are recorded on Polygon PoS. Regulatory bodies may scrutinize on-chain trading activity.
- **Dynamic taker fees (1.80% on BTC/ETH, from March 30, 2026):** Significantly impacts profitability of high-frequency taker strategies.

### Kalshi
- **CFTC-regulated exchange:** KalshiEX LLC is a designated contract market (DCM) regulated by the CFTC.
- **Retail access:** Kalshi is open to US persons (excluding DC, HI, LA, ME, NM, ND, TN, VT, WV, WY and under-18). Your location in Austin, TX is **allowed**.
- **No trading API for retail:** The `kalshi-python` SDK and exchange API are institutional-access only (minimum $10M AUM or equivalent). **Retail users cannot programmatically trade Kalshi.**
- **Legal advantage:** CFTC regulation means Kalshi is the most legally transparent venue for US users.

### Coinbase Predictions (Kalshi-Powered)
- **No public API:** Coinbase Predictions has no public trading API. Only Coinbase can place markets on behalf of users.
- **This venue cannot be automated** with retail-accessible tools.

---

## 3. Trading & Technical Risks

| Risk | Description |
|------|-------------|
| **Edge compression** | Competitor bots, tighter spreads, and Polymarket's repricing speed improvements have reduced the latency arbitrage window significantly since late 2025. |
| **Fee erosion** | 1.80% Polymarket taker fee on BTC/ETH means a >1.80% edge is required just to break even on a round-trip. |
| **Execution latency** | Sub-100ms execution requires co-location or low-latency VPS near venue infrastructure. Retail internet connections (~20–50ms round-trip to Polygon RPC) are likely too slow for taker strategies. |
| **Oracle lag** | Chainlink and Polymarket's RTDS relay may lag behind Binance/Coinbase by 500ms–2s. The bot's edge is built on this lag; if oracles speed up, the edge disappears. |
| **GC pauses** | The BEAM VM's garbage collector can cause 10–100ms pauses at inopportune moments. Use `:erlang.system_info(:garbage_collection_info)` and dirty schedulers for latency-sensitive paths. |
| **Polygon RPC reliability** | Transaction submission depends on Polygon RPC. An RPC outage or rate limit can miss critical trade windows. Use multiple RPC providers. |
| **Order book toxicity** | High-frequency taker orders in a CLOB may be treated as MEV / inventory toxicity, resulting in adverse fills. |
| **Signature replay** | EIP-712 signatures must include a nonce. Replay protection is the developer's responsibility. |
| **Reorg / oracle manipulation** | On-chain oracles can be manipulated by miners/validators in extreme conditions. |

---

## 4. Operational Risks

| Risk | Description |
|------|-------------|
| **Key management** | Storing private keys in environment variables or application config is insecure for production. Use a hardware security module (HSM), Geth keystore, or key management service (KMS). |
| **Single point of failure** | The current architecture has a single PriceOracle GenServer. Add redundancy for production. |
| **Daily loss limit bypass** | The `:daily_loss_limit` circuit breaker is in-memory only. A crash and restart resets it. Use persistent storage for kill switches. |
| **Network partition** | If the VPS loses internet during an open position, the bot cannot close it. Use a second monitoring process on a separate network path. |
| **Clock skew** | System clocks that drift can cause order expiry and timing mismatches. Use NTP with a low-drift source. |

---

## 5. Jurisdiction-Specific (Texas, USA)

- Texas is **NOT** one of the states that ban Kalshi.
- Texas has no state-level prediction market regulations beyond CFTC jurisdiction.
- Polymarket's CFTC approval means Texas residents can access it through proper channels (FCM/brokerage in 2026+).
- **Tax treatment:** Gains from prediction market trading are likely taxable as ordinary income or capital gains in the US. Consult a US tax professional.
- **No consumer protection:** Texas does not currently regulate prediction market trading. There is no state-level recourse if a platform fails.

---

## 6. Responsible Trading Guidance

1. **Start with paper trading** — all strategies should be validated with zero real capital for a minimum of 7 days / 200 trades before going live.
2. **Never risk more than you can afford to lose** — treat this as speculative capital, not savings.
3. **Implement kill switches** — hard stop losses and daily loss limits are non-negotiable.
4. **Diversify** — do not deploy more than 10–20% of your total trading capital in any single automated strategy.
5. **Stay informed** — regulatory, fee, and rule changes can invalidate a strategy overnight.
