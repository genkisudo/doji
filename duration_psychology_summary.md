# Analytics Insight: Duration Psychology ("Diamond Hands" vs. Scalpers)

This analysis explores the psychological profile of DojiFunded traders by analyzing their hold times. It uses the `openedAt` and `closedAt` timestamps from the on-chain `TradeMetadata` struct.

## Methodology

Trades are categorized into four distinct styles:
- **Scalp:** < 5 minutes
- **Day:** 5 minutes – 4 hours
- **Extended Day:** 4 hours – 24 hours
- **Swing:** > 24 hours

## Key Psychological Indicators

### 1. The "Hope" Ratio (Loser-to-Winner Hold Time)
A classic retail trading mistake is cutting winning trades early while holding losing trades in the "hope" that they will reverse. 
- **Hope Ratio = (Average Loser Hold Time) / (Average Winner Hold Time)**
- **Interpretation:** A ratio significantly greater than 1.0 suggests a cohort is struggling with risk management and emotional attachment to losing positions.

### 2. Style Profitability
Which cohort actually generates the most PnL on the platform? Do scalpers get eaten by fees while swing traders capture the big moves?

### 3. Hold Time per Result
This metric breaks down exactly how long a cohort stays in a winning trade vs. a losing trade, providing a clear visual of their "patience" for profit vs. their "tolerance" for pain.

## Implementation Details

The query `queries/q9_duration_psychology.sql` utilizes the `dojitradenft_call_minttrade` table to access the full `TradeMetadata` struct via JSON extraction.

```sql
-- Style Bucket Logic
CASE
    WHEN (closed_at - opened_at) < 300 THEN '1. Scalp (< 5m)'
    WHEN (closed_at - opened_at) < 14400 THEN '2. Day (5m - 4h)'
    WHEN (closed_at - opened_at) < 86400 THEN '3. Extended Day (4h - 24h)'
    ELSE '4. Swing (> 24h)'
END AS trading_style
```

## Dashboard Utilization

This query is ideal for:
- **Leaderboard Filters:** Showing the "Top Scalper" vs. "Top Swing Trader".
- **Risk Management Education:** Warning traders if their "Hope Ratio" is becoming dangerously high.
- **Platform Marketing:** Proving that the platform supports diverse trading styles effectively.
