# DojiFunded On-Chain Analytics — Query Summary

**Chain:** Arbitrum | **As of:** 2026-06-17

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

### Q5 — Fee Wallet USDC Inflows (Platform Revenue)
- **File:** `queries/q5_fee_wallet_inflows.sql`
- **Dune ID:** (not yet saved)
- **What it does:** Daily inflows of any token to the fee wallet (`0xF5D8…6c1`) — gross platform revenue from trading fees. Outputs a per-day time-series with daily and cumulative totals per token, suitable for both a summary card and a revenue chart. Fees arrive in a custom token (not USDC); unknown tokens fall back to their raw contract address.
- **Columns:** `day`, `token`, `contract_address`, `fee_tx_count`, `daily_amount`, `cumulative_amount`

### Q6 — Per-Wallet Trader Scorecard (parameterized)
- **File:** `queries/q6_wallet_breakdown.sql`
- **Dune ID:** [7742479](https://dune.com/queries/7742479)
- **Source:** `dojifunded_arbitrum.dojitradenft_evt_trademinted` (decoded, available from 2026-06-17)
- **Parameter:** `{{wallet_address}}` — paste any `0x` trader address in the Dune UI
- **What it does:** Single-row scorecard for a trader: realized PnL, fees, net PnL, trade count, number of accounts, pairs traded, win rate, total volume, average and max leverage, long/short split, best and worst trade, and first/last trade dates.
- **Columns:** `trader`, `total_trades`, `accounts`, `pairs_traded`, `realized_pnl_usd`, `total_fees_usd`, `net_pnl_usd`, `avg_pnl_per_trade_usd`, `best_trade_usd`, `worst_trade_usd`, `winning_trades`, `losing_trades`, `win_rate_pct`, `total_volume_usd`, `avg_position_usd`, `avg_leverage_x`, `max_leverage_x`, `long_trades`, `short_trades`, `first_trade`, `last_trade`, `active_days`

### Q7 — Account Autopsy ("Breach DNA", per-account)
- **File:** `queries/q7_account_autopsy.sql`
- **Dune ID:** [7742886](https://dune.com/queries/7742886)
- **Source:** `dojifunded_arbitrum.dojitradenft_call_minttrade` (decoded CALL — see Breach DNA note below)
- **What it does:** One row per trading account: its lifespan and cause of death. An account's killer is the `breachedRule` on its last-ever trade; soft mid-life breaches are survived. Includes the fatal trade, PnL bled out, leverage habits, and a future-proof `received_payout` flag.
- **Columns:** `account_id`, `trader`, `received_payout`, `status` (killed/active/dormant), `killed_by`, `total_trades`, `soft_breaches_survived`, `realized_pnl_usd`, `net_pnl_usd`, `total_fees_usd`, `max_leverage_x`, `avg_leverage_x`, `distinct_symbols`, `fatal_symbol`, `fatal_side`, `fatal_leverage_x`, `fatal_size_usd`, `fatal_pnl_usd`, `days_alive`, `first_trade_at`, `last_trade_at`
- **Live result (2026-06-17):** 156 accounts · **113 killed**, 29 active, 14 dormant · biggest blow-up −$2,881 (JTO-PERP, 5×, dead same day in 1 trade)

### Q8 — Breach Leaderboard ("Breach DNA", aggregate)
- **File:** `queries/q8_breach_leaderboard.sql`
- **Dune ID:** [7742887](https://dune.com/queries/7742887)
- **Source:** `dojifunded_arbitrum.dojitradenft_call_minttrade` (decoded CALL)
- **What it does:** One row per cause of death. Ranks which risk rules kill the most accounts and profiles each: avg lifespan, avg PnL at death, avg leverage on the fatal trade, and the deadliest pair.
- **Columns:** `cause_of_death`, `accounts`, `pct_of_accounts`, `avg_trades_alive`, `avg_days_alive`, `avg_realized_pnl_usd`, `avg_fatal_leverage_x`, `deadliest_symbol`
- **Live result (2026-06-17):** `daily_drawdown` **86 accounts (55%)**, avg −$478 at death · survived/active 43 (28%, +$4) · `single_trade_loss` 11 · `static_drawdown` 1 (slow death: 6 trades / 5 days, −$1,502)

---

## Breach DNA note (Q7/Q8) — the `breachedRule` gotcha

The `TradeMinted` **event** only emits a subset of the `TradeMetadata` struct and **drops `breachedRule`** (plus `openedAt`, `closedAt`, `fundingPayment`, `requestedPrice`, and the TP/SL fields). The full struct survives only as the JSON calldata `data` of the decoded **call** table `dojifunded_arbitrum.dojitradenft_call_minttrade`. Parse it with `json_extract_scalar(data, '$.field')`. The `breachedRule` sentinel for "no breach" is the string `'NA'`. Eval-vs-funded is **not** on-chain, so Q7/Q8 cover all accounts and use a `received_payout` flag (from the decoded `payoutvault_evt_payoutexecuted`, currently 0 payouts) as a funded/success proxy.

---

## Design Notes

Q1–Q5 are **decode-independent** — they run entirely on raw `nft.transfers` and `erc20_arbitrum.evt_Transfer` events. No ABI decoding is needed for these.

**The DojiTradeNFT contract is now decoded on Dune** (as of 2026-06-17) under the namespace `dojifunded_arbitrum`. Available tables:

- `dojifunded_arbitrum.dojitradenft_evt_trademinted` — one row per closed trade (subset of the struct; no `breachedRule`)
- `dojifunded_arbitrum.dojitradenft_evt_transfer` — ERC-721 transfer events
- `dojifunded_arbitrum.dojitradenft_call_minttrade` — **full** trade struct as JSON calldata (`breachedRule`, `openedAt`/`closedAt`, `fundingPayment`, prices, TP/SL)
- `dojifunded_arbitrum.payoutvault_evt_payoutexecuted` — trader payouts (0 so far)

Q6 uses `dojitradenft_evt_trademinted` for per-wallet breakdowns; Q7/Q8/Q9 use `dojitradenft_call_minttrade` for breach and duration analysis. Still open to build: PnL distributions, leverage heatmaps, per-symbol volumes, slippage (requestedPrice vs exitPrice), and cohort retention.

### Q9 — "Diamond Hands" vs. Scalpers (Duration Psychology)
- **File:** `queries/q9_duration_psychology.sql`
- **Dune ID:** (save with `dune query create`)
- **Source:** `dojifunded_arbitrum.dojitradenft_call_minttrade` (decoded CALL)
- **What it does:** Analyzes trader psychology by categorizing trades based on hold duration (Scalp, Day, Swing). Compares win rates, average PnL, and the "Hope Ratio" (loser-to-winner hold time) per cohort.
- **Columns:** `trading_style`, `total_trades`, `win_rate_pct`, `avg_pnl_usd`, `total_pnl_usd`, `avg_winner_hold_minutes`, `avg_loser_hold_minutes`, `loser_to_winner_hold_ratio`
