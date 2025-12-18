# SLO/SLA Definitions & Metrics

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

---

## Service Level Indicators (SLIs)

### Availability SLI

**Definition**: Percentage of successful Claude invocations

**Measurement**:
```bash
successful_invocations / total_invocations * 100
```

**Query**:
```bash
jq -s 'group_by(.event) |
       map({event: .[0].event, count: length}) |
       map(select(.event == "claude_end")) |
       .[0].count' \
  ~/.claude-docker-events.jsonl
```

**Target**: ≥ 99.9%

---

### Latency SLI

**Definition**: Time from `claude_start` to `claude_end`

**Measurement**:
```bash
# P95 latency
jq -s 'map(select(.metric == "claude.invocation.duration")) |
       sort_by(.value) |
       .[length * 0.95 | floor].value' \
  ~/.claude-docker-metrics.jsonl
```

**Targets**:
- P50: < 2s
- P95: < 5s
- P99: < 10s

---

### Error Rate SLI

**Definition**: Percentage of failed invocations

**Measurement**:
```bash
error_count / total_invocations * 100
```

**Query**:
```bash
# Count errors in last hour
jq -s --arg since "$(date -v-1H -Iseconds)" \
  'map(select(.timestamp >= $since and .level == "ERROR")) |
   length' \
  ~/.claude-docker-events.jsonl
```

**Target**: < 1%

---

## Error Budget

### Monthly Error Budget

**Calculation**:
- Total time: 730 hours (30 days)
- Target uptime: 99.9%
- Allowed downtime: **43.8 minutes/month**

**Example**:
```
If error rate = 5% for 1 hour:
  Consumed: 1 hour * 5% = 3 minutes of budget
  Remaining: 43.8 - 3 = 40.8 minutes
```

### Error Budget Policy

**Budget consumption tracking**:
```bash
# Calculate error budget spent
jq -s 'map(select(.level == "ERROR")) |
       group_by(.timestamp[:10]) |
       map({date: .[0].timestamp[:10], errors: length})' \
  ~/.claude-docker-events.jsonl
```

**Policy**:
- **Budget healthy (> 50%)**: Continue feature development
- **Budget low (20-50%)**: Reduce deployment frequency
- **Budget critical (< 20%)**: Freeze features, focus on reliability
- **Budget exhausted (0%)**: Emergency reliability work only

---

## Monitoring Dashboard

### Real-time Metrics

**Terminal Dashboard**:
```bash
#!/bin/bash
# Quick metrics dashboard

echo "=== Claude Docker Metrics ==="
echo ""

# Availability (last 24h)
uptime=$(jq -s --arg since "$(date -v-24H -Iseconds)" \
  'map(select(.timestamp >= $since)) |
   group_by(.event) |
   map({event: .[0].event, count: length}) |
   (map(select(.event == "claude_end"))[0].count // 0) as $success |
   (map(select(.event == "claude_start"))[0].count // 0) as $total |
   if $total > 0 then ($success / $total * 100) else 100 end' \
  ~/.claude-docker-events.jsonl)
echo "Availability (24h): $uptime%"

# P95 Latency (last hour)
p95=$(jq -s --arg since "$(date -v-1H +%s)" \
  'map(select(.timestamp >= ($since | tonumber) and
              .metric == "claude.invocation.duration")) |
   sort_by(.value) |
   .[length * 0.95 | floor].value // 0' \
  ~/.claude-docker-metrics.jsonl)
echo "P95 Latency (1h): ${p95}ms"

# Error rate (last hour)
errors=$(jq -s --arg since "$(date -v-1H -Iseconds)" \
  'map(select(.timestamp >= $since and .level == "ERROR")) |
   length' \
  ~/.claude-docker-events.jsonl)
echo "Errors (1h): $errors"

# Orphaned containers
orphaned=$(docker ps -a -q -f name=claude-session | wc -l)
echo "Orphaned containers: $orphaned"

# Disk usage
disk=$(df -h ~ | awk 'NR==2 {print $5}')
echo "Disk usage: $disk"

# Backup age
if [[ -d ~/.claude-backups/latest ]]; then
  backup_age=$(( ($(date +%s) - $(stat -f%m ~/.claude-backups/latest)) / 3600 ))
  echo "Last backup: ${backup_age}h ago"
fi
```

### Grafana Dashboard (Optional)

**Prometheus metrics export**:
```bash
# Export metrics for Prometheus
cat ~/.claude-docker-metrics.jsonl | jq -r '
  "claude_invocation_duration_seconds{\(.tags | to_entries | map("\(.key)=\"\(.value)\"") | join(","))} \(.value / 1000) \(.timestamp)"
' > /var/lib/prometheus/claude-metrics.prom
```

**Example Grafana queries**:
```promql
# Availability
sum(rate(claude_invocation_total{status="success"}[5m])) /
sum(rate(claude_invocation_total[5m])) * 100

# P95 Latency
histogram_quantile(0.95, rate(claude_invocation_duration_seconds_bucket[5m]))

# Error rate
sum(rate(claude_invocation_total{status="error"}[5m])) /
sum(rate(claude_invocation_total[5m])) * 100
```

---

## Alerting Rules

### Critical Alerts

**Rule 1: Data Loss**
```yaml
alert: ClaudeDataLoss
expr: claude_sync_integrity_errors > 0
for: 0m
severity: critical
action: Immediate disaster recovery
```

**Rule 2: Error Rate Critical**
```yaml
alert: ClaudeErrorRateCritical
expr: rate(claude_invocation_total{status="error"}[5m]) > 0.05
for: 5m
severity: critical
action: Auto-rollback deployment
```

### High Priority Alerts

**Rule 3: Availability SLO Breach**
```yaml
alert: ClaudeAvailabilitySLOBreach
expr: availability_24h < 99.5
for: 1h
severity: high
action: Investigate root cause
```

**Rule 4: Latency SLO Breach**
```yaml
alert: ClaudeLatencySLOBreach
expr: claude_p95_latency > 7000
for: 15m
severity: high
action: Performance investigation
```

### Medium Priority Alerts

**Rule 5: Disk Usage**
```yaml
alert: ClaudeDiskUsageHigh
expr: disk_usage_percent > 80
for: 1h
severity: medium
action: Cleanup old backups
```

**Rule 6: Orphaned Containers**
```yaml
alert: ClaudeOrphanedContainers
expr: claude_orphaned_containers > 5
for: 30m
severity: medium
action: Investigate cleanup issue
```

---

## Performance Targets

### Startup Performance
- **Cold start**: < 3s (first invocation)
- **Warm start**: < 1s (config cached)
- **Container spawn**: < 2s

### Runtime Performance
- **Sync IN**: < 500ms
- **Sync OUT**: < 500ms
- **Command latency**: P50 < 2s, P95 < 5s

### Resource Usage
- **Memory per container**: < 512MB
- **CPU usage**: < 10% idle, < 50% active
- **Disk I/O**: < 10MB/s

### Scalability
- **Max concurrent sessions**: 20+
- **Session startup rate**: 5/second
- **Total system memory**: < 8GB for 10 sessions

---

## SLA Commitments

**For Production Users**:

| Service Tier | Availability | Support Response | Downtime/Month |
|--------------|--------------|------------------|----------------|
| **Free** | 95% | Best effort | 36 hours |
| **Pro** | 99.5% | < 4 hours | 3.6 hours |
| **Enterprise** | 99.9% | < 1 hour | 43.8 minutes |

**Compensation Policy**:
- **99.5% SLA breach**: 10% credit
- **99.0% SLA breach**: 25% credit
- **< 99.0%**: 50% credit

---

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)
