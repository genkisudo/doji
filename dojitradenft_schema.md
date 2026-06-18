# DojiTradeNFT — Analytics Reference

**Contract:** `0xcac4cbbcb921512dbd327b23ab5771125e7c1ff1` (Arbitrum)
**Token:** ERC-721 "DojiFunded Trade Proof" / `DOJI-TRADE`
**Source:** `doji_tradenft.sol` — `DojiTradeNFT`
**Dune namespace:** `dojifunded_arbitrum.dojitradenft_*`

One NFT is minted per closed trade. The mint is the on-chain record that a trade happened.

---

## Decimal Conventions (from contract constants)

| Constant | Value | Applies to |
|---|---|---|
| `PRICE_DECIMALS` | 8 | `exitPrice`, `entryPrice`, `markPrice`, `requestedPrice`, `fundingRate`, `takeProfitTrigger/Limit`, `stopLossTrigger/Limit` |
| `USD_DECIMALS` | 6 | `positionSizeUsd`, `realizedPnl`, `feesPaid`, `fundingPayment` |
| `QTY_DECIMALS` | 18 | `quantity` (base asset) |
| `LEVERAGE_DECIMALS` | 2 | `leverage` — 1x = 100, 50x = 5000 |

---

## Live Row Counts (since 2026-05-01)

| Table | Rows |
|---|---|
| `dojitradenft_evt_trademinted` | 746 |
| `dojitradenft_call_minttrade` | 746 (call_success = true) |
| `dojitradenft_evt_transfer` (mints only) | 746 |
| `dojitradenft_evt_rolegranted` | 2 |

---

## Table 1 — `dojitradenft_evt_trademinted` ← primary analytics table

Emitted by `mintTrade()` for every closed trade. Contains a curated subset of `TradeMetadata` — enough for most analytics (PnL, leverage, symbol, size, fees). Does **not** include `entryPrice`, `breachedRule`, `openedAt`, `closedAt`, `fundingPayment`, `quantity`, etc. — use `call_minttrade` for those.

| Column | Type | Decimals | Human value |
|---|---|---|---|
| `evt_block_time` | timestamp | — | partition key |
| `evt_block_date` | date | — | |
| `evt_block_number` | bigint | — | |
| `evt_tx_hash` | varbinary | — | |
| `evt_tx_from` | varbinary | — | tx sender (minter backend) |
| `contract_address` | varbinary | — | NFT contract |
| `tokenId` | uint256 | — | sequential NFT ID |
| `trader` | varbinary | — | trader wallet (NFT recipient) |
| `accountId` | varchar | — | UUID eval account identifier |
| `tradeId` | varchar | — | UUID trade identifier |
| `symbol` | varchar | — | e.g. `"BTC-PERP"`, `"MEGA-PERP"` |
| `isLong` | boolean | — | `true` = long, `false` = short |
| `leverage` | bigint | ÷ 100 | `CAST(leverage AS DOUBLE) / 100` |
| `positionSizeUsd` | uint256 | ÷ 1e6 | `CAST(positionSizeUsd AS DOUBLE) / 1e6` |
| `realizedPnl` | int256 | ÷ 1e6 | **signed** — `CAST(realizedPnl AS DOUBLE) / 1e6` |
| `feesPaid` | uint256 | ÷ 1e6 | `CAST(feesPaid AS DOUBLE) / 1e6` |
| `exitPrice` | uint256 | ÷ 1e8 | `CAST(exitPrice AS DOUBLE) / 1e8` |

**Standard SELECT pattern:**
```sql
SELECT
  evt_block_time,
  trader,
  accountId,
  tradeId,
  symbol,
  isLong,
  CAST(leverage AS DOUBLE) / 100             AS leverage_x,
  CAST(positionSizeUsd AS DOUBLE) / 1e6      AS position_size_usd,
  CAST(realizedPnl AS DOUBLE) / 1e6          AS realized_pnl_usd,
  CAST(feesPaid AS DOUBLE) / 1e6             AS fees_paid_usd,
  CAST(exitPrice AS DOUBLE) / 1e8            AS exit_price,
  tokenId
FROM dojifunded_arbitrum.dojitradenft_evt_trademinted
WHERE evt_block_time >= TIMESTAMP '2026-05-01'
  AND trader != 0xf60ffefeea868d0a77d5b055df07c18022c7f7bc  -- exclude internal testing wallet
```

