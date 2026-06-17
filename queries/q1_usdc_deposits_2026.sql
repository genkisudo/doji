-- ============================================================================
-- Q1 — USDC deposits to the DojiFunded deposit reserve (calendar year 2026)
-- ----------------------------------------------------------------------------
-- Dune query ID : 7717333
-- Purpose       : Funnel / treasury metric — how much real USDC traders have
--                 deposited to fund their accounts, plus how many distinct
--                 wallets funded and how many deposit transactions occurred.
-- Source        : erc20_arbitrum.evt_Transfer (raw ERC-20 Transfer events).
--                 Decode-independent: no project ABI required.
--
-- Addresses
--   Reserve     : 0x98D4077A5C448529d20D233d36780e3A99dB541E  (deposit sink)
--   Real USDC   : 0xaf88d065e77c8cC2239327C5EDb3A432268e5831  (Circle native, 6 dec)
--
-- Spoof guard   : A fake token 0xc09978783365361538c50c1036f3958509886418
--                 ("UṢDC", Unicode dotted-S) also transfers into the reserve.
--                 Pinning contract_address to the real Circle USDC below
--                 excludes it — never aggregate by reserve address alone.
--
-- Notes
--   * value is in 6-decimal base units; / 1e6 converts to whole USDC.
--   * Bounded to [2026-05-01, 2027-01-01) so block_time partition pruning
--     applies (launch was 2026-05-25; lower bound set early for headroom).
-- ============================================================================
SELECT
    COUNT(*)               AS deposit_count,      -- number of deposit transfers
    SUM(value / 1e6)       AS total_usdc,         -- total USDC deposited (6 dec)
    COUNT(DISTINCT "from") AS unique_depositors   -- distinct funding wallets
FROM erc20_arbitrum.evt_Transfer
WHERE "to" = 0x98D4077A5C448529d20D233d36780e3A99dB541E   -- into the reserve
  AND contract_address = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831  -- real USDC only
  AND evt_block_time >= TIMESTAMP '2026-05-01'   -- partition-pruned lower bound
  AND evt_block_time <  TIMESTAMP '2027-01-01'   -- exclusive upper bound (2026 only)