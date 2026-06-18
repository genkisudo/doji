# PayoutVault — Dune Decoded Tables

**Contract:** `0x1016bC039A4aB6008d38EAD798b4E29361a2D6eA` (Arbitrum)
**Dune namespace:** `dojifunded_arbitrum.payoutvault_*`

This contract is the payout reserve / vault. It receives USDC from the deposit pipeline and disperses winnings to profitable traders. There are two role-controlled operations: `depositReserve` (funded by the allocator) and `executePayout` (triggered by the payout operator).

---

## Live Row Counts (since 2026-05-01)

| Table | Rows |
|---|---|
| `payoutvault_evt_reservedeposited` | 106 |
| `payoutvault_call_depositreserve` | 106 |
| `payoutvault_evt_payoutexecuted` | 4 |
| `payoutvault_call_executepayout` | 4 |
| `payoutvault_evt_emergencywithdraw` | 0 |
| `payoutvault_evt_nativewithdrawn` | 0 |

---

## Event Tables

### `payoutvault_evt_reservedeposited` ← primary funding signal

Emitted whenever USDC is deposited into the vault reserve. All 106 deposits originate from `0x98d4077a5c448529d20d233d36780e3a99db541e` (Deposit Reserve A / trader-facing entry).

| Column | Type | Notes |
|---|---|---|
| `evt_block_time` | timestamp | partition key |
| `evt_block_date` | date | |
| `evt_block_number` | bigint | |
| `evt_tx_hash` | varbinary | |
| `evt_tx_from` | varbinary | |
| `evt_tx_to` | varbinary | |
| `evt_tx_index` | integer | |
| `evt_index` | bigint | |
| `contract_address` | varbinary | |
| `amount` | uint256 | USDC 6-dec → divide by 1e6 |
| `"from"` | varbinary | depositing address (needs quoting — reserved keyword) |
| `depositId` | varbinary | unique deposit identifier |
| `token` | varbinary | always USDC `0xaf88d065e77c8cC2239327C5EDb3A432268e5831` |

**Sample query:**
```sql
SELECT
  evt_block_time,
  CAST(amount AS DOUBLE) / 1e6 AS amount_usdc,
  "from",
  depositId,
  token
FROM dojifunded_arbitrum.payoutvault_evt_reservedeposited
WHERE evt_block_time >= TIMESTAMP '2026-05-01'
ORDER BY evt_block_time DESC
LIMIT 20
```

---

### `payoutvault_evt_payoutexecuted` ← primary payout signal

Emitted when a trader payout is executed. Only 4 payouts have occurred so far (total ~685 USDC).

| Column | Type | Notes |
|---|---|---|
| `evt_block_time` | timestamp | |
| `evt_block_date` | date | |
| `evt_block_number` | bigint | |
| `evt_tx_hash` | varbinary | |
| `evt_tx_from` | varbinary | |
| `evt_tx_to` | varbinary | |
| `evt_tx_index` | integer | |
| `evt_index` | bigint | |
| `contract_address` | varbinary | |
| `amount` | uint256 | USDC 6-dec |
| `payoutId` | varbinary | unique payout identifier |
| `recipient` | varbinary | trader wallet receiving funds |
| `token` | varbinary | payout token (USDC) |

**Known payout recipients (since launch):**
- `0x7d61b004427aab1c71455421a70a8018a44f4d97` — 3 payouts: 345.11, 200.94, 127.20 USDC (Jun 2026)
- `0xfe66dfdbecbd98611753f84597843c442e8ef191` — 1 payout: 12.00 USDC (May 25 launch day)

---

### `payoutvault_evt_emergencywithdraw`

Emitted on emergency withdrawal of any token. No occurrences yet.

| Column | Type |
|---|---|
| `amount` | uint256 |
| `recipient` | varbinary |
| `token` | varbinary |

---

### `payoutvault_evt_nativewithdrawn`

Emitted when native ETH is swept out. No occurrences yet.

| Column | Type |
|---|---|
| `amount` | uint256 |
| `recipient` | varbinary |

---

### `payoutvault_evt_payoutlimitset`

Emitted when admin sets a rate limit (cap per rolling time window) for a payout token.

| Column | Type | Notes |
|---|---|---|
| `cap` | uint256 | max payout per window |
| `token` | varbinary | |
| `window` | uint256 | window size in seconds |

---

### `payoutvault_evt_dustthresholdset`

Emitted when the dust threshold (minimum meaningful balance) is configured for a token.

| Column | Type |
|---|---|
| `threshold` | uint256 |
| `token` | varbinary |

---

### `payoutvault_evt_payouttokensupportset`

Emitted when a token is enabled or disabled as a payout token.

| Column | Type |
|---|---|
| `enabled` | boolean |
| `token` | varbinary |

---

### Access-Control Events

| Table | Key Columns | Notes |
|---|---|---|
| `payoutvault_evt_rolegranted` | `account`, `role`, `sender` | role = bytes32 hash |
| `payoutvault_evt_rolerevoked` | `account`, `role`, `sender` | |
| `payoutvault_evt_roleadminchanged` | `role`, `previousAdminRole`, `newAdminRole` | |
| `payoutvault_evt_paused` | `account` | who triggered pause |
| `payoutvault_evt_unpaused` | `account` | who triggered unpause |

---

## Call Tables

Call tables capture decoded function arguments (and return values for views). Common metadata columns on all call tables: `contract_address`, `call_success` (boolean), `call_tx_hash`, `call_tx_from`, `call_tx_to`, `call_tx_index`, `call_trace_address`, `call_block_time`, `call_block_number`, `call_block_date`.

