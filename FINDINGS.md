# Findings — Accept / Push Back

| # | Finding | Response |
|---|---------|----------|
| F-1 | API Gateway has no authentication | **Accept.** Demo scope; `api_gateway.tf` already flags it and names an SSM-backed API key as the easy next step. |
| F-2 | No DynamoDB TTL — `portfolio_history` grows ~2,880 rows/month forever | **Accept + Fixed** → commit `ca6048f` (see below). |
| F-3 | Single `"default"` partition key on both tables | **Push back.** The code comment explicitly scopes this as a single-portfolio project; at one `put_item` per 15 minutes there is zero hot-partition risk. |

---

## Fix — commit `ca6048f`

**Problem:** `portfolio_history` has no expiry policy. At the default 15-minute poll rate that is ~2,880 new items per month with no upper bound — a latent cost and operational hygiene issue.

**Two files changed, zero new AWS resources:**

### `terraform/dynamodb.tf`
```hcl
resource "aws_dynamodb_table" "portfolio_history" {
  # ... existing keys unchanged ...

  # NEW: DynamoDB deletes rows automatically after expires_at. Free feature.
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
}
```

### `lambda/poller/handler.py`
```python
# Added timedelta to existing datetime import
from datetime import datetime, timezone, timedelta

# Added inside lambda_handler, before put_item:
expires_at = int((datetime.now(timezone.utc) + timedelta(days=90)).timestamp())

item = {
    "portfolio_id":    PORTFOLIO_ID,
    "timestamp":       timestamp,
    "expires_at":      expires_at,   # ← new: Unix epoch, DynamoDB deletes after this
    "total_value_usd": round(total_value, 2),
    "breakdown":       breakdown,
}
```

**Result:** table is now bounded at ~12,960 items (90 days × 96 polls/day). The `/current` and `/history` endpoints are unaffected — they query by `portfolio_id + timestamp`, not `expires_at`. TTL deletion is free.