---

## Table 2 — `dojitradenft_call_minttrade` ← full TradeMetadata (use for breachedRule, entryPrice, timestamps)

The decoded call table. The full `TradeMetadata` struct is ABI-encoded as the `data` argument (JSON string on Dune). Extract fields with `json_extract_scalar(data, '$.fieldName')`.

**Use this table when you need:** `breachedRule`, `entryPrice`, `openedAt`, `closedAt`, `fundingPayment`, `fundingRate`, `quantity`, `markPrice`, `requestedPrice`, `positionId`, TP/SL triggers.

| Column | Type | Notes |
|---|---|---|
| `call_block_time` | timestamp | partition key |
| `call_block_date` | date | |
| `call_block_number` | bigint | |
| `call_tx_hash` | varbinary | |
| `call_tx_from` | varbinary | |
| `call_success` | boolean | **always filter `call_success = true`** |
| `call_trace_address` | array(bigint) | |
| `contract_address` | varbinary | |
| `to` | varbinary | trader wallet (NFT recipient) |
| `data` | varchar | JSON blob of full `TradeMetadata` struct |
| `output_tokenId` | uint256 | minted NFT ID |

### JSON fields inside `data`

Extract with `json_extract_scalar(data, '$.fieldName')`. All extracted values are `varchar` — cast numerics explicitly.

| JSON field | Decimals | Cast pattern |
|---|---|---|
| `$.accountId` | — | varchar |
| `$.tradeId` | — | varchar |
| `$.positionId` | — | varchar |
| `$.symbol` | — | varchar |
| `$.isLong` | — | `= 'true'` or `= 'false'` |
| `$.breachedRule` | — | `'NA'` = no breach; any other value = breach cause |
| `$.openedAt` | unix seconds | `from_unixtime(CAST(... AS BIGINT))` |
| `$.closedAt` | unix seconds | `from_unixtime(CAST(... AS BIGINT))` |
| `$.leverage` | ÷ 100 | `CAST(... AS DOUBLE) / 100` |
| `$.positionSizeUsd` | ÷ 1e6 | `CAST(... AS DOUBLE) / 1e6` |
| `$.realizedPnl` | ÷ 1e6 | signed — `CAST(... AS DOUBLE) / 1e6` |
| `$.feesPaid` | ÷ 1e6 | `CAST(... AS DOUBLE) / 1e6` |
| `$.fundingPayment` | ÷ 1e6 | signed — `CAST(... AS DOUBLE) / 1e6` |
| `$.fundingRate` | ÷ 1e8 | signed — `CAST(... AS DOUBLE) / 1e8` |
| `$.entryPrice` | ÷ 1e8 | `CAST(... AS DOUBLE) / 1e8` |
| `$.exitPrice` | ÷ 1e8 | `CAST(... AS DOUBLE) / 1e8` |
| `$.requestedPrice` | ÷ 1e8 | `CAST(... AS DOUBLE) / 1e8` |
| `$.markPrice` | ÷ 1e8 | `CAST(... AS DOUBLE) / 1e8` |
| `$.quantity` | ÷ 1e18 | `CAST(... AS DOUBLE) / 1e18` |
| `$.takeProfitTrigger` | ÷ 1e8 | `0` = not set |
| `$.takeProfitLimit` | ÷ 1e8 | |
| `$.takeProfitTriggerType` | — | `'0'`=NONE, `'1'`=MARK, `'2'`=LAST |
| `$.stopLossTrigger` | ÷ 1e8 | `0` = not set |
| `$.stopLossLimit` | ÷ 1e8 | |
| `$.stopLossTriggerType` | — | `'0'`=NONE, `'1'`=MARK, `'2'`=LAST |