### State-Changing Calls

| Table | Input Columns | Notes |
|---|---|---|
| `payoutvault_call_depositreserve` | `amount` (uint256), `depositId` (varbinary), `token` (varbinary) | mirrors `evt_reservedeposited`; 106 rows |
| `payoutvault_call_executepayout` | `amount`, `payoutId`, `recipient`, `token` | mirrors `evt_payoutexecuted`; 4 rows |
| `payoutvault_call_emergencywithdraw` | `amount`, `recipient`, `token` | admin only |
| `payoutvault_call_sweepnative` | `amount`, `recipient` | sweeps ETH dust |
| `payoutvault_call_setpayoutlimit` | `cap`, `token`, `window` | rate-limit config |
| `payoutvault_call_setdustthreshold` | `threshold`, `token` | |
| `payoutvault_call_setpayouttokensupport` | `enabled` (boolean), `token` | |
| `payoutvault_call_pausepayoutvault` | _(no inputs)_ | |
| `payoutvault_call_unpausepayoutvault` | _(no inputs)_ | |
| `payoutvault_call_grantrole` | `account`, `role` | |
| `payoutvault_call_revokerole` | `account`, `role` | |
| `payoutvault_call_renouncerole` | `account`, `role` | |

### View / Read Calls

| Table | Input | Output Columns | Notes |
|---|---|---|---|
| `payoutvault_call_availablereserve` | `token` | `output_0` (uint256) | current available reserve for token |
| `payoutvault_call_totalreceived` | `_0` (token) | `output_0` (uint256) | cumulative received |
| `payoutvault_call_totalpaidout` | `_0` (token) | `output_0` (uint256) | cumulative paid out |
| `payoutvault_call_totalemergencywithdrawn` | `_0` (token) | `output_0` (uint256) | |
| `payoutvault_call_payoutlimits` | `_0` (token) | `output_cap`, `output_spent`, `output_window`, `output_windowStart` (all uint256) | current rate-limit state |
| `payoutvault_call_dustthreshold` | `_0` (token) | `output_0` (uint256) | |
| `payoutvault_call_ispayouttoken` | `token` | `output_0` (boolean) | |
| `payoutvault_call_paused` | _(none)_ | `output_0` (boolean) | |
| `payoutvault_call_processeddepositids` | `_0` (varbinary) | `output_0` (boolean) | idempotency check |
| `payoutvault_call_processedpayoutids` | `_0` (varbinary) | `output_0` (boolean) | idempotency check |
| `payoutvault_call_hasrole` | `account`, `role` | `output_0` (boolean) | |
| `payoutvault_call_getroleadmin` | `role` | `output_0` (varbinary) | |
| `payoutvault_call_supportsinterface` | `interfaceId` | `output_0` (boolean) | ERC-165 |

### Role Constant Readers

These return the bytes32 keccak hash for each named role.

| Table | Output |
|---|---|
| `payoutvault_call_default_admin_role` | `output_0` |
| `payoutvault_call_allocator_role` | `output_0` |
| `payoutvault_call_payout_operator_role` | `output_0` |
| `payoutvault_call_payout_pauser_role` | `output_0` |

---

## Query Patterns

### Total USDC deposited into reserve
```sql
SELECT
  SUM(CAST(amount AS DOUBLE)) / 1e6 AS total_deposited_usdc,
  COUNT(*) AS deposit_count
FROM dojifunded_arbitrum.payoutvault_evt_reservedeposited
WHERE evt_block_time >= TIMESTAMP '2026-05-01'
```

### Total USDC paid out to traders
```sql
SELECT
  SUM(CAST(amount AS DOUBLE)) / 1e6 AS total_paid_usdc,
  COUNT(*) AS payout_count,
  COUNT(DISTINCT recipient) AS unique_recipients
FROM dojifunded_arbitrum.payoutvault_evt_payoutexecuted
WHERE evt_block_time >= TIMESTAMP '2026-05-01'
```

### Reserve health: received vs paid out
```sql
WITH deposits AS (
  SELECT SUM(CAST(amount AS DOUBLE)) / 1e6 AS total_in
  FROM dojifunded_arbitrum.payoutvault_evt_reservedeposited
  WHERE evt_block_time >= TIMESTAMP '2026-05-01'
),
payouts AS (
  SELECT SUM(CAST(amount AS DOUBLE)) / 1e6 AS total_out
  FROM dojifunded_arbitrum.payoutvault_evt_payoutexecuted
  WHERE evt_block_time >= TIMESTAMP '2026-05-01'
)
SELECT
  total_in,
  total_out,
  total_in - total_out AS net_reserve_usdc
FROM deposits, payouts
```

---

## Key Notes

- **`"from"` must be double-quoted** in DuneSQL — it is a reserved keyword.
- **`amount` is `uint256`** — cast with `CAST(amount AS DOUBLE) / 1e6` for USDC values.
- **`depositId` / `payoutId`** are unique bytes32 identifiers used for idempotency; the contract tracks processed IDs in `processeddepositids` / `processedpayoutids` mappings.
- **Rate limiting**: the vault enforces a `cap` per rolling `window` (seconds) per token, tracked in `payoutlimits`. Inspect `payoutvault_evt_payoutlimitset` for configured limits.
- **All deposits funnel through Deposit Reserve A** (`0x98d4077a5c448529d20d233d36780e3a99db541e`), which is the same address as the trader-facing entry point. The call to `depositReserve` is how that contract pushes USDC across.
- **Payouts are USDC-only** so far (`0xaf88d065e77c8cC2239327C5EDb3A432268e5831`).