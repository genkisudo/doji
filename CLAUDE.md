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
| Deposit reserve | `0x98D4077A5C448529d20D233d36780e3A99dB541E` |
| Fee wallet | `0xF5D86eA2457d8b408E6e63affBF0E40E9AB646c1` |
| DojiTradeNFT contract (DOJI-TRADE) | `0xcac4cbbcb921512dbd327b23ab5771125e7c1ff1` |
| Real USDC (Circle native, 6 dec) | `0xaf88d065e77c8cC2239327C5EDb3A432268e5831` |
| Spoof "UṢDC" (dotted-S, exclude always) | `0xc09978783365361538c50c1036f3958509886418` |

## Query Architecture

All queries are **decode-independent** — they run on raw `nft.transfers` and `erc20_arbitrum.evt_Transfer` without needing the main trading contract's ABI to be decoded on Dune.

**How traders are identified:**
- A closed trade mints one `DojiTradeNFT` to the trader's address (`from = 0x0` in `nft.transfers`). Distinct mint recipients = unique traders.
- Traders fund accounts by depositing real USDC to the deposit reserve. Use this as a secondary signal or funnel metric.

**The DojiTradeNFT contract is not yet decoded on Dune.** Once it is, queries can be enriched using the `TradeMinted` event, which carries: `realizedPnl`, `positionSizeUsd`, `leverage`, `symbol`, `entryPrice`, `exitPrice`, `requestedPrice`, `feesPaid`, `fundingPayment`, `breachedRule`, `accountId`.

**All queries filter from `2026-05-01`** (platform launch was 2026-05-25; the filter is set early to leave headroom).

## Saved Queries on Dune

| File | Dune ID | Description |
|---|---|---|
| `queries/q1_usdc_deposits_2026.sql` | 7717333 | USDC deposits to reserve in 2026 |
| `queries/q2_unique_traders.sql` | 7717347 | Unique traders via NFT mint recipients |
| `queries/q3_headline_metrics.sql` | 7717396 | Single-row platform summary (trades + deposits) |
| `queries/q4_daily_trades_growth.sql` | 7717399 | Daily trades & cumulative trader growth |
| `queries/q5_fee_wallet_inflows.sql` | — | Fee wallet USDC inflows (platform revenue) |

## DuneSQL Notes (from `sql_guide.md`)

- Filter on `block_time` / `evt_block_time` / `block_date` to hit partition pruning — always include a time range.
- For cross-chain tables (`tokens.transfers`, `dex.trades`), also add `blockchain = 'arbitrum'` to prune the blockchain partition.
- Prefer CTEs over nested subqueries; use window functions instead of correlated subqueries.
- Never `SELECT *` on large tables; never `ORDER BY` without `LIMIT` on unbounded result sets.

## Reference Files

- `doji_docs.md` — DojiFunded platform documentation (Explorer, Terminal, payouts)
- `doji_tradenft.sol` — DojiTradeNFT smart contract source; defines `TradeMetadata` struct and decimal conventions (`PRICE_DECIMALS=8`, `USD_DECIMALS=6`, `QTY_DECIMALS=18`, `LEVERAGE_DECIMALS=2`)
- `doji_queries_summary.md` — Summary of all 4 saved queries with live result snapshots
- `sql_guide.md` — Dune's official DuneSQL efficiency guide

### Notes

The smart contract was submited for decoding on Dune, should be ready soon. 
