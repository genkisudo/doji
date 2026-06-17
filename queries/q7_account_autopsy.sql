-- ============================================================================
-- Q7 — Account autopsy: what kills DojiFunded accounts ("Breach DNA")
-- ----------------------------------------------------------------------------
-- Dune query ID : (save with `dune query create`)
-- Purpose       : One row per trading account — its full lifespan and cause of
--                 death. Each account either dies to a risk-rule breach or is
--                 still active/dormant. Surfaces the fatal trade, the PnL the
--                 account bled out, leverage habits, and soft warnings survived.
-- Source        : dojifunded_arbitrum.dojitradenft_call_minttrade (decoded CALL).
--
-- ⚠ Why the CALL table, not the event: the TradeMinted EVENT only emits a subset
--   of the struct and DROPS `breachedRule`. The full TradeMetadata struct —
--   including breachedRule, openedAt, closedAt, fundingPayment — survives only as
--   the JSON calldata `data` of mintTrade(address to, TradeMetadata data). We
--   parse it with json_extract_scalar(data, '$.field').
--
-- Cause of death: the `breachedRule` on the account's chronologically LAST trade
--   (ordered by closedAt, tiebroken by the globally-monotonic mint tokenId).
--   'NA' on the last trade => not killed by a rule (active or voluntarily idle).
--   Soft rules (e.g. minimum_trade_duration) often appear mid-life and are
--   survived; only the terminal breach is the killer.
--
-- Eval vs funded: not recorded on-chain. We analyze ALL accounts and attach a
--   `received_payout` flag (trader got a PayoutExecuted => likely funded/success;
--   died-to-breach + no payout => likely a failed evaluation). Payouts are 0
--   platform-wide as of 2026-06-17, so the flag is currently always false but
--   future-proof.
--
-- Decimals (TradeMetadata): realizedPnl / positionSizeUsd / feesPaid /
--   fundingPayment = 1e6 (USD); leverage = 1e2 (200 = 2.0x). openedAt/closedAt
--   are unix seconds. Trader wallet = the call's `to` column.
--
-- PnL note: `realized_pnl_usd` is realizedPnl as emitted. `net_pnl_usd` further
--   subtracts fees and applies funding (pnl - fees + funding) — correct only if
--   realizedPnl is reported GROSS of fees. If realizedPnl is already net, use
--   realized_pnl_usd and read total_fees_usd as informational. Both are exposed.
-- ============================================================================
WITH trades AS (
    SELECT
        json_extract_scalar(data, '$.accountId')                  AS account_id,
        "to"                                                       AS trader,
        CAST(output_tokenId AS BIGINT)                            AS token_id,
        CAST(json_extract_scalar(data, '$.closedAt') AS BIGINT)   AS closed_at,
        json_extract_scalar(data, '$.symbol')                     AS symbol,
        json_extract_scalar(data, '$.breachedRule')               AS breached_rule,
        json_extract_scalar(data, '$.isLong')                     AS is_long,
        CAST(json_extract_scalar(data, '$.realizedPnl')     AS DOUBLE) AS pnl_raw,
        CAST(json_extract_scalar(data, '$.feesPaid')        AS DOUBLE) AS fees_raw,
        CAST(json_extract_scalar(data, '$.fundingPayment')  AS DOUBLE) AS funding_raw,
        CAST(json_extract_scalar(data, '$.positionSizeUsd') AS DOUBLE) AS size_raw,
        CAST(json_extract_scalar(data, '$.leverage')        AS DOUBLE) AS lev_raw
    FROM dojifunded_arbitrum.dojitradenft_call_minttrade
    WHERE call_success = true
      AND call_block_time >= TIMESTAMP '2026-05-01'                -- partition pruning
      AND "to" != 0xf60ffefeea868d0a77d5b055df07c18022c7f7bc       -- exclude internal testing wallet
),
ranked AS (
    -- rn_last = 1 marks each account's final closed trade = its moment of death.
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY account_id
                           ORDER BY closed_at DESC, token_id DESC) AS rn_last
    FROM trades
),
payouts AS (
    -- Traders who have received a payout (future-proof; 0 rows as of 2026-06-17).
    SELECT DISTINCT recipient
    FROM dojifunded_arbitrum.payoutvault_evt_payoutexecuted
    WHERE evt_block_time >= TIMESTAMP '2026-05-01'
),
ref AS (
    SELECT MAX(closed_at) AS now_close FROM trades   -- latest close = "now"
),
agg AS (
    SELECT
        account_id,
        trader,
        COUNT(*)                                       AS total_trades,
        SUM(pnl_raw) / 1e6                             AS realized_pnl_usd,
        SUM(pnl_raw - fees_raw + funding_raw) / 1e6    AS net_pnl_usd,
        SUM(fees_raw) / 1e6                            AS total_fees_usd,
        MAX(lev_raw) / 1e2                             AS max_leverage_x,
        AVG(lev_raw) / 1e2                             AS avg_leverage_x,
        COUNT(DISTINCT symbol)                         AS distinct_symbols,
        COUNT(*) FILTER (WHERE breached_rule <> 'NA')  AS total_breaches,
        MIN(closed_at)                                 AS first_close,
        MAX(closed_at)                                 AS last_close
    FROM trades
    GROUP BY account_id, trader
)
SELECT
    -- Account status: visual badge first so it reads instantly in a table
    CASE
        WHEN f.breached_rule <> 'NA'              THEN '💀 killed'
        WHEN r.now_close - a.last_close <= 259200 THEN '🟢 active'
        ELSE                                           '😴 dormant'
    END                                                            AS status,

    -- Cause of death: emoji per rule so rows are scannable at a glance
    CASE f.breached_rule
        WHEN 'daily_drawdown'        THEN '📉 daily_drawdown'
        WHEN 'single_trade_loss'     THEN '💸 single_trade_loss'
        WHEN 'daily_loss_limit'      THEN '🚫 daily_loss_limit'
        WHEN 'static_drawdown'       THEN '🕳️ static_drawdown'
        WHEN 'minimum_trade_duration'THEN '⏱️ min_trade_duration'
        ELSE NULL
    END                                                            AS killed_by,

    -- Trader wallet: truncated with emoji (42-char address: 0x + 40 hex)
    '👤 ' || concat(
        substr(cast(a.trader AS varchar), 1, 6), '...',
        substr(cast(a.trader AS varchar), 39, 4)
    )                                                              AS trader,

    -- Account ID: first 8 chars of the UUID is enough to identify a row
    concat(substr(a.account_id, 1, 8), '...')                     AS account,

    -- Payout flag: clean tick or dash (all false until first funded payout)
    CASE WHEN p.recipient IS NOT NULL THEN '✅ paid out' ELSE '—' END
                                                                   AS payout,

    -- Lifespan counters (pure numbers — sortable)
    a.total_trades,
    a.total_breaches - CASE WHEN f.breached_rule <> 'NA' THEN 1 ELSE 0 END
                                                                   AS soft_breaches,
    DATE_DIFF('day', FROM_UNIXTIME(a.first_close), FROM_UNIXTIME(a.last_close))
                                                                   AS days_alive,

    -- PnL metrics (pure numbers — sortable; format as $ in Dune column settings)
    ROUND(a.realized_pnl_usd, 2)                                   AS realized_pnl_usd,
    ROUND(a.net_pnl_usd,      2)                                   AS net_pnl_usd,
    ROUND(a.total_fees_usd,   2)                                   AS fees_usd,

    -- Leverage (pure numbers)
    ROUND(a.avg_leverage_x, 2)                                     AS avg_lev_x,
    ROUND(a.max_leverage_x, 2)                                     AS max_lev_x,
    a.distinct_symbols                                             AS pairs,

    -- Fatal trade detail: the exact trade that killed (or last trade if alive)
    CASE WHEN f.is_long = 'true' THEN '📈 LONG' ELSE '📉 SHORT' END
                                                                   AS fatal_side,
    f.symbol                                                       AS fatal_symbol,
    ROUND(f.lev_raw  / 1e2, 2)                                     AS fatal_lev_x,
    ROUND(f.size_raw / 1e6, 2)                                     AS fatal_size_usd,
    ROUND(f.pnl_raw  / 1e6, 2)                                     AS fatal_pnl_usd,

    -- Timestamps (native — Dune handles timezone display)
    FROM_UNIXTIME(a.first_close)                                   AS first_trade_at,
    FROM_UNIXTIME(a.last_close)                                    AS last_trade_at

FROM agg a
JOIN ranked f ON f.account_id = a.account_id AND f.rn_last = 1
CROSS JOIN ref r
LEFT JOIN payouts p ON p.recipient = a.trader
ORDER BY a.realized_pnl_usd ASC   -- biggest blow-ups first
