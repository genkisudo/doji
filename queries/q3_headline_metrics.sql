-- ============================================================================
-- Q3 — DojiFunded platform headline metrics (single-row summary)
-- ----------------------------------------------------------------------------
-- Dune query ID : 7717396
-- Purpose       : One row, all the public/marketing top-line numbers — trades,
--                 traders, deposit count, depositors, and total USDC deposited.
--                 Ideal backing query for a metric-card visual.
-- Source        : nft.transfers (trades) + erc20_arbitrum.evt_Transfer (deposits).
--                 Fully decode-independent — no project ABI required.
--
-- Method        : Two independent single-row CTEs (trades, deposits) joined with
--                 a CROSS JOIN. Each side is 1 row, so the cross join yields
--                 exactly one combined row. Trade and deposit logic mirror Q2
--                 and Q1 respectively, so totals here reconcile with those queries.
--
-- Addresses
--   Trade NFT   : 0xcac4cbbcb921512dbd327b23ab5771125e7c1ff1
--   Reserve A   : 0x98D4077A5C448529d20D233d36780e3A99dB541E
--   Reserve B   : 0x1016bC039A4aB6008d38EAD798b4E29361a2D6eA
--   Real USDC   : 0xaf88d065e77c8cC2239327C5EDb3A432268e5831  (dotted-S spoof excluded)
--
-- Note          : all-time totals from 2026-05-01 (partition-pruned lower bound).
-- ============================================================================
WITH trades AS (
    -- Closed trades = DojiTradeNFT mints; recipients = traders (see Q2).
    SELECT
        COUNT(*)           AS total_trades,
        COUNT(DISTINCT to) AS unique_traders
    FROM nft.transfers
    WHERE blockchain = 'arbitrum'
      AND contract_address = 0xcac4cbbcb921512dbd327b23ab5771125e7c1ff1
      AND "from" = 0x0000000000000000000000000000000000000000  -- mints only
      AND to != 0xf60ffefeea868d0a77d5b055df07c18022c7f7bc    -- exclude internal testing wallet
      AND block_time >= TIMESTAMP '2026-05-01'
),
deposits AS (
    -- Real USDC deposits into the reserve (see Q1); spoof token excluded by
    -- pinning contract_address to Circle native USDC.
    SELECT
        COUNT(*)               AS total_deposits,
        SUM(value / 1e6)       AS total_usdc_deposited,   -- 6-decimal base units → USDC
        COUNT(DISTINCT "from") AS unique_depositors
    FROM erc20_arbitrum.evt_Transfer
    WHERE "to" = 0x98D4077A5C448529d20D233d36780e3A99dB541E   -- Reserve A only (trader-facing; see Q1)
      AND contract_address = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831
      AND "from" != 0xf60ffefeea868d0a77d5b055df07c18022c7f7bc  -- exclude internal testing wallet
      AND evt_block_time >= TIMESTAMP '2026-05-01'
)

SELECT
    t.total_trades,
    t.unique_traders,
    d.total_deposits,
    d.unique_depositors,
    d.total_usdc_deposited
FROM trades t
CROSS JOIN deposits d   -- 1 row × 1 row = 1 combined summary row
