# Phase 3: Production Hardening (Дни 8-14)

**📍 Navigation**: [← Back to Plan v3.0](../../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)

---

## 🎯 Цель Фазы

Подготовить систему к **production deployment**:
- Observability (logs, metrics, traces)
- Disaster Recovery automation
- Blue-Green deployment pattern
- Alerting и monitoring
- GitOps compliance

---

## 3.1 Observability Stack

**Файл**: `lib/observability.sh`

**Краткое описание**:
- Structured logging (JSON lines)
- Metrics collection (Prometheus-compatible)
- Distributed tracing (trace IDs)
- Event correlation

**Ключевые функции**:
```bash
log_event()         # Structured logging
collect_metrics()   # Metrics collection
start_trace()       # Distributed tracing
send_to_datadog()   # External monitoring
```

**Интеграция**:
- Автоматическое логирование каждой операции
- Метрики производительности (latency, throughput)
- Trace IDs для debugging
- Dashboard-ready формат

**Файлы логов**:
- `~/.claude-docker-events.jsonl` - Structured events
- `~/.claude-docker-metrics.jsonl` - Metrics
- `~/.claude-docker-traces/` - Distributed traces

---

## 3.2 Disaster Recovery

**Файл**: `lib/disaster_recovery.sh`

**Краткое описание**:
- Automated disaster recovery runbook
- Multi-backup verification
- One-command recovery
- Post-recovery validation

**Ключевые функции**:
```bash
disaster_recovery()       # Полная DR процедура
find_good_backup()        # Поиск последнего валидного backup
restore_from_backup()     # Восстановление из backup
verify_recovery()         # Проверка целостности после DR
```

**Триггеры DR**:
- Fatal sync errors
- Config corruption detected
- Manual invocation

**Recovery Targets**:
- **RTO** (Recovery Time Objective): < 5 минут
- **RPO** (Recovery Point Objective): < 1 час (последний backup)

---

## 3.3 Blue-Green Deployment

**Файл**: `lib/deployment.sh`

**Краткое описание**:
- Feature toggle для новой версии
- Canary deployment (10% → 50% → 100%)
- Automated rollback на ошибках
- Zero-downtime migration

**Ключевые функции**:
```bash
deploy_canary()          # Canary deployment
rollback_deployment()    # Automated rollback
run_smoke_tests()        # Post-deploy validation
track_deployment()       # Metrics tracking
```

**Deployment Process**:
```bash
# 1. Deploy to 10% users
CLAUDE_DOCKER_V2_PROBABILITY=0.1 deploy_canary

# 2. Monitor metrics (error rate, latency)
# 3. If OK → increase to 50%
CLAUDE_DOCKER_V2_PROBABILITY=0.5 deploy_canary

# 4. If OK → full rollout
CLAUDE_DOCKER_V2_PROBABILITY=1.0 deploy_canary

# 5. If errors → auto-rollback
# rollback_deployment (automatic on threshold breach)
```

**Rollback Triggers**:
- Error rate > 10% for 5 minutes
- P95 latency > 15s
- Smoke tests failed
- Critical alert triggered

---

## 3.4 GitOps Integration

**Файл**: `lib/gitops.sh`

**Краткое описание**:
- Config-as-Code в Git
- Encrypted secrets (SOPS/age)
- Drift detection
- Reconciliation loop
- Audit trail

**Ключевые функции**:
```bash
encrypt_secrets()        # SOPS encryption
reconcile_config()       # Git → Runtime sync
detect_drift()           # Config drift detection
audit_config_change()    # Change tracking
```

**GitOps Workflow**:
```
1. Developer: Edit .claude/settings.json
2. Commit to Git
3. CI validates config
4. Reconciliation loop detects change
5. Auto-sync to ~/.claude/
6. Verification + health check
7. If failed → auto-rollback
```

**Setup SOPS Encryption**:
```bash
# 1. Install SOPS + age
brew install sops age

# 2. Generate key
age-keygen -o ~/.config/sops/age/keys.txt

# 3. Configure SOPS
cat > .sops.yaml <<SOPS
creation_rules:
  - path_regex: \.claude/\.claude\.json\.enc$
    age: <YOUR_AGE_PUBLIC_KEY>
SOPS

# 4. Encrypt secrets
sops --encrypt .claude/.claude.json > .claude/.claude.json.enc
git add .claude/.claude.json.enc
echo ".claude/.claude.json" >> .gitignore
```

**Reconciliation Loop** (background service):
```bash
gitops_reconcile_loop() {
  while true; do
    # Pull latest from Git
    git pull origin main --quiet

    # Detect changes
    if config_changed_since_last_run; then
      # Decrypt secrets
      decrypt_secrets

      # Validate
      validate_claude_config || continue

      # Apply
      sync_claude_config_in

      # Verify
      smoke_test || rollback_config
    fi

    sleep 60  # Check every minute
  done
}
```

---

## 3.5 Alerting System

**Файл**: `lib/alerting.sh`

**Краткое описание**:
- Rule-based alerting
- Multiple channels (desktop, Slack, email)
- Alert throttling
- Incident tracking

**Alert Rules**:

### High Priority
- Error rate > 5% for 5 minutes
- No successful run in 1 hour
- 5+ orphaned containers
- Data corruption detected

### Medium Priority
- Latency P95 > 10s
- Disk usage > 80%
- 3+ sync failures in 1 hour

### Low Priority
- Backup older than 24h
- Config drift detected

**Alert Channels**:
```bash
# Desktop notification (macOS)
osascript -e 'display notification "Error rate critical" with title "Claude Docker Alert"'

# Slack webhook
curl -X POST "$SLACK_WEBHOOK_URL" \
  -H 'Content-Type: application/json' \
  -d '{"text":"🚨 Claude Docker: Error rate > 5%"}'

# Email (via sendmail)
echo "Error rate critical" | mail -s "Claude Docker Alert" admin@example.com
```

**Alert Throttling**:
- Same alert не чаще чем раз в 15 минут
- Max 10 alerts per hour
- Escalation при повторных alerts

---

## 📋 Phase 3 Checklist

- [ ] Создать `lib/observability.sh`
- [ ] Создать `lib/disaster_recovery.sh`
- [ ] Создать `lib/deployment.sh`
- [ ] Создать `lib/gitops.sh`
- [ ] Создать `lib/alerting.sh`
- [ ] Интегрировать в `ai-assistant.zsh`
- [ ] Настроить monitoring dashboard
- [ ] Протестировать DR process
- [ ] Коммит: `git commit -m "feat(phase3): production hardening"`

---

**🔗 Next**: [Phase 4: Testing & Validation](./PHASE4_TESTING.md)

**📍 Navigation**: [← Back to Plan v3.0](../../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)
