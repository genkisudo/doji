# Q10 — Trader Payouts from PayoutVault

**File:** `queries/q10_trader_payouts.sql`
**Dune ID:** (not yet saved)
**Source table:** `dojifunded_arbitrum.payoutvault_evt_payoutexecuted`

## Purpose

Full audit log of every on-chain trader payout approved by the platform, with running totals per recipient and across the platform. Suitable as a backing query for a Payouts dashboard section.

## What it produces

One row per payout, ordered newest-first:

| Column | Description |
|---|---|
| `payout_num` | Sequential payout number (chronological) |
| `paid_at` | Block timestamp of the payout |
| `recipient` | Trader wallet that received funds |
| `amount_usdc` | Amount paid in this transaction |
| `recipient_running_total_usdc` | Cumulative paid to this recipient up to this row |
| `platform_running_total_usdc` | Cumulative paid to all recipients up to this row |
| `recipient_total_payouts` | Total number of payouts this recipient has ever received |
| `recipient_total_usdc` | Total USDC ever paid to this recipient |
| `tx_hash` | Transaction hash |
| `payout_id` | Unique bytes32 idempotency key from the contract |

## Live Results (as of 2026-06-18)

4 payouts — **685.248 USDC total** — 2 recipients

| # | Date | Recipient | Amount (USDC) | Recipient Total | Platform Total |
|---|---|---|---|---|---|
| 4 | 2026-06-15 04:27 | `0x7d61b004...f4d97` | 345.11 | 673.25 | 685.25 |
| 3 | 2026-06-14 12:44 | `0x7d61b004...f4d97` | 200.94 | 328.14 | 340.14 |
| 2 | 2026-06-14 03:51 | `0x7d61b004...f4d97` | 127.20 | 127.20 | 139.20 |
| 1 | 2026-05-25 18:22 | `0xfe66dfdb...f191`  | 12.00  | 12.00  | 12.00  |

**Recipient breakdown:**
- `0x7d61b004427aab1c71455421a70a8018a44f4d97` — 3 payouts, **673.248 USDC** (all in June 2026)
- `0xfe66dfdbecbd98611753f84597843c442e8ef191` — 1 payout, **12.00 USDC** (launch day, May 25)

## Design Notes

- Filters `token = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831` (real USDC) so the query stays safe if the vault ever supports additional tokens.
- Window functions compute running totals without a self-join — both per-recipient and platform-wide in one pass.
- `by_recipient` CTE pre-aggregates lifetime stats so each detail row carries the full recipient summary without re-scanning.
- `payout_id` is exposed for cross-referencing with backend records (the contract enforces uniqueness on-chain).
