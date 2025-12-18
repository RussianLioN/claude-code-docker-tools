# SLO/SLA Definitions

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)

---

## Service Level Objectives (SLOs)

| Метрика | Target | Measurement Window | Enforcement |
|---------|--------|-------------------|-------------|
| **Availability** | 99.9% | 30 days | Alert if < 99.5% |
| **Latency (P50)** | < 2s | 1 hour | Alert if > 3s |
| **Latency (P95)** | < 5s | 1 hour | Alert if > 7s |
| **Latency (P99)** | < 10s | 1 hour | Alert if > 15s |
| **Error Rate** | < 1% | 1 hour | Alert if > 5% |
| **Data Loss** | 0% | Always | CRITICAL alert immediately |

## Service Level Indicators (SLIs)

**Measured via**:

```bash
# Availability SLI
successful_invocations / total_invocations * 100

# Latency SLI (from metrics)
jq -s 'map(select(.metric == "claude.invocation.duration")) |
       sort_by(.value) | .[length * 0.95 | floor].value' \
  ~/.claude-docker-metrics.jsonl

# Error Rate SLI
error_count / total_invocations * 100
```

## Error Budget

**Monthly error budget**:

- Total time: 730 hours (30 days)
- Target uptime: 99.9%
- Allowed downtime: **43.8 minutes/month**

**Error budget consumption**:

```bash
# If error rate = 5% for 1 hour
# Consumed: 1 hour * 5% = 3 minutes of budget

# Remaining: 43.8 - 3 = 40.8 minutes
```

**Policy**: При исчерпании бюджета → заморозить новые features, фокус на reliability.

---

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)
