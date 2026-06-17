-- ============================================================================
-- Q2 — Unique traders on DojiFunded
-- ----------------------------------------------------------------------------
-- Dune query ID : 7717347
-- Purpose       : Headline adoption metric — count of distinct traders and the
--                 total volume of closed trades, with the platform's activity
--                 window (first/last closed trade).
-- Source        : nft.transfers (raw ERC-721 Transfer events).
--                 Decode-independent: no DojiTradeNFT ABI required.
--
-- Definition    : Closing a trade mints one DojiTradeNFT "trade proof" to the
--                 trader. These are receipts, not tradeable collectibles.
--                   * Distinct mint recipients (to) = unique traders.
--                   * Each mint                      = one closed trade.
--                 Filtering from = 0x0 isolates mints from later transfers,
--                 so secondary movement of a proof is never double-counted.
--
-- Address       : DojiTradeNFT 0xcac4cbbcb921512dbd327b23ab5771125e7c1ff1 (DOJI-TRADE)
-- Notes         : block_time lower bound enables partition pruning; no upper
--                 bound is needed — this is an all-time, run-to-date total.
-- ============================================================================
SELECT
    COUNT(DISTINCT to)   AS unique_traders,   -- distinct mint recipients = traders
    COUNT(*)             AS total_trades,     -- one mint per closed trade
    MIN(block_time)      AS first_trade,      -- first closed trade (≈ launch)
    MAX(block_time)      AS last_trade        -- most recent closed trade
FROM nft.transfers
WHERE blockchain = 'arbitrum'                 -- prune the blockchain partition
  AND contract_address = 0xcac4cbbcb921512dbd327b23ab5771125e7c1ff1
  AND "from" = 0x0000000000000000000000000000000000000000  -- mints only (excludes resends)
  AND block_time >= TIMESTAMP '2026-05-01'    -- partition-pruned lower bound
