# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

On-chain analytics workspace for **DojiFunded** — a decentralized prop trading platform on Arbitrum. Work here is primarily DuneSQL queries and supporting documentation. There is no build system or test runner.

## Running Queries

Use the Dune CLI with the project API key:

```bash
export DUNE_API_KEY=gq7TX5Jj2IIrkdZIU5hlHD7RJ3D1tmwi

# Run a one-off query
dune query run-sql --sql "SELECT ..." -o json

# Create a saved query
dune query create --name "Name" --sql "$(cat queries/file.sql)" -o json

# Run a saved query by ID
dune query run <query_id> -o json

# Update an existing saved query
dune query update <query_id> --sql "$(cat queries/file.sql)" -o json
```

Always use `-o json` — it returns more detail than the default text format. Use `--api-key` flag only as a last resort (visible in shell history); prefer the `export` approach.

## Key Addresses (Arbitrum)

| Role | Address |
|---|---|
| Deposit reserve A (trader-facing entry) | `0x98D4077A5C448529d20D233d36780e3A99dB541E` |
| Deposit reserve B (internal; emits `ReserveDeposited`) | `0x1016bC039A4aB6008d38EAD798b4E29361a2D6eA` |
| Fee wallet | `0xF5D86eA2457d8b408E6e63affBF0E40E9AB646c1` |
| DojiTradeNFT contract (DOJI-TRADE) | `0xcac4cbbcb921512dbd327b23ab5771125e7c1ff1` |
| Real USDC (Circle native, 6 dec) | `0xaf88d065e77c8cC2239327C5EDb3A432268e5831` |
| Spoof "UṢDC" (dotted-S, exclude always) | `0xc09978783365361538c50c1036f3958509886418` |
| Internal testing wallet (exclude always) | `0xf60ffefeea868d0a77d5b055df07c18022c7f7bc` |

## Query Architecture

Older queries (Q1–Q5) are **decode-independent** — they run on raw `nft.transfers` and `erc20_arbitrum.evt_Transfer` without needing the ABI.

**The DojiTradeNFT contract is now decoded on Dune** as `dojifunded_arbitrum.dojitradenft_evt_trademinted`. Q6 and future queries use this table for rich per-trade data: `realizedPnl`, `positionSizeUsd`, `leverage`, `symbol`, `feesPaid`, `accountId`, `tradeId`, `trader`, `isLong`, `exitPrice`.

**How traders are identified:**
- Older queries: a closed trade mints one `DojiTradeNFT` to the trader (`from = 0x0` in `nft.transfers`). Distinct recipients = unique traders.
- Newer queries: use `trader` column directly from `dojitradenft_evt_trademinted`.
- Traders fund accounts by depositing real USDC to the deposit reserve (secondary/funnel metric).

**All queries filter from `2026-05-01`** (platform launch was 2026-05-25; the filter is set early to leave headroom).

## Saved Queries on Dune

| File | Dune ID | Description |
|---|---|---|
| `queries/q1_usdc_deposits_2026.sql` | 7717333 | USDC deposits to reserve in 2026 |
| `queries/q2_unique_traders.sql` | 7717347 | Unique traders via NFT mint recipients |
| `queries/q3_headline_metrics.sql` | 7717396 | Single-row platform summary (trades + traders + accounts + deposits) |
| `queries/q4_daily_trades_growth.sql` | 7717399 | Daily trades & cumulative trader growth |
| `queries/q5_fee_wallet_inflows.sql` | — | Fee wallet USDC inflows (platform revenue) |
| `queries/q6_wallet_breakdown.sql` | 7742479 | Per-wallet scorecard — PnL, win rate, leverage, pairs, accounts (parameterized: `{{wallet_address}}`) |
| `queries/q7_account_autopsy.sql` | 7742886 | "Breach DNA" — one row per account, cause of death + lifespan + fatal trade |
| `queries/q8_breach_leaderboard.sql` | 7742887 | "Breach DNA" — deadliest rules ranked (accounts killed, avg lifespan, fatal leverage) |

**Note on the `breachedRule` field (and the full trade struct):** The `TradeMinted` *event* only emits a subset of `TradeMetadata` and **drops `breachedRule`** (plus `openedAt`, `closedAt`, `fundingPayment`, `requestedPrice`, etc.). The full struct survives only as the JSON calldata `data` of the decoded **call** table `dojifunded_arbitrum.dojitradenft_call_minttrade`. Parse it with `json_extract_scalar(data, '$.field')`. Q7/Q8 source from this call table; Q6 uses the lighter event table. The `breachedRule` sentinel for "no breach" is the string `'NA'`. The PayoutVault is also decoded (`dojifunded_arbitrum.payoutvault_evt_payoutexecuted`), though it has 0 payouts so far.

**Note on parameterized queries:** Dune's CLI (`dune query create`) does not support declaring parameters. Use the REST API to create or update queries with `{{param}}` placeholders:

```bash
python3 -c "
import json, urllib.request, os
sql = open('queries/q6_wallet_breakdown.sql').read()
payload = {'name': 'Query name', 'query_sql': sql, 'parameters': [{'key': 'wallet_address', 'type': 'text', 'value': '0x...'}]}
req = urllib.request.Request('https://api.dune.com/api/v1/query', data=json.dumps(payload).encode(), headers={'X-Dune-API-Key': os.environ['DUNE_API_KEY'], 'Content-Type': 'application/json'}, method='POST')
print(urllib.request.urlopen(req).read().decode())
"
```

## DuneSQL Notes (from `sql_guide.md`)

- Filter on `block_time` / `evt_block_time` / `block_date` to hit partition pruning — always include a time range.
- For cross-chain tables (`tokens.transfers`, `dex.trades`), also add `blockchain = 'arbitrum'` to prune the blockchain partition.
- Prefer CTEs over nested subqueries; use window functions instead of correlated subqueries.
- Never `SELECT *` on large tables; never `ORDER BY` without `LIMIT` on unbounded result sets.

## Reference Files

- `doji_docs.md` — DojiFunded platform documentation (Explorer, Terminal, payouts)
- `doji_tradenft.sol` — DojiTradeNFT smart contract source; defines `TradeMetadata` struct and decimal conventions (`PRICE_DECIMALS=8`, `USD_DECIMALS=6`, `QTY_DECIMALS=18`, `LEVERAGE_DECIMALS=2`)
- `doji_queries_summary.md` — Summary of all saved queries with live result snapshots
- `sql_guide.md` — Dune's official DuneSQL efficiency guide
