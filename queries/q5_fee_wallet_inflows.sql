-- ============================================================================
-- Q5 — Fee wallet USDC inflows (platform revenue)
-- ----------------------------------------------------------------------------
-- Dune query ID : (not yet saved)
-- Purpose       : Platform revenue metric — total USDC received by the fee
--                 wallet. Every trade on DojiFunded incurs fees that are settled
--                 as USDC transfers to this wallet. Summing inflows gives gross
--                 protocol revenue without needing decoded contract events.
-- Source        : erc20_arbitrum.evt_Transfer (raw ERC-20 Transfer events).
--                 Decode-independent: works before DojiTradeNFT ABI is live.
--
-- Addresses
--   Fee wallet  : 0xF5D86eA2457d8b408E6e63affBF0E40E9AB646c1
--   Real USDC   : 0xaf88d065e77c8cC2239327C5EDb3A432268e5831  (Circle native, 6 dec)
--
-- Spoof guard   : Same approach as Q1 — pinning contract_address to Circle USDC
--                 excludes the dotted-S "UṢDC" spoof token.
--
-- Output
--   fee_tx_count      : number of fee transfer events
--   total_fee_usdc    : gross USDC received by the fee wallet
--   unique_fee_payers : distinct addresses that paid fees
--   first_fee         : earliest fee transfer (≈ platform launch)
--   last_fee          : most recent fee transfer
--   daily breakdown   : per-day fee volume and running cumulative total
--
-- Notes
--   * value / 1e6 converts 6-decimal base units to whole USDC.
--   * Two-part output: a daily time-series (for charts) that also carries
--     the all-time aggregates in every row via window functions, so a single
--     query serves both the summary card and the revenue chart.
--   * block_time lower bound enables partition pruning.
-- ============================================================================
WITH fee_transfers AS (
    SELECT
        evt_block_time,
        "from"          AS payer,
        value / 1e6     AS usdc_amount       -- 6-decimal base units → whole USDC
    FROM erc20_arbitrum.evt_Transfer
    WHERE "to" = 0xF5D86eA2457d8b408E6e63affBF0E40E9AB646c1       -- fee wallet
      AND contract_address = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831  -- real USDC only
      AND evt_block_time >= TIMESTAMP '2026-05-01'                 -- partition-pruned lower bound
),
daily_fees AS (
    SELECT
        date_trunc('day', evt_block_time) AS day,
        COUNT(*)                          AS fee_tx_count,         -- fee transfers that day
        SUM(usdc_amount)                  AS daily_fee_usdc,       -- USDC fees collected that day
        COUNT(DISTINCT payer)             AS unique_fee_payers     -- distinct payers that day
    FROM fee_transfers
    GROUP BY 1
)
SELECT
    day,
    fee_tx_count,
    daily_fee_usdc,
    unique_fee_payers,
    SUM(daily_fee_usdc) OVER (ORDER BY day) AS cumulative_fee_usdc,  -- running revenue total
    SUM(fee_tx_count)   OVER (ORDER BY day) AS cumulative_fee_txns   -- running transfer count
FROM daily_fees
ORDER BY day
