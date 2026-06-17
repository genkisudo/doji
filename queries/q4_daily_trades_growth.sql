-- ============================================================================
-- Q4 — Daily closed trades & cumulative trader growth
-- ----------------------------------------------------------------------------
-- Dune query ID : 7717399
-- Purpose       : Time-series for a growth chart — per-day closed-trade volume,
--                 newly acquired traders, and running cumulative totals of both.
-- Source        : nft.transfers (raw ERC-721 Transfer events). Decode-independent.
--
-- Method
--   mints CTE   : One DojiTradeNFT mint = one closed trade. ROW_NUMBER() over
--                 each trader (ordered by time) flags rn = 1 as that wallet's
--                 first-ever trade — i.e. the day it became a new trader.
--   daily CTE   : Roll mints up per day: total trades, and new_traders counted
--                 via FILTER (WHERE rn = 1) so each trader is "new" exactly once.
--   final SELECT: Running totals with SUM() OVER (ORDER BY day) for cumulative
--                 trades and cumulative distinct traders.
--
-- Address       : DojiTradeNFT 0xcac4cbbcb921512dbd327b23ab5771125e7c1ff1 (Arbitrum)
-- Output cols   : day, trades, new_traders, cumulative_trades, cumulative_traders
-- Notes         : block_time lower bound enables partition pruning; ORDER BY day
--                 is safe (bounded daily grain, not an unbounded row dump).
-- ============================================================================
WITH mints AS (
    SELECT
        to AS trader,
        block_time,
        -- First mint per wallet (rn = 1) marks the trader's onboarding event.
        ROW_NUMBER() OVER (PARTITION BY to ORDER BY block_time) AS rn
    FROM nft.transfers
    WHERE blockchain = 'arbitrum'
      AND contract_address = 0xcac4cbbcb921512dbd327b23ab5771125e7c1ff1
      AND "from" = 0x0000000000000000000000000000000000000000  -- mints only
      AND to != 0xf60ffefeea868d0a77d5b055df07c18022c7f7bc    -- exclude internal testing wallet
      AND block_time >= TIMESTAMP '2026-05-01'
),
daily AS (
    SELECT
        date_trunc('day', block_time)  AS day,
        COUNT(*)                       AS trades,       -- closed trades that day
        COUNT(*) FILTER (WHERE rn = 1) AS new_traders   -- first-time traders that day
    FROM mints
    GROUP BY 1
)
SELECT
    day,
    trades,
    new_traders,
    SUM(trades)      OVER (ORDER BY day) AS cumulative_trades,   -- running trade total
    SUM(new_traders) OVER (ORDER BY day) AS cumulative_traders   -- running trader total
FROM daily
ORDER BY day
