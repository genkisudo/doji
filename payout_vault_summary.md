# PayoutVault Contract Summary

**File:** `payout_vault.sol`  
**Chain:** Arbitrum  
**Address:** `0x1016bC039A4aB6008d38EAD798b4E29361a2D6eA` *(Reserve B — confirmed by ReserveDeposited event in tx logs)*

---

## What It Does

Holds the payout-reserve share of plan purchases and executes approved trader payouts. Business logic (how much goes to reserve vs. fees) lives in the backend; this contract only enforces custody and payout safety.

---

## Roles

| Role | Holder type | What they can do |
|---|---|---|
| `DEFAULT_ADMIN_ROLE` | Multisig (Timelock-governed) | Grant roles, emergency withdraw (paused only) |
| `ALLOCATOR_ROLE` | Backend hot wallet | Deposit reserve funds (`depositReserve`) |
| `PAYOUT_OPERATOR_ROLE` | Backend hot wallet | Execute trader payouts (`executePayout`) |
| `PAYOUT_PAUSER_ROLE` | Admin | Pause / unpause the vault |

---

## Key Events (most valuable for Dune analytics)

| Event | Signature | What it tells you |
|---|---|---|
| `ReserveDeposited` | `(bytes32 depositId, address token, address from, uint256 amount)` | Funds allocated into the vault per plan purchase |
| `PayoutExecuted` | `(bytes32 payoutId, address token, address recipient, uint256 amount)` | **Trader payout** — who got paid, how much, in what token |
| `EmergencyWithdraw` | `(address token, address recipient, uint256 amount)` | Admin emergency drain (paused state only) |
| `NativeWithdrawn` | `(address payable recipient, uint256 amount)` | ETH sweep (force-sent ETH only) |
| `PayoutTokenSupportSet` | `(address token, bool enabled)` | Token whitelist changes |
| `PayoutLimitSet` | `(address token, uint256 cap, uint256 window)` | Rolling payout cap configuration |
| `DustThresholdSet` | `(address token, uint256 threshold)` | Dust threshold changes |

---

## Analytics Unlocked After Decoding

- **Total USDC paid out to traders** — sum of `PayoutExecuted.amount`
- **Per-trader payout history** — group `PayoutExecuted` by `recipient`
- **Reserve vs. payout ratio** — `ReserveDeposited` vs. `PayoutExecuted` over time
- **Vault health** — running `availableReserve` = `totalReceived - totalPaidOut - totalEmergencyWithdrawn`
- **Payout frequency** — daily/weekly payout counts and volumes

---

## Contract Properties (for Dune submission)

| Property | Value |
|---|---|
| Proxy? | No — standard implementation contract |
| Multiple instances? | No — single deployed address |
| Factory-created? | No |
| Verified on Arbiscan? | TBD |
| ABI source | `payout_vault.sol` (available locally) |

---

## Deposit Flow (two-hop context)

```
Trader wallet
    │  USDC Transfer
    ▼
Reserve A  (0x98D4077A5C448529d20D233d36780e3A99dB541E)   ← trader-facing
    │  USDC Transfer  +  depositReserve() call
    ▼
PayoutVault / Reserve B  (0x1016bC039A4aB6008d38EAD798b4E29361a2D6eA)
    │  emits ReserveDeposited
    │
    └─ executePayout() ──► Trader wallet  (emits PayoutExecuted)
```
