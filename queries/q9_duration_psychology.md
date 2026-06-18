# Q9 — "Diamond Hands" vs. Scalpers (Duration Psychology)

**File:** `queries/q9_duration_psychology.sql`
**Dune ID:** (not yet saved)
**Source table:** `dojifunded_arbitrum.dojitradenft_call_minttrade`

## Purpose

Categorizes every closed trade by how long it was held and compares win rate, average PnL, and hold-time behavior across four duration buckets. Also computes the **"Hope" Ratio** — whether traders hold losing positions longer than winning ones, a classic retail bias signal.

## Duration Buckets

| Label | Range |
|---|---|
| `1. Scalp (< 5m)` | < 300 seconds |
| `2. Day (5m - 4h)` | 300 – 14 399 seconds |
| `3. Extended Day (4h - 24h)` | 14 400 – 86 399 seconds |
| `4. Swing (> 24h)` | ≥ 86 400 seconds |

## Output Columns

| Column | Description |
|---|---|
| `trading_style` | Duration bucket label (prefix-sorted) |
| `total_trades` | Number of trades in this bucket |
| `win_rate_pct` | % of trades with positive PnL |
| `avg_pnl_usd` | Mean realized PnL per trade (USD) |
| `total_pnl_usd` | Sum of all realized PnL in the bucket (USD) |
| `avg_winner_hold_minutes` | Average hold time for winning trades (minutes) |
| `avg_loser_hold_minutes` | Average hold time for losing trades (minutes) |
| `loser_to_winner_hold_ratio` | `avg_loser_hold / avg_winner_hold` — values > 1 indicate the "hope" bias |

## CTE Structure

```
call_minttrade
    └── trades        extract openedAt, closedAt, realizedPnl from JSON data
         └── durations  compute duration_seconds, assign trading_style, label Win/Loss
              └── SELECT  aggregate per bucket
```

## Design Notes

- **Source:** `call_minttrade` (not `evt_trademinted`) because `openedAt` and `closedAt` are only in the full `data` JSON blob, not emitted in the event.
- **Zero-duration filter:** `closedAt > openedAt` drops any rows where timestamps are equal or inverted (data integrity guard).
- **`CASE WHEN` aggregation:** DuneSQL (Trino) does not support `AGG(...) FILTER (WHERE ...)` syntax — conditional aggregation uses `AVG(CASE WHEN ... THEN col END)` instead.
- **Hope Ratio:** `NULL` if there are no winning trades in a bucket (`NULLIF` guard). A ratio > 1 means losers were held longer on average than winners — evidence of traders cutting winners early and riding losses.
- **Excludes** internal testing wallet `0xf60ffefeea868d0a77d5b055df07c18022c7f7bc`.
