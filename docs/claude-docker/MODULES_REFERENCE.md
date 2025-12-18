# Modules Reference

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)

---

## Модульная Архитектура

Все критичные компоненты вынесены в отдельные модули для переиспользования:

| Модуль | Путь | Назначение | Статус |
|--------|------|------------|--------|
| **Backup** | [lib/backup.sh](../../lib/backup.sh) | 3-2-1 backup strategy | ✅ Phase 1 |
| **Validation** | [lib/validation.sh](../../lib/validation.sh) | Config validation | ✅ Phase 1 |
| **Error Handling** | [lib/error_handling.sh](../../lib/error_handling.sh) | Centralized errors | ✅ Phase 1 |
| **Keychain** | [lib/keychain.sh](../../lib/keychain.sh) | macOS Keychain integration | ✅ Phase 2 |
| **Sync** | [lib/sync.sh](../../lib/sync.sh) | Bidirectional sync | ✅ Phase 2 |
| **Observability** | [lib/observability.sh](../../lib/observability.sh) | Logs/metrics/traces | 📋 Phase 3 |
| **Disaster Recovery** | [lib/disaster_recovery.sh](../../lib/disaster_recovery.sh) | Automated DR | 📋 Phase 3 |
| **Deployment** | [lib/deployment.sh](../../lib/deployment.sh) | Blue-green deployment | 📋 Phase 3 |
| **GitOps** | [lib/gitops.sh](../../lib/gitops.sh) | Config-as-Code | 📋 Phase 3 |
| **Alerting** | [lib/alerting.sh](../../lib/alerting.sh) | Alert management | 📋 Phase 3 |

---

## Sourcing в ai-assistant.zsh

```bash
# После строки 175: Source всех модулей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Phase 1 modules
source "${SCRIPT_DIR}/lib/backup.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/validation.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/error_handling.sh" 2>/dev/null || true

# Phase 2 modules
source "${SCRIPT_DIR}/lib/keychain.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/sync.sh" 2>/dev/null || true

# Phase 3 modules
source "${SCRIPT_DIR}/lib/observability.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/disaster_recovery.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/deployment.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/gitops.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/alerting.sh" 2>/dev/null || true
```

---

## Module: backup.sh (Phase 1)

**Назначение**: 3-2-1 Backup Strategy

**Ключевые функции**:
- `backup_claude_data()` - Полный backup (3 копии)
- `pre_sync_backup()` - Быстрый backup перед sync
- `verify_backup()` - Проверка целостности backup

**Locations**:
- Copy 1: `~/.claude-backups/` (local, incremental)
- Copy 2: `/Volumes/TimeMachine/claude-backups/` (external)
- Copy 3: `rclone:remote/claude-backups/` (cloud)

**Retention**: 30 дней

---

## Module: validation.sh (Phase 1)

**Назначение**: Config validation

**Ключевые функции**:
- `validate_claude_config()` - Validate ~/.claude structure
- `validate_docker_environment()` - Check Docker availability
- `verify_sync_integrity()` - Post-sync verification

**Validation Checks**:
- JSON syntax (jq validation)
- OAuth tokens presence
- Critical files exist
- File sizes match after sync

---

## Module: error_handling.sh (Phase 1)

**Назначение**: Centralized error handling

**Ключевые функции**:
- `log_error()` - Structured error logging
- `fatal_error()` - Fatal errors with recovery trigger
- `cleanup_on_error()` - Emergency cleanup
- `error_trap_handler()` - Trap handler for unexpected errors

**Error Log**: `~/.claude-docker-errors.log` (JSON format)

---

## Module: keychain.sh (Phase 2)

**Назначение**: macOS Keychain integration

**Ключевые функции**:
- `extract_keychain_credentials()` - Extract OAuth from Keychain
- `store_to_keychain()` - Store credentials back to Keychain

**Services**:
- `claude.ai` - Access token
- `claude.ai.refresh` - Refresh token

**macOS only**: Gracefully skips on non-Darwin systems

---

## Module: sync.sh (Phase 2)

**Назначение**: Bidirectional sync with data protection

**Ключевые функции**:
- `sync_claude_config_in()` - Host → Container sync
- `sync_claude_config_out()` - Container → Host sync
- `fix_mcp_paths()` - MCP server path rewriting
- `normalize_session_history()` - Session path normalization
- `acquire_sync_lock()` / `release_sync_lock()` - Locking

**Sync Excludes**:
- `debug/`, `shell-snapshots/`, `statsig/`
- `.DS_Store`, `*.log`, `*.tmp`

**Lock**: `/tmp/claude-config-sync.lock` (30s timeout)

---

## Module: observability.sh (Phase 3)

**Назначение**: Logs/Metrics/Traces

**Ключевые функции**:
- `log_event()` - Structured event logging
- `collect_metrics()` - Metrics collection
- `start_trace()` / `end_trace()` - Distributed tracing
- `send_to_datadog()` - External monitoring integration

**Outputs**:
- `~/.claude-docker-events.jsonl` - Events (JSON lines)
- `~/.claude-docker-metrics.jsonl` - Metrics
- `~/.claude-docker-traces/` - Trace files

**Format**: JSON lines (ready for log aggregation)

---

## Module: disaster_recovery.sh (Phase 3)

**Назначение**: Automated disaster recovery

**Ключевые функции**:
- `disaster_recovery()` - Full DR process
- `find_good_backup()` - Find last valid backup
- `restore_from_backup()` - Restore from backup
- `verify_recovery()` - Post-recovery validation

**Triggers**:
- Fatal sync errors
- Config corruption detected
- Manual invocation: `disaster_recovery`

**Targets**:
- **RTO**: < 5 minutes
- **RPO**: < 1 hour

---

## Module: deployment.sh (Phase 3)

**Назначение**: Blue-green deployment

**Ключевые функции**:
- `deploy_canary()` - Canary deployment (10% → 50% → 100%)
- `rollback_deployment()` - Automated rollback
- `run_smoke_tests()` - Post-deploy validation
- `track_deployment()` - Deployment metrics

**Feature Toggle**: `CLAUDE_DOCKER_V2_PROBABILITY` (0.0 to 1.0)

**Rollback Triggers**:
- Error rate > 10%
- P95 latency > 15s
- Smoke tests failed

---

## Module: gitops.sh (Phase 3)

**Назначение**: Config-as-Code (GitOps compliance)

**Ключевые функции**:
- `encrypt_secrets()` - SOPS/age encryption
- `reconcile_config()` - Git → Runtime sync
- `detect_drift()` - Config drift detection
- `audit_config_change()` - Change tracking

**GitOps Workflow**:
1. Edit config in Git
2. CI validates
3. Reconciliation loop detects change
4. Auto-sync to runtime
5. Verification + rollback if needed

**Encryption**: SOPS with age keys

---

## Module: alerting.sh (Phase 3)

**Назначение**: Alert management

**Ключевые функции**:
- `send_alert()` - Send alert to channels
- `check_alert_rules()` - Evaluate alert rules
- `throttle_alert()` - Alert throttling (15 min)
- `escalate_alert()` - Escalation logic

**Alert Channels**:
- Desktop notification (macOS)
- Slack webhook
- Email (sendmail)

**Alert Priorities**:
- High: Error rate > 5%, orphaned containers, data corruption
- Medium: P95 > 10s, disk > 80%, sync failures
- Low: Backup old, config drift

---

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)
