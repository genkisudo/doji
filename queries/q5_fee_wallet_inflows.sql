-- ============================================================================
-- Q5 — Fee wallet inflows (platform revenue)
-- ----------------------------------------------------------------------------
-- Dune query ID : (not yet saved)
-- Purpose       : Platform revenue metric — daily inflows to the fee wallet,
--                 normalized by token. Fees are NOT paid in USDC; diagnostic
--                 found token 0x3581053e672de2a68920a6ae55b327ea9dfbb9b0
--                 (unregistered in tokens.erc20 as of 2026-06-17).
-- Source        : erc20_arbitrum.evt_Transfer + tokens.erc20 (symbol/decimals).
--                 Decode-independent: no project ABI required.
--
-- Addresses
--   Fee wallet  : 0xF5D86eA2457d8b408E6e63affBF0E40E9AB646c1
--
-- Notes
--   * No contract_address filter — fees may arrive in any token; all inflows
--     are captured and labelled by symbol (or raw address if unregistered).
--   * COALESCE(decimals, 18) guards against tokens absent from tokens.erc20;
--     18 is the ERC-20 default. Check contract on Arbiscan if symbol is null.
--   * Cumulative window is partitioned by contract_address (not symbol) so
--     NULL symbols — unregistered tokens — don't collapse into one bucket.
--   * Bounded to [2026-05-01, 2027-01-01) for partition pruning.
-- ============================================================================
WITH fee_transfers AS (
    SELECT
        t.evt_block_time,
        t."from"                                                        AS source,
        t.contract_address,
        COALESCE(tk.symbol, CAST(t.contract_address AS VARCHAR))        AS token,   -- fallback to address if unregistered
        COALESCE(tk.decimals, 18)                                       AS decimals,
        CAST(t.value AS DOUBLE) / POW(10, COALESCE(tk.decimals, 18))   AS amount   -- normalized to whole units
    FROM erc20_arbitrum.evt_Transfer t
    LEFT JOIN tokens.erc20 tk
           ON tk.contract_address = t.contract_address
          AND tk.blockchain = 'arbitrum'
    WHERE t."to" = 0xF5D86eA2457d8b408E6e63affBF0E40E9AB646c1
      AND t.evt_block_time >= TIMESTAMP '2026-05-01'
      AND t.evt_block_time <  TIMESTAMP '2027-01-01'
),
daily_fees AS (
    SELECT
        date_trunc('day', evt_block_time)  AS day,
        contract_address,
        token,
        COUNT(*)                           AS fee_tx_count,
        SUM(amount)                        AS daily_amount
    FROM fee_transfers
    GROUP BY 1, 2, 3
)
SELECT
    day,
    token,
    contract_address,
    fee_tx_count,
    daily_amount,
    SUM(daily_amount) OVER (PARTITION BY contract_address ORDER BY day) AS cumulative_amount
FROM daily_fees
ORDER BY day, token;


-- ── Diagnostic: per-token summary — run standalone to inspect fee wallet ──────
-- SELECT
--     t.contract_address,
--     COALESCE(tk.symbol, 'unknown')                                       AS token,
--     COALESCE(tk.decimals, 18)                                            AS decimals,
--     COUNT(*)                                                             AS tx_count,
--     SUM(CAST(t.value AS DOUBLE) / POW(10, COALESCE(tk.decimals, 18)))   AS total_normalized,
--     MIN(t.evt_block_time)                                                AS first_seen,
--     MAX(t.evt_block_time)                                                AS last_seen
-- FROM erc20_arbitrum.evt_Transfer t
-- LEFT JOIN tokens.erc20 tk
--        ON tk.contract_address = t.contract_address
--       AND tk.blockchain = 'arbitrum'
-- WHERE t."to" = 0xF5D86eA2457d8b408E6e63affBF0E40E9AB646c1
--   AND t.evt_block_time >= TIMESTAMP '2026-05-01'
--   AND t.evt_block_time <  TIMESTAMP '2027-01-01'
-- GROUP BY 1, 2, 3
-- ORDER BY tx_count DESC;
