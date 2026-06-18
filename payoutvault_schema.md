# PayoutVault — Analytics Reference

**Contract:** `0x1016bC039A4aB6008d38EAD798b4E29361a2D6eA` (Arbitrum)
**Source:** `doji_vault.sol` — `PayoutVault`
**Token:** USDC `0xaf88d065e77c8cC2239327C5EDb3A432268e5831` (6 decimals)

Use event tables for analytics. Call tables carry the same payload but add `call_success` (useful only when filtering for failed txns).

---

## `payoutvault_evt_reservedeposited` — 106 rows

Emitted by `depositReserve()`. Called by the `ALLOCATOR_ROLE` wallet whenever a trader buys a plan — the backend splits the purchase and pushes the reserve share into the vault. All deposits originate from Deposit Reserve A (`0x98d4077a5c448529d20d233d36780e3a99db541e`).

| Column | Type | Notes |
|---|---|---|
| `evt_block_time` | timestamp | partition key |
| `evt_block_date` | date | |
| `evt_tx_hash` | varbinary | |
| `evt_tx_from` | varbinary | tx sender |
| `contract_address` | varbinary | vault address |
| `amount` | uint256 | USDC, 6 dec — `CAST(amount AS DOUBLE) / 1e6` |
| `"from"` | varbinary | depositing wallet — **must double-quote** (reserved keyword) |
| `depositId` | varbinary | unique bytes32 idempotency key |
| `token` | varbinary | always USDC for now |

```sql
SELECT
  evt_block_time,
  CAST(amount AS DOUBLE) / 1e6 AS amount_usdc,
  "from",
  depositId
FROM dojifunded_arbitrum.payoutvault_evt_reservedeposited
WHERE evt_block_time >= TIMESTAMP '2026-05-01'
ORDER BY evt_block_time DESC
```

---

## `payoutvault_evt_payoutexecuted` — 4 rows

Emitted by `executePayout()`. Called by the `PAYOUT_OPERATOR_ROLE` wallet when a trader's withdrawal is approved by the backend. This is the primary signal for actual money-out-to-traders.

| Column | Type | Notes |
|---|---|---|
| `evt_block_time` | timestamp | partition key |
| `evt_block_date` | date | |
| `evt_tx_hash` | varbinary | |
| `evt_tx_from` | varbinary | operator wallet |
| `contract_address` | varbinary | |
| `amount` | uint256 | USDC, 6 dec |
| `recipient` | varbinary | trader wallet receiving funds |
| `payoutId` | varbinary | unique bytes32 idempotency key |
| `token` | varbinary | USDC |

**Live payouts (all time):**

| Date | Recipient | Amount (USDC) |
|---|---|---|
| 2026-06-15 | `0x7d61b004...f4d97` | 345.11 |
| 2026-06-14 | `0x7d61b004...f4d97` | 200.94 |
| 2026-06-14 | `0x7d61b004...f4d97` | 127.20 |
| 2026-05-25 | `0xfe66dfdb...f191` | 12.00 |

```sql
SELECT
  evt_block_time,
  CAST(amount AS DOUBLE) / 1e6 AS amount_usdc,
  recipient,
  payoutId
FROM dojifunded_arbitrum.payoutvault_evt_payoutexecuted
WHERE evt_block_time >= TIMESTAMP '2026-05-01'
ORDER BY evt_block_time DESC
```

---

## `payoutvault_evt_payoutlimitset`

Emitted by `setPayoutLimit()` (admin-only). Records the rolling-window payout cap per token. When `cap = 0` the limit is disabled. Changing the limit resets the window.

| Column | Type | Notes |
|---|---|---|
| `evt_block_time` | timestamp | |
| `evt_tx_hash` | varbinary | |
| `token` | varbinary | |
| `cap` | uint256 | max USDC per window, 6 dec |
| `window` | uint256 | window duration in seconds |

---

## `payoutvault_evt_rolegranted`

Emitted by `grantRole()`. Tracks which wallets hold `ALLOCATOR_ROLE`, `PAYOUT_OPERATOR_ROLE`, and `PAYOUT_PAUSER_ROLE`.

| Column | Type | Notes |
|---|---|---|
| `evt_block_time` | timestamp | |
| `evt_tx_hash` | varbinary | |
| `account` | varbinary | wallet receiving the role |
| `role` | varbinary | bytes32 keccak hash of role name |
| `sender` | varbinary | admin who granted it |

Role hashes (from contract constants):
- `ALLOCATOR_ROLE` = `keccak256("ALLOCATOR_ROLE")`
- `PAYOUT_OPERATOR_ROLE` = `keccak256("PAYOUT_OPERATOR_ROLE")`
- `PAYOUT_PAUSER_ROLE` = `keccak256("PAYOUT_PAUSER_ROLE")`

---

## Reserve Health Formula

From the contract (`availableReserve` view):

```
available = totalReceived[token] - totalPaidOut[token] - totalEmergencyWithdrawn[token]
```

On Dune, derive this from event tables:

```sql
WITH received AS (
  SELECT SUM(CAST(amount AS DOUBLE)) / 1e6 AS total
  FROM dojifunded_arbitrum.payoutvault_evt_reservedeposited
  WHERE evt_block_time >= TIMESTAMP '2026-05-01'
),
paid AS (
  SELECT SUM(CAST(amount AS DOUBLE)) / 1e6 AS total
  FROM dojifunded_arbitrum.payoutvault_evt_payoutexecuted
  WHERE evt_block_time >= TIMESTAMP '2026-05-01'
),
emergency AS (
  SELECT SUM(CAST(amount AS DOUBLE)) / 1e6 AS total
  FROM dojifunded_arbitrum.payoutvault_evt_emergencywithdraw
  WHERE evt_block_time >= TIMESTAMP '2026-05-01'
)
SELECT
  received.total                                           AS total_deposited_usdc,
  paid.total                                               AS total_paid_usdc,
  COALESCE(emergency.total, 0)                             AS total_emergency_usdc,
  received.total - paid.total - COALESCE(emergency.total, 0) AS available_reserve_usdc
FROM received, paid, emergency
```