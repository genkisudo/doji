-- ============================================================================
-- Q10 — DojiFunded trader payouts from PayoutVault
-- ----------------------------------------------------------------------------
-- Dune query ID : (not yet saved)
-- Purpose       : Full payout log + per-recipient totals + platform summary.
--                 Backed by the decoded PayoutVault event table which is the
--                 authoritative on-chain record of approved trader withdrawals.
--
-- Source        : dojifunded_arbitrum.payoutvault_evt_payoutexecuted
--
-- Addresses
--   PayoutVault : 0x1016bC039A4aB6008d38EAD798b4E29361a2D6eA
--   Real USDC   : 0xaf88d065e77c8cC2239327C5EDb3A432268e5831
--
-- Note          : `amount` is uint256 with 6 decimal places (USDC).
--                 All rows since 2026-05-01 (platform launch headroom).
-- ============================================================================

WITH raw AS (
    SELECT
        evt_block_time                          AS paid_at,
        evt_tx_hash                             AS tx_hash,
        recipient,
        CAST(amount AS DOUBLE) / 1e6            AS amount_usdc,
        payoutId                                AS payout_id
    FROM dojifunded_arbitrum.payoutvault_evt_payoutexecuted
    WHERE evt_block_time >= TIMESTAMP '2026-05-01'
      AND token = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831  -- real USDC only
),

-- Running total per recipient, ordered by time
payout_log AS (
    SELECT
        paid_at,
        recipient,
        amount_usdc,
        SUM(amount_usdc) OVER (
            PARTITION BY recipient
            ORDER BY paid_at
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                       AS recipient_running_total_usdc,
        SUM(amount_usdc) OVER (
            ORDER BY paid_at
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                       AS platform_running_total_usdc,
        ROW_NUMBER() OVER (ORDER BY paid_at)    AS payout_num,
        tx_hash,
        payout_id
    FROM raw
),

-- Per-recipient summary
by_recipient AS (
    SELECT
        recipient,
        COUNT(*)            AS payout_count,
        SUM(amount_usdc)    AS total_usdc,
        MIN(paid_at)        AS first_payout_at,
        MAX(paid_at)        AS last_payout_at
    FROM raw
    GROUP BY recipient
)

-- Full payout log (one row per payout, ordered newest-first)
SELECT
    l.payout_num,
    l.paid_at,
    l.recipient,
    l.amount_usdc,
    l.recipient_running_total_usdc,
    l.platform_running_total_usdc,
    r.payout_count          AS recipient_total_payouts,
    r.total_usdc            AS recipient_total_usdc,
    l.tx_hash,
    l.payout_id
FROM payout_log l
JOIN by_recipient r ON r.recipient = l.recipient
ORDER BY l.paid_at DESC
