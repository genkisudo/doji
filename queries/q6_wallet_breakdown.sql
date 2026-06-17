-- ============================================================================
-- Q6 — Single-wallet trader breakdown (parameterized)
-- ----------------------------------------------------------------------------
-- Dune query ID : (save with `dune query create`)
-- Purpose       : Paste a trader's wallet address and get a one-row scorecard of
--                 their entire DojiFunded history: realized PnL, fees, net PnL,
--                 trade count, accounts, pairs, win rate, volume, leverage,
--                 long/short split, best/worst trade, and first/last trade dates.
-- Source        : dojifunded_arbitrum.dojitradenft_evt_trademinted (decoded).
--                 One TradeMinted event == one closed trade.
--
-- Parameter     : {{wallet_address}}  (type: text)
--                 Paste a 0x-prefixed address, e.g.
--                 0x8173699df688d03720159e59b559ae3ee94cd8c6
--                 Dune substitutes the text literally, so a 0x hex value parses
--                 directly as a varbinary address — no quoting/casting needed.
--
-- Decimals (from DojiTradeNFT): realizedPnl / feesPaid / positionSizeUsd = 1e6,
--                 leverage = 1e2 (1x = 100). Prices (1e8) are not used here.
--
-- PnL note      : `realizedPnl` is the trade's realized PnL as emitted. `net_pnl`
--                 subtracts `feesPaid` on top, so it is correct only if the event
--                 reports PnL gross of fees. If realizedPnl is already net of
--                 fees, use `realized_pnl_usd` and treat `total_fees_usd` as
--                 informational. Both columns are exposed so either reading works.
-- ============================================================================
WITH trades AS (
    SELECT
        realizedPnl,
        feesPaid,
        positionSizeUsd,
        leverage,
        isLong,
        symbol,
        accountId,
        evt_block_time
    FROM dojifunded_arbitrum.dojitradenft_evt_trademinted
    WHERE trader = {{wallet_address}}
      AND evt_block_time >= TIMESTAMP '2026-05-01'   -- partition-pruned lower bound
)
SELECT
    {{wallet_address}}                                         AS trader,

    -- Activity counts
    COUNT(*)                                                   AS total_trades,
    COUNT(DISTINCT accountId)                                  AS accounts,
    COUNT(DISTINCT symbol)                                     AS pairs_traded,

    -- PnL (USD, 1e6 base units)
    SUM(CAST(realizedPnl AS DOUBLE)) / 1e6                     AS realized_pnl_usd,
    SUM(CAST(feesPaid    AS DOUBLE)) / 1e6                     AS total_fees_usd,
    (SUM(CAST(realizedPnl AS DOUBLE)) - SUM(CAST(feesPaid AS DOUBLE))) / 1e6
                                                              AS net_pnl_usd,
    AVG(CAST(realizedPnl AS DOUBLE)) / 1e6                     AS avg_pnl_per_trade_usd,
    MAX(CAST(realizedPnl AS DOUBLE)) / 1e6                     AS best_trade_usd,
    MIN(CAST(realizedPnl AS DOUBLE)) / 1e6                     AS worst_trade_usd,

    -- Win/loss
    COUNT(*) FILTER (WHERE realizedPnl > 0)                    AS winning_trades,
    COUNT(*) FILTER (WHERE realizedPnl < 0)                    AS losing_trades,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE realizedPnl > 0) / COUNT(*), 1
    )                                                          AS win_rate_pct,

    -- Size & leverage
    SUM(CAST(positionSizeUsd AS DOUBLE)) / 1e6                 AS total_volume_usd,
    AVG(CAST(positionSizeUsd AS DOUBLE)) / 1e6                 AS avg_position_usd,
    AVG(CAST(leverage AS DOUBLE)) / 1e2                        AS avg_leverage_x,
    MAX(CAST(leverage AS DOUBLE)) / 1e2                        AS max_leverage_x,

    -- Direction split
    COUNT(*) FILTER (WHERE isLong)                             AS long_trades,
    COUNT(*) FILTER (WHERE NOT isLong)                         AS short_trades,

    -- Time window
    MIN(evt_block_time)                                       AS first_trade,
    MAX(evt_block_time)                                       AS last_trade,
    DATE_DIFF('day', MIN(evt_block_time), MAX(evt_block_time)) AS active_days
FROM trades
