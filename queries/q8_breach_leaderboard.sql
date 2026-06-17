-- ============================================================================
-- Q8 — Breach leaderboard: the deadliest rules ("Breach DNA", aggregate view)
-- ----------------------------------------------------------------------------
-- Dune query ID : (save with `dune query create`)
-- Purpose       : One row per cause of death. Ranks which risk rules kill the
--                 most accounts and profiles each killer: average lifespan, PnL
--                 bled out, leverage on the fatal trade, and the deadliest pair.
--                 The aggregate companion to Q7 (per-account autopsy).
-- Source        : dojifunded_arbitrum.dojitradenft_call_minttrade (decoded CALL).
--
-- ⚠ breachedRule lives only in the CALL table's JSON `data` (the TradeMinted
--   event drops it). See Q7 header for the full explanation.
--
-- Cause of death = the breachedRule on each account's chronologically last trade
--   (closedAt, tiebroken by mint tokenId). 'NA' last trade => relabelled
--   'survived / still active'. Soft breaches mid-life are not counted as deaths.
--
-- Decimals: realizedPnl = 1e6 (USD); leverage = 1e2 (200 = 2.0x);
--   openedAt/closedAt = unix seconds. Internal testing wallet excluded.
-- ============================================================================
WITH trades AS (
    SELECT
        json_extract_scalar(data, '$.accountId')                  AS account_id,
        CAST(output_tokenId AS BIGINT)                            AS token_id,
        CAST(json_extract_scalar(data, '$.closedAt') AS BIGINT)   AS closed_at,
        json_extract_scalar(data, '$.symbol')                     AS symbol,
        json_extract_scalar(data, '$.breachedRule')               AS breached_rule,
        CAST(json_extract_scalar(data, '$.realizedPnl') AS DOUBLE) AS pnl_raw,
        CAST(json_extract_scalar(data, '$.leverage')    AS DOUBLE) AS lev_raw
    FROM dojifunded_arbitrum.dojitradenft_call_minttrade
    WHERE call_success = true
      AND call_block_time >= TIMESTAMP '2026-05-01'                -- partition pruning
      AND "to" != 0xf60ffefeea868d0a77d5b055df07c18022c7f7bc       -- exclude internal testing wallet
),
ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY account_id
                           ORDER BY closed_at DESC, token_id DESC) AS rn_last
    FROM trades
),
acct AS (
    -- Per-account lifespan stats (whole life, not just the fatal trade).
    SELECT
        account_id,
        COUNT(*)            AS trades_alive,
        SUM(pnl_raw) / 1e6  AS realized_pnl_usd,
        MIN(closed_at)      AS first_close,
        MAX(closed_at)      AS last_close
    FROM trades
    GROUP BY account_id
),
fatal AS (
    -- One row per account: the terminal trade = cause of death + fatal leverage/symbol.
    SELECT
        account_id,
        CASE WHEN breached_rule = 'NA' THEN 'survived / still active'
             ELSE breached_rule END AS cause_of_death,
        symbol  AS fatal_symbol,
        lev_raw AS fatal_lev_raw
    FROM ranked
    WHERE rn_last = 1
),
joined AS (
    -- One row per account, carrying its cause of death and lifespan.
    SELECT
        f.cause_of_death,
        f.fatal_symbol,
        f.fatal_lev_raw,
        a.trades_alive,
        a.realized_pnl_usd,
        DATE_DIFF('day', FROM_UNIXTIME(a.first_close), FROM_UNIXTIME(a.last_close)) AS days_alive
    FROM fatal f
    JOIN acct  a ON a.account_id = f.account_id
),
agg AS (
    SELECT
        cause_of_death,
        COUNT(*)                  AS accounts,
        AVG(trades_alive)         AS avg_trades_alive,
        AVG(days_alive)           AS avg_days_alive,
        AVG(realized_pnl_usd)     AS avg_realized_pnl_usd,
        AVG(fatal_lev_raw) / 1e2  AS avg_fatal_leverage_x
    FROM joined
    GROUP BY cause_of_death
),
sym AS (
    -- Deadliest pair per cause: most frequent symbol on the fatal trades.
    SELECT
        cause_of_death,
        fatal_symbol,
        ROW_NUMBER() OVER (PARTITION BY cause_of_death
                           ORDER BY COUNT(*) DESC, fatal_symbol) AS rk
    FROM joined
    GROUP BY cause_of_death, fatal_symbol
),
total AS (
    SELECT COUNT(*) AS n FROM joined   -- all classified accounts (deaths + survivors)
)
SELECT
    -- Rule name with emoji so the top killer is visually obvious
    CASE g.cause_of_death
        WHEN 'daily_drawdown'          THEN '📉 daily_drawdown'
        WHEN 'single_trade_loss'       THEN '💸 single_trade_loss'
        WHEN 'daily_loss_limit'        THEN '🚫 daily_loss_limit'
        WHEN 'static_drawdown'         THEN '🕳️ static_drawdown'
        WHEN 'minimum_trade_duration'  THEN '⏱️ min_trade_duration'
        ELSE                                '🟢 survived / active'
    END                                                  AS cause_of_death,

    -- Account counts (pure numbers — sortable)
    g.accounts,
    ROUND(100.0 * g.accounts / t.n, 1)                  AS pct_of_accounts,

    -- Lifespan averages (pure numbers)
    ROUND(g.avg_trades_alive, 1)                         AS avg_trades_alive,
    ROUND(g.avg_days_alive,   1)                         AS avg_days_alive,

    -- PnL at death (pure number; format as $ in Dune column settings)
    ROUND(g.avg_realized_pnl_usd, 2)                     AS avg_pnl_at_death_usd,

    -- Leverage on the fatal trade (pure number)
    ROUND(g.avg_fatal_leverage_x, 2)                     AS avg_fatal_lev_x,

    -- Deadliest pair: the symbol that appears most on fatal trades for this rule
    '⚡ ' || s.fatal_symbol                              AS deadliest_symbol

FROM agg g
JOIN sym   s ON s.cause_of_death = g.cause_of_death AND s.rk = 1
CROSS JOIN total t
ORDER BY g.accounts DESC
