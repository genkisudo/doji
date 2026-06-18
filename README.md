# DojiFunded On-Chain Analytics

On-chain analytics workspace for [DojiFunded](https://dojifunded.com) — a decentralized prop trading platform on Arbitrum. All queries run against raw blockchain events, requiring no ABI decoding.

---

## Queries

| # | File | Dune ID | Description |
|---|------|---------|-------------|
| Q1 | [`queries/q1_usdc_deposits_2026.sql`](queries/q1_usdc_deposits_2026.sql) | [7717333](https://dune.com/queries/7717333) | USDC deposits to the reserve (2026) |
| Q2 | [`queries/q2_unique_traders.sql`](queries/q2_unique_traders.sql) | [7717347](https://dune.com/queries/7717347) | Unique traders via NFT mint recipients |
| Q3 | [`queries/q3_headline_metrics.sql`](queries/q3_headline_metrics.sql) | [7717396](https://dune.com/queries/7717396) | Single-row platform summary (trades, traders, accounts, deposits) |
| Q4 | [`queries/q4_daily_trades_growth.sql`](queries/q4_daily_trades_growth.sql) | [7717399](https://dune.com/queries/7717399) | Daily trades & cumulative trader growth |
| Q5 | [`queries/q5_fee_wallet_inflows.sql`](queries/q5_fee_wallet_inflows.sql) | — | Fee wallet USDC inflows (platform revenue) |
| Q6 | [`queries/q6_wallet_breakdown.sql`](queries/q6_wallet_breakdown.sql) | [7742479](https://dune.com/queries/7742479) | Per-wallet scorecard — paste any address, get PnL, win rate, leverage, accounts, pairs |
| Q7 | [`queries/q7_account_autopsy.sql`](queries/q7_account_autopsy.sql) | [7742886](https://dune.com/queries/7742886) | **Breach DNA** — per-account autopsy: cause of death, lifespan, fatal trade, PnL bled out |
| Q8 | [`queries/q8_breach_leaderboard.sql`](queries/q8_breach_leaderboard.sql) | [7742887](https://dune.com/queries/7742887) | **Breach DNA** — deadliest rules ranked: accounts killed, avg lifespan, fatal leverage, deadliest pair |

---

## Key Addresses

| Role | Address |
|------|---------|
| Deposit reserve A | `0x98D4077A5C448529d20D233d36780e3A99dB541E` |
| Deposit reserve B | `0x1016bC039A4aB6008d38EAD798b4E29361a2D6eA` |
| Fee wallet | `0xF5D86eA2457d8b408E6e63affBF0E40E9AB646c1` |
| DojiTradeNFT contract | `0xcac4cbbcb921512dbd327b23ab5771125e7c1ff1` |
| Real USDC (Circle, 6 dec) | `0xaf88d065e77c8cC2239327C5EDb3A432268e5831` |
| Spoof "UṢDC" — **excluded** | `0xc09978783365361538c50c1036f3958509886418` |

> **Spoof warning:** A fake token with a Unicode dotted-S (`UṢDC`) also transfers into the reserve. Every deposit query pins `contract_address` to the real Circle USDC to exclude it.

---

## How It Works

**Traders** are identified via the `DojiTradeNFT` contract — closing a trade mints a proof NFT to the trader's address. Counting distinct mint recipients gives unique traders; each mint is one closed trade.

**Deposits** are tracked through raw ERC-20 `Transfer` events into the deposit reserve, filtered to Circle-native USDC only.

**Revenue** is measured as USDC inflows to the fee wallet — no decoding required.

**Per-trade detail** (Q6) uses the decoded `dojifunded_arbitrum.dojitradenft_evt_trademinted` event table, available since 2026-06-17. It carries `realizedPnl`, `feesPaid`, `positionSizeUsd`, `leverage`, `symbol`, `accountId`, `isLong`, and more — one row per closed trade.

**Breach DNA** (Q7/Q8) analyzes what kills trading accounts. The `breachedRule` field — and the rest of the full trade struct — is *not* in the event; it lives only as JSON calldata in the decoded **call** table `dojifunded_arbitrum.dojitradenft_call_minttrade`. An account's cause of death is the breach rule on its last-ever trade. `daily_drawdown` is the dominant killer (~55% of accounts).

Q1–Q5 are decode-independent. All queries are partition-pruned (filtered from `2026-05-01`).

---

## Running Queries

```bash
export DUNE_API_KEY=your_key_here

# Run a query file
dune query run-sql --sql "$(cat queries/q3_headline_metrics.sql)" -o json

# Update a saved query
dune query update 7717333 --sql "$(cat queries/q1_usdc_deposits_2026.sql)" -o json
```

---

## Reference

- [`doji_docs.md`](doji_docs.md) — DojiFunded platform documentation
- [`doji_tradenft.sol`](doji_tradenft.sol) — Smart contract source and decimal conventions
- [`doji_queries_summary.md`](doji_queries_summary.md) — Query descriptions with live result snapshots
- [`sql_guide.md`](sql_guide.md) — DuneSQL efficiency guide
