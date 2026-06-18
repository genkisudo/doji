# DojiFunded On-Chain Analytics

On-chain analytics workspace for [DojiFunded](https://dojifunded.com), a decentralized prop trading platform on Arbitrum. This repository contains DuneSQL queries, smart contract sources, and documentation for platform transparency and performance tracking.

## Project Overview

- **Blockchain:** Arbitrum
- **Core Technology:** DuneSQL for analytics, Solidity for smart contracts.
- **Purpose:** Provide verifiable transparency for trading activity, platform revenue, and trader performance ("Explorer" and "Terminal" metrics).
- **Data Architecture:**
    - **Raw Events:** Q1–Q5 use raw ERC-20 and NFT transfers (decode-independent).
    - **Decoded Tables:** Q6+ use decoded Dune tables:
        - `dojifunded_arbitrum.dojitradenft_evt_trademinted`: Rich per-trade metadata.
        - `dojifunded_arbitrum.dojitradenft_call_minttrade`: Full trade struct including `breachedRule` (cause of death).
        - `dojifunded_arbitrum.payoutvault_evt_payoutexecuted`: Settlement records.

## Key Files & Directories

- `queries/`: SQL files for Dune Analytics (Q1–Q8).
- `doji_tradenft.sol`: The `DojiTradeNFT` contract. Defines decimal conventions:
    - `PRICE_DECIMALS`: 8
    - `USD_DECIMALS`: 6
    - `QTY_DECIMALS`: 18
    - `LEVERAGE_DECIMALS`: 2
- `payout_vault.sol`: The `PayoutVault` contract for settler and payouts.
- `CLAUDE.md`: Operational guide for Claude Code (contains active API keys and CLI usage).
- `sql_guide.md`: Best practices for writing efficient DuneSQL queries.

## Key Addresses (Arbitrum)

| Role | Address |
|---|---|
| Deposit reserve A | `0x98D4077A5C448529d20D233d36780e3A99dB541E` |
| Fee wallet | `0xF5D86eA2457d8b408E6e63affBF0E40E9AB646c1` |
| DojiTradeNFT (DOJI-TRADE) | `0xcac4cbbcb921512dbd327b23ab5771125e7c1ff1` |
| Real USDC (Circle) | `0xaf88d065e77c8cC2239327C5EDb3A432268e5831` |
| Spoof "UṢDC" (Exclude) | `0xc09978783365361538c50c1036f3958509886418` |

## Development Conventions

### SQL Queries
- **Partition Pruning:** Always filter on `block_time` / `block_date` and `blockchain = 'arbitrum'`.
- **Filtering:** Exclude the spoof USDC (`0xc0997...`) and internal testing wallet (`0xf60ff...`).
- **Traders:** Identified via `DojiTradeNFT` mint recipients. A closed trade mints one NFT to the trader.
- **Decimals:** Follow the constants defined in `doji_tradenft.sol`.

### Deployment & Execution
- **Dune CLI:** Used to run, create, and update queries. Use `-o json` for detailed output.
- **Parameters:** Use the REST API (documented in `CLAUDE.md`) for parameterized queries (e.g., Q6).

## Building and Running

This project has no local build system. All execution happens via the Dune CLI or API.

- **Run Query:** `dune query run-sql --sql "$(cat queries/q3_headline_metrics.sql)" -o json`
- **Update Query:** `dune query update <query_id> --sql "$(cat queries/q1_usdc_deposits_2026.sql)" -o json`
- **API Key:** Exported as `DUNE_API_KEY`.