**Standard SELECT pattern:**
```sql
SELECT
  call_block_time,
  "to"                                                           AS trader,
  json_extract_scalar(data, '$.accountId')                       AS account_id,
  json_extract_scalar(data, '$.tradeId')                         AS trade_id,
  json_extract_scalar(data, '$.symbol')                          AS symbol,
  json_extract_scalar(data, '$.breachedRule')                    AS breached_rule,
  json_extract_scalar(data, '$.isLong') = 'true'                 AS is_long,
  CAST(json_extract_scalar(data, '$.leverage') AS DOUBLE) / 100  AS leverage_x,
  CAST(json_extract_scalar(data, '$.positionSizeUsd') AS DOUBLE) / 1e6  AS position_size_usd,
  CAST(json_extract_scalar(data, '$.realizedPnl') AS DOUBLE) / 1e6      AS realized_pnl_usd,
  CAST(json_extract_scalar(data, '$.feesPaid') AS DOUBLE) / 1e6         AS fees_paid_usd,
  CAST(json_extract_scalar(data, '$.entryPrice') AS DOUBLE) / 1e8       AS entry_price,
  CAST(json_extract_scalar(data, '$.exitPrice') AS DOUBLE) / 1e8        AS exit_price,
  from_unixtime(CAST(json_extract_scalar(data, '$.openedAt') AS BIGINT)) AS opened_at,
  from_unixtime(CAST(json_extract_scalar(data, '$.closedAt') AS BIGINT)) AS closed_at,
  output_tokenId                                                 AS token_id
FROM dojifunded_arbitrum.dojitradenft_call_minttrade
WHERE call_block_time >= TIMESTAMP '2026-05-01'
  AND call_success = true
  AND "to" != 0xf60ffefeea868d0a77d5b055df07c18022c7f7bc
```

---

## Table 3 — `dojitradenft_evt_transfer`

Standard ERC-721 `Transfer(from, to, tokenId)` event. Every mint fires one transfer where `from = 0x000...0`. Useful for older queries (Q1–Q5) that pre-date the decoded contract tables.

| Column | Type | Notes |
|---|---|---|
| `evt_block_time` | timestamp | |
| `evt_block_date` | date | |
| `evt_tx_hash` | varbinary | |
| `contract_address` | varbinary | |
| `from` | varbinary | `0x000...0` on mint |
| `to` | varbinary | trader wallet on mint |
| `tokenId` | uint256 | |

**Mint-only filter:** `"from" = 0x0000000000000000000000000000000000000000`

Prefer `evt_trademinted` over this table for trade analytics — it has richer columns. Use `evt_transfer` only when you need raw NFT movement (e.g. secondary transfers, if they ever occur).

---

## Table 4 — `dojitradenft_evt_rolegranted`

2 rows — records which wallets hold `MINTER_ROLE` (the backend hot wallet that calls `mintTrade`).

| Column | Type |
|---|---|
| `evt_block_time` | timestamp |
| `evt_tx_hash` | varbinary |
| `account` | varbinary |
| `role` | varbinary |
| `sender` | varbinary |

Role hash: `MINTER_ROLE = keccak256("MINTER_ROLE")`

---

## Which Table to Use

| Need | Table |
|---|---|
| PnL, fees, leverage, symbol, win/loss per trade | `evt_trademinted` |
| Breach cause (`breachedRule`), entry price, hold duration, funding | `call_minttrade` |
| Unique traders / trade count (decode-independent) | `evt_transfer` (filter `from = 0x0`) |
| Full field set — any combination of the above | `call_minttrade` (superset of `evt_trademinted`) |

---

## Key Notes

- **Exclude testing wallet** `0xf60ffefeea868d0a77d5b055df07c18022c7f7bc` from all queries.
- **`realizedPnl` is signed** (`int256`) — cast with `CAST(realizedPnl AS DOUBLE)`, not `CAST(... AS BIGINT)`, to avoid overflow on large negative values.
- **`breachedRule = 'NA'`** is the sentinel for "no breach" — the account closed normally. Non-`'NA'` values identify the rule that killed the account (used in Q7/Q8).
- **`call_minttrade` is a superset** of `evt_trademinted` — every field in the event is also in the JSON `data` blob, plus ~15 additional fields the event drops. The event is faster to query; the call table is heavier but complete.
- **`openedAt` / `closedAt`** are Unix timestamps (seconds) extracted as strings from JSON — always `CAST(... AS BIGINT)` before passing to `from_unixtime()`.
- **Trade duration** = `closedAt - openedAt` seconds (both from `call_minttrade`).
