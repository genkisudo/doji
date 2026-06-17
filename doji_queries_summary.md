# DojiFunded On-Chain Analytics — Query Summary

**Chain:** Arbitrum | **As of:** 2026-06-13

## Key Addresses

| Role | Address |
|---|---|
| Deposit reserve (traders fund here) | `0x98D4077A5C448529d20D233d36780e3A99dB541E` |
| Fee wallet | `0xF5D86eA2457d8b408E6e63affBF0E40E9AB646c1` |
| DojiTradeNFT contract (DOJI-TRADE) | `0xcac4cbbcb921512dbd327b23ab5771125e7c1ff1` |
| Real USDC (Circle native, 6 dec) | `0xaf88d065e77c8cC2239327C5EDb3A432268e5831` |
| Spoof "UṢDC" token (excluded) | `0xc09978783365361538c50c1036f3958509886418` |

> **Spoof warning:** A fake token with a Unicode dotted-S (`UṢDC`) also sends to the reserve. All deposit queries explicitly filter to the real Circle USDC contract address only.

---

## Queries

### Q1 — USDC Deposits to Reserve (2026)
- **File:** `queries/q1_usdc_deposits_2026.sql`
- **Dune ID:** [7717333](https://dune.com/queries/7717333)
- **What it does:** Counts all real USDC deposits into the deposit reserve in calendar year 2026 — number of transfers, total USDC sum, and unique depositor addresses.
- **Live result (2026-06-13):** 42 deposits · **1,643.46 USDC** · 31 unique depositors

### Q2 — Unique Traders
- **File:** `queries/q2_unique_traders.sql`
- **Dune ID:** [7717347](https://dune.com/queries/7717347)
- **What it does:** Counts unique traders as distinct recipients of trade-proof NFT mints from the DojiTradeNFT contract. One mint = one closed trade (proof receipt, not a tradeable NFT). Works via raw ERC721 events — no ABI decoding required.
- **Live result (2026-06-13):** **35 unique traders** · 374 total closed trades · platform launched 2026-05-25

### Q3 — Platform Headline Metrics
- **File:** `queries/q3_headline_metrics.sql`
- **Dune ID:** [7717396](https://dune.com/queries/7717396)
- **What it does:** Single-row summary combining trade counts (from NFT mints) and deposit data (from USDC transfers). Designed as a public/marketing metric card — all figures in one query.
- **Live result (2026-06-13):** 374 trades · 35 traders · 42 deposits · 31 depositors · 1,643.46 USDC

### Q4 — Daily Trades & Trader Growth
- **File:** `queries/q4_daily_trades_growth.sql`
- **Dune ID:** [7717399](https://dune.com/queries/7717399)
- **What it does:** Day-by-day breakdown of closed trades and new traders (first-ever trade), plus running cumulative totals. Suitable for a line chart showing platform growth since launch.
- **Columns:** `day`, `trades`, `new_traders`, `cumulative_trades`, `cumulative_traders`

---

## Design Notes

All four queries are **decode-independent** — they run entirely on raw `nft.transfers` and `erc20_arbitrum.evt_Transfer` events. No ABI decoding is needed.

Once the DojiTradeNFT contract (`0xcac4…1ff1`) or the main trading contract is decoded on Dune, Q2/Q3/Q4 can be enriched with the `TradeMinted` event fields from the contract:

```
realizedPnl, positionSizeUsd, leverage, symbol, entryPrice, exitPrice,
requestedPrice, feesPaid, fundingPayment, breachedRule, accountId
```

This would unlock win rates, PnL distributions, leverage heatmaps, per-symbol volumes, slippage (requestedPrice vs exitPrice), and total fees collected — fully on-brand with the Explorer's "public verifiability" story.
