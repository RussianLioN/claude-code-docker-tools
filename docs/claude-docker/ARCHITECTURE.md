# Production Architecture

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)

---

## Архитектурная Диаграмма

```
┌─────────────────────────────────────────────────────────────┐
│                     macOS Host System                        │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Config Sources (Highest Priority)                   │  │
│  │  ├─ macOS Keychain (OAuth tokens) ← EXTRACTED       │  │
│  │  ├─ ~/.claude.json (OAuth, MCP, UI prefs)           │  │
│  │  ├─ ~/.claude/settings.json (User settings)         │  │
│  │  └─ ~/.claude/projects/ (Session history)           │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Backup Layer (3-2-1 Strategy)                       │  │
│  │  ├─ Copy 1: ~/.claude-backups/ (local)              │  │
│  │  ├─ Copy 2: /Volumes/TimeMachine (external)         │  │
│  │  └─ Copy 3: rclone → Cloud (offsite)                │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Sync Layer (with flock + validation)                │  │
│  │  ├─ pre_sync_backup() → backup before sync          │  │
│  │  ├─ sync_claude_config_in() → rsync to staging      │  │
│  │  ├─ verify_sync_integrity() → checksum validation   │  │
│  │  └─ fix_mcp_paths() → rewrite host→container paths  │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Staging Area                                         │  │
│  │  ~/.docker-ai-config/global_state/claude_config/     │  │
│  │  ├─ .claude.json (from Keychain + file)             │  │
│  │  ├─ settings.json                                     │  │
│  │  ├─ projects/ (with normalized paths)               │  │
│  │  └─ commands/, agents/, todos/                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓ volume mount                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Ephemeral Docker Container (--rm)                   │  │
│  │                                                       │  │
│  │  ┌────────────────────────────────────────────────┐ │  │
│  │  │  /root/.claude-config/ ← mounted :consistent  │ │  │
│  │  │  ├─ .claude.json (ready to use)               │ │  │
│  │  │  ├─ settings.json                              │ │  │
│  │  │  └─ projects/, commands/, agents/             │ │  │
│  │  │                                                 │ │  │
│  │  │  Environment:                                   │ │  │
│  │  │  ├─ CLAUDE_CONFIG_DIR=/root/.claude-config    │ │  │
│  │  │  ├─ XDG_CONFIG_HOME=/root/.claude-config      │ │  │
│  │  │  └─ ANTHROPIC_* (if using Z.AI)               │ │  │
│  │  │                                                 │ │  │
│  │  │  Resource Limits:                              │ │  │
│  │  │  ├─ --memory=2g                                │ │  │
│  │  │  ├─ --cpus=2.0                                 │ │  │
│  │  │  └─ --pids-limit=100                           │ │  │
│  │  │                                                 │ │  │
│  │  │  Health Check:                                 │ │  │
│  │  │  └─ claude --version every 5s                  │ │  │
│  │  └────────────────────────────────────────────────┘ │  │
│  │                                                       │  │
│  │  claude-code-tools CLI (interactive TUI)             │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↑ sync-out on exit                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Observability Layer                                 │  │
│  │  ├─ ~/.claude-docker-events.jsonl (structured logs) │  │
│  │  ├─ ~/.claude-docker-metrics.jsonl (metrics)        │  │
│  │  └─ ~/.claude-docker-traces/ (distributed traces)   │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  GitOps Layer (Optional but Recommended)             │  │
│  │  ├─ .claude/settings.json → Git (team shared)       │  │
│  │  ├─ .claude/.claude.json.enc → Git (SOPS encrypted) │  │
│  │  └─ reconciliation_loop() → auto-sync from Git      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Ключевые Принципы

1. **Defense in Depth** - Многоуровневая защита данных
2. **Fail-Safe Defaults** - При ошибке rollback, не потеря данных
3. **Zero Data Loss** - 3-2-1 backup + sync verification
4. **Observability First** - Каждая операция логируется
5. **GitOps Compliant** - Config as Code, версионирование
6. **Production Ready** - SLO/SLA, monitoring, alerting

---

## Архитектурные Компоненты

### 1. Config Sources Layer
**Назначение**: Централизованное хранение конфигурации на хосте

**Компоненты**:
- macOS Keychain (OAuth токены) - автоматическая extraction
- `~/.claude.json` - OAuth, MCP servers, UI preferences
- `~/.claude/settings.json` - User settings
- `~/.claude/projects/` - Session history

### 2. Backup Layer
**Назначение**: Data loss protection (3-2-1 strategy)

**Компоненты**:
- Copy 1: Local incremental backups (`~/.claude-backups/`)
- Copy 2: External drive (`/Volumes/TimeMachine/claude-backups/`)
- Copy 3: Cloud backup (rclone → remote storage)

**Retention**: 30 дней

### 3. Sync Layer
**Назначение**: Bidirectional sync с data protection

**Компоненты**:
- `pre_sync_backup()` - Backup перед каждым sync
- `sync_claude_config_in()` - Host → Staging
- `verify_sync_integrity()` - Checksum validation
- `fix_mcp_paths()` - Path rewriting для контейнера
- `sync_claude_config_out()` - Container → Host

**Locking**: flock для предотвращения race conditions

### 4. Staging Area
**Назначение**: Промежуточное хранилище для контейнера

**Местоположение**: `~/.docker-ai-config/global_state/claude_config/`

**Содержимое**:
- Validated config
- Rewritten MCP paths
- Normalized session history

### 5. Container Layer
**Назначение**: Isolated execution environment

**Характеристики**:
- **Ephemeral** (`--rm`) - автоочистка
- **Resource limited** - memory/CPU/PID limits
- **Health checked** - monitoring готовности
- **Volume mounted** - staging area с :consistent flag

### 6. Observability Layer
**Назначение**: Production monitoring

**Три столпа**:
- **Logs**: `~/.claude-docker-events.jsonl` (structured JSON)
- **Metrics**: `~/.claude-docker-metrics.jsonl` (Prometheus-compatible)
- **Traces**: `~/.claude-docker-traces/` (distributed tracing)

### 7. GitOps Layer (Optional)
**Назначение**: Config-as-Code compliance

**Функции**:
- Config версионирование в Git
- SOPS encryption для секретов
- Reconciliation loop для auto-sync
- Drift detection

---

## Data Flow

### Startup Flow
```
1. extract_keychain_credentials()     # macOS Keychain → ~/.claude.json
2. pre_sync_backup()                  # Backup перед sync
3. sync_claude_config_in()            # Host → Staging
   ├─ rsync ~/.claude/ → staging/
   ├─ cp ~/.claude.json → staging/
   ├─ fix_mcp_paths()                 # Path rewriting
   └─ normalize_session_history()     # Path normalization
