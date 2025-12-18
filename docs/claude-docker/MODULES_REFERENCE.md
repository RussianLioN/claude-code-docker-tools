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

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)
