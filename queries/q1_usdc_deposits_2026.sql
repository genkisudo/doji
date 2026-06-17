-- ============================================================================
-- Q1 — USDC deposits to DojiFunded (calendar year 2026)
-- ----------------------------------------------------------------------------
-- Dune query ID : 7717333
-- Purpose       : Funnel / treasury metric — how much real USDC traders have
--                 deposited to fund their accounts, plus unique funders and
--                 transaction count.
-- Source        : erc20_arbitrum.evt_Transfer (raw ERC-20 Transfer events).
--                 Decode-independent: no project ABI required.
--
-- Deposit flow (two-hop):
--   1. Trader  →  Reserve A  (raw ERC-20 Transfer; "from" = actual trader)
--   2. Reserve A  →  Reserve B  (internal sweep; Reserve B emits ReserveDeposited)
--
--   We filter on Reserve A only. "from" in those events is the real trader
--   wallet, giving correct unique_depositors. Filtering on Reserve B would
--   show Reserve A as the depositor and double-count USDC amounts.
--
-- Addresses
--   Reserve A   : 0x98D4077A5C448529d20D233d36780e3A99dB541E  (trader-facing entry)
--   Reserve B   : 0x1016bC039A4aB6008d38EAD798b4E29361a2D6eA  (internal; emits ReserveDeposited)
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
    COUNT(DISTINCT "from") AS unique_depositors   -- distinct trader wallets
FROM erc20_arbitrum.evt_Transfer
WHERE "to" = 0x98D4077A5C448529d20D233d36780e3A99dB541E   -- Reserve A only (trader-facing)
  AND contract_address = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831  -- real USDC only
  AND evt_block_time >= TIMESTAMP '2026-05-01'   -- partition-pruned lower bound
  AND evt_block_time <  TIMESTAMP '2027-01-01'   -- exclusive upper bound (2026 only)