4. verify_sync_integrity()            # Checksum validation
5. docker run --rm                    # Start ephemeral container
   ├─ volume mount staging → /root/.claude-config
   ├─ resource limits enforced
   └─ health check running
6. log_event("claude_start")          # Observability
```

### Shutdown Flow
```
1. Container exits (user Ctrl+C or normal exit)
2. sync_claude_config_out()           # Container → Host
   ├─ acquire_sync_lock()
   ├─ pre_sync_backup()
   ├─ rsync staging/ → ~/.claude/
   ├─ cp staging/.claude.json → ~/
   └─ verify_sync_integrity()
3. Docker removes container (--rm)    # Auto-cleanup
4. log_event("claude_end")            # Observability
5. collect_metrics()                  # Performance tracking
```

### Disaster Recovery Flow
```
1. Fatal error detected
2. disaster_recovery()
   ├─ find_good_backup()              # Search for valid backup
   ├─ restore_from_backup()           # Restore config
   ├─ verify_recovery()               # Validate restoration
   └─ log incident for analysis
3. System operational again
```

---

## Security Model

### Secrets Management
- **OAuth tokens**: macOS Keychain (encrypted at OS level)
- **Config files**: Git-encrypted via SOPS/age
- **Container isolation**: Docker security namespaces
- **File permissions**: 600 на чувствительные файлы

### Access Control
- User-level isolation (multi-user safe)
- Container resource limits (DoS prevention)
- Volume mounts read-write isolation

---

## Performance Considerations

### Optimizations
- **rsync** с `--checksum` - только измененные файлы
- **:consistent** mount flag - optimized для macOS
- **Resource limits** - prevent resource exhaustion
- **Incremental backups** - fast backup с hard links

### Bottlenecks
- Sync IN/OUT: 500ms target
- Container startup: 2s target
- MCP path rewriting: minimal overhead

---

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)
