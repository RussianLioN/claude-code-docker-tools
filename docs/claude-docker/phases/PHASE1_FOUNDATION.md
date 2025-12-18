# Phase 1: Foundation & Safety (Дни 1-2)

**📍 Navigation**: [← Back to Plan v3.0](../../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)

---

## 🎯 Цель Фазы

Создать **безопасную основу** для реализации:
- Система backup/restore (3-2-1 strategy)
- Validation framework
- Error handling infrastructure

**Критично**: Эта фаза защищает от потери данных на всех последующих этапах.

---

## PRE-IMPLEMENTATION CHECKLIST

### ⚠️ КРИТИЧНО: Выполнить ДО начала

```bash
# 1. Создать pre-implementation backup
git tag claude-v2-before-v3-migration
git push origin claude-v2-before-v3-migration

# 2. Backup текущей конфигурации
mkdir -p ~/claude-v2-backup
cp -r ~/.claude ~/claude-v2-backup/
cp ~/.claude.json ~/claude-v2-backup/ 2>/dev/null || true
tar -czf ~/claude-v2-backup.tar.gz ~/claude-v2-backup/

# 3. Backup текущего ai-assistant.zsh
cp ai-assistant.zsh ai-assistant.zsh.v2.backup

# 4. Проверить зависимости
check_dependencies() {
  local missing=()

  command -v docker &>/dev/null || missing+=("docker")
  command -v rsync &>/dev/null || missing+=("rsync")
  command -v flock &>/dev/null || missing+=("flock")
  command -v jq &>/dev/null || missing+=("jq")

  if (( ${#missing[@]} > 0 )); then
    echo "❌ Отсутствуют зависимости: ${missing[*]}"
    echo "Установите: brew install ${missing[*]}"
    return 1
  fi

  echo "✅ Все зависимости установлены"
}

check_dependencies || exit 1

# 5. Проверить место на диске
available_gb=$(df -h ~ | awk 'NR==2 {print $4}' | sed 's/Gi//')
if (( $(echo "$available_gb < 5" | bc -l) )); then
  echo "❌ Недостаточно места на диске (< 5GB)"
  exit 1
fi

# 6. Создать структуру директорий
mkdir -p ~/.claude-backups
mkdir -p ~/.docker-ai-config/global_state/claude_config
mkdir -p ~/.claude-docker-logs
mkdir -p lib
mkdir -p tests

# 7. Убедиться что Docker запущен
docker info >/dev/null 2>&1 || {
  echo "❌ Docker не запущен. Запустите Docker Desktop"
  exit 1
}

echo "✅ Pre-implementation checklist complete"
```

---

## 1.1 Backup System (3-2-1 Strategy)

**Файл**: `lib/backup.sh`

### Принцип 3-2-1

- **3** copies данных (original + 2 backups)
- **2** different media (local disk + external/cloud)
- **1** offsite copy (cloud backup)

### Реализация

```bash
#!/bin/bash
# lib/backup.sh - 3-2-1 Backup Strategy для Claude Config

set -euo pipefail

# Configuration
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/.claude-backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
EXTERNAL_BACKUP_PATH="${EXTERNAL_BACKUP_PATH:-/Volumes/TimeMachine/claude-backups}"
RCLONE_REMOTE="${RCLONE_REMOTE:-remote:claude-backups}"

# Logging
log_backup() {
  local level="$1"
  local message="$2"

  cat >> "$HOME/.claude-docker-backup.log" <<LOG
$(date -Iseconds) [$level] $message
LOG
}

# Main backup function
backup_claude_data() {
  local timestamp=$(date +%Y%m%d-%H%M%S)
  local backup_dir="$BACKUP_ROOT/$timestamp"

  log_backup "INFO" "Starting backup to $backup_dir"

  # Create backup directory
  mkdir -p "$backup_dir"

  # COPY 1: Local incremental backup (fast, cheap)
  if [[ -d "$HOME/.claude" ]]; then
    rsync -a --link-dest="$BACKUP_ROOT/latest" \
      "$HOME/.claude/" "$backup_dir/claude/" 2>&1 | tee -a "$HOME/.claude-docker-backup.log" || {
        log_backup "ERROR" "Failed to backup ~/.claude"
        return 1
      }
  fi

  # Backup ~/.claude.json from root
  if [[ -f "$HOME/.claude.json" ]]; then
    cp "$HOME/.claude.json" "$backup_dir/claude.json" || {
      log_backup "ERROR" "Failed to backup ~/.claude.json"
      return 1
    }
  fi

  # Create symlink to latest
  ln -snf "$backup_dir" "$BACKUP_ROOT/latest"

  # COPY 2: Compressed archive to external drive
  log_backup "INFO" "Creating compressed archive"
  tar -czf "$backup_dir.tar.gz" -C "$BACKUP_ROOT" "$timestamp" 2>&1 | tee -a "$HOME/.claude-docker-backup.log" || {
    log_backup "WARN" "Failed to create tar.gz, continuing..."
  }

  # Copy to external drive (if available)
  if [[ -d "$(dirname "$EXTERNAL_BACKUP_PATH")" ]]; then
    mkdir -p "$EXTERNAL_BACKUP_PATH"
    cp "$backup_dir.tar.gz" "$EXTERNAL_BACKUP_PATH/" && \
      log_backup "INFO" "Copied to external drive: $EXTERNAL_BACKUP_PATH"
  else
    log_backup "WARN" "External backup path not available: $EXTERNAL_BACKUP_PATH"
  fi

  # COPY 3: Cloud backup (if rclone configured)
  if command -v rclone &>/dev/null && rclone listremotes | grep -q "^${RCLONE_REMOTE%%:*}:"; then
    log_backup "INFO" "Uploading to cloud: $RCLONE_REMOTE"
    rclone copy "$backup_dir.tar.gz" "$RCLONE_REMOTE/" \
      --progress 2>&1 | tee -a "$HOME/.claude-docker-backup.log" && \
      log_backup "INFO" "Cloud backup successful"
  else
    log_backup "WARN" "rclone not configured, skipping cloud backup"
  fi

  # Cleanup old backups (retention policy)
  log_backup "INFO" "Applying retention policy (${BACKUP_RETENTION_DAYS} days)"
  find "$BACKUP_ROOT" -maxdepth 1 -type d -name "20*" -mtime "+$BACKUP_RETENTION_DAYS" -exec rm -rf {} \; 2>/dev/null || true
  find "$BACKUP_ROOT" -maxdepth 1 -type f -name "*.tar.gz" -mtime "+$BACKUP_RETENTION_DAYS" -exec rm -f {} \; 2>/dev/null || true

  log_backup "INFO" "Backup complete: $backup_dir"
  echo "$backup_dir"
}

# Pre-sync backup (lightweight, before every sync)
pre_sync_backup() {
  local backup_dir="$BACKUP_ROOT/pre-sync-$(date +%Y%m%d-%H%M%S)"

  mkdir -p "$backup_dir"

  # Quick snapshot (no compression, no external)
  rsync -a "$HOME/.claude/" "$backup_dir/claude/" 2>/dev/null || true
  cp "$HOME/.claude.json" "$backup_dir/claude.json" 2>/dev/null || true

  # Write backup location for recovery
  echo "$backup_dir" > /tmp/claude-last-backup

  log_backup "INFO" "Pre-sync backup: $backup_dir"
}

# Verify backup integrity
verify_backup() {
  local backup_dir="$1"

  if [[ ! -d "$backup_dir" ]]; then
    log_backup "ERROR" "Backup directory not found: $backup_dir"
    return 1
  fi

  # Check critical files exist
  local critical_files=("settings.json")

  for file in "${critical_files[@]}"; do
    if [[ -f "$HOME/.claude/$file" ]] && [[ ! -f "$backup_dir/claude/$file" ]]; then
      log_backup "ERROR" "Critical file missing in backup: $file"
      return 1
    fi
  done

  log_backup "INFO" "Backup verification successful: $backup_dir"
  return 0
}

# Export functions
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Called directly
  backup_claude_data
else
  # Sourced
  export -f backup_claude_data
  export -f pre_sync_backup
  export -f verify_backup
fi
```

### Optional: Automated Backup Schedule

**macOS (launchd)**:

```bash
# ~/Library/LaunchAgents/com.claude.backup.plist
cat > ~/Library/LaunchAgents/com.claude.backup.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.backup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>source ~/.zshrc && backup_claude_data</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
PLIST

# Load
launchctl load ~/Library/LaunchAgents/com.claude.backup.plist
```

---

## 1.2 Validation Framework

**Файл**: `lib/validation.sh`

### Реализация

```bash
#!/bin/bash
# lib/validation.sh - Configuration validation

set -euo pipefail

# Validate Claude configuration structure
validate_claude_config() {
  local config_dir="${1:-$HOME/.claude}"
  local errors=()

  # Check directory exists
  if [[ ! -d "$config_dir" ]]; then
    errors+=("Config directory not found: $config_dir")
  fi

  # Validate settings.json (if exists)
  if [[ -f "$config_dir/settings.json" ]]; then
    if ! jq empty "$config_dir/settings.json" 2>/dev/null; then
      errors+=("Invalid JSON in settings.json")
    fi
  fi

  # Validate ~/.claude.json (OAuth)
  if [[ -f "$HOME/.claude.json" ]]; then
    if ! jq empty "$HOME/.claude.json" 2>/dev/null; then
      errors+=("Invalid JSON in ~/.claude.json")
    fi

    # Check for OAuth tokens
    if ! jq -e '.claudeAiOauth.accessToken' "$HOME/.claude.json" >/dev/null 2>&1; then
      errors+=("Missing OAuth access token in ~/.claude.json")
    fi
  else
    errors+=("~/.claude.json not found - authentication will fail")
  fi

  # Report errors
  if (( ${#errors[@]} > 0 )); then
    echo "❌ Configuration validation failed:" >&2
    printf '  - %s\n' "${errors[@]}" >&2
    return 1
  fi

  echo "✅ Configuration validation passed"
  return 0
}

# Validate Docker environment
validate_docker_environment() {
  local errors=()

  # Docker daemon running
  if ! docker info >/dev/null 2>&1; then
    errors+=("Docker daemon not running")
  fi

  # Image exists
  if ! docker image inspect claude-ai:latest >/dev/null 2>&1; then
    errors+=("Docker image not found: claude-ai:latest")
  fi

  # Resource availability
  local available_memory=$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)
  if (( available_memory < 2147483648 )); then  # 2GB
    errors+=("Insufficient Docker memory (< 2GB)")
  fi

  if (( ${#errors[@]} > 0 )); then
    echo "❌ Docker environment validation failed:" >&2
    printf '  - %s\n' "${errors[@]}" >&2
    return 1
  fi

  echo "✅ Docker environment validation passed"
  return 0
}

# Validate sync integrity (after sync)
verify_sync_integrity() {
  local source="$1"
  local target="$2"

  local errors=()

  # Check critical files synced
  local critical_files=(
    ".claude.json"
    "settings.json"
  )

  for file in "${critical_files[@]}"; do
    local source_file="$source/$file"
    local target_file="$target/$file"

    # Skip if source doesn't exist
    [[ -f "$source_file" ]] || continue

    # Check target exists
    if [[ ! -f "$target_file" ]]; then
      errors+=("File not synced: $file")
      continue
    fi

    # Check sizes match
    local source_size=$(stat -f%z "$source_file" 2>/dev/null || echo 0)
    local target_size=$(stat -f%z "$target_file" 2>/dev/null || echo 0)

    if (( source_size != target_size )); then
      errors+=("Size mismatch for $file: $source_size vs $target_size bytes")
    fi
  done

  if (( ${#errors[@]} > 0 )); then
    echo "❌ Sync integrity verification failed:" >&2
    printf '  - %s\n' "${errors[@]}" >&2
    return 1
  fi

  echo "✅ Sync integrity verified"
  return 0
}

# Export functions
export -f validate_claude_config
export -f validate_docker_environment
export -f verify_sync_integrity
```

---

## 1.3 Error Handling Infrastructure

**Файл**: `lib/error_handling.sh`

### Реализация

```bash
#!/bin/bash
# lib/error_handling.sh - Centralized error handling

set -euo pipefail

# Error logging
ERROR_LOG="${ERROR_LOG:-$HOME/.claude-docker-errors.log}"

log_error() {
  local error_msg="$1"
  local context="${2:-unknown}"

  cat >> "$ERROR_LOG" <<ERROR
{
  "timestamp": "$(date -Iseconds)",
  "level": "ERROR",
  "message": "$error_msg",
  "context": "$context",
  "user": "$USER",
  "host": "$(hostname)",
  "pid": $$
}
ERROR

  echo "❌ ERROR: $error_msg" >&2
}

# Fatal error handler (triggers recovery)
fatal_error() {
  local error_msg="$1"
  local should_recover="${2:-true}"

  log_error "$error_msg" "FATAL"

  if [[ "$should_recover" == "true" ]]; then
    echo "🚨 Fatal error occurred, initiating recovery..." >&2
    # disaster_recovery будет доступна в Phase 3
    # disaster_recovery
  fi

  exit 1
}

# Trap handler for unexpected errors
error_trap_handler() {
  local line_number="$1"
  local command="$2"

  log_error "Unexpected error at line $line_number: $command" "TRAP"

  # Cleanup
  cleanup_on_error
}

# Cleanup function
cleanup_on_error() {
  # Kill any running Claude containers
  docker ps -q -f name=claude-session | xargs -r docker kill 2>/dev/null || true

  # Release locks
  rm -f /tmp/claude-config-sync.lock 2>/dev/null || true
}

# Set trap
trap 'error_trap_handler $LINENO "$BASH_COMMAND"' ERR

# Export functions
export -f log_error
export -f fatal_error
export -f cleanup_on_error
```

---

## 1.4 Phase 1 Testing

**Файл**: `tests/phase1-foundation-tests.sh`

```bash
#!/bin/bash
# tests/phase1-foundation-tests.sh

set -euo pipefail

# Ensure we're in the right directory
cd "$(dirname "$0")/.."

source lib/backup.sh
source lib/validation.sh
source lib/error_handling.sh

echo "🧪 Phase 1: Foundation & Safety Tests"
echo ""

# Test 1: Backup creation
echo "Test 1: Backup creation..."
backup_dir=$(backup_claude_data)
[[ -d "$backup_dir" ]] || {
  echo "❌ FAIL: Backup directory not created"
  exit 1
}
echo "✅ PASS: Backup created at $backup_dir"

# Test 2: Backup verification
echo "Test 2: Backup verification..."
verify_backup "$backup_dir" || {
  echo "❌ FAIL: Backup verification failed"
  exit 1
}
echo "✅ PASS: Backup verified"

# Test 3: Config validation
echo "Test 3: Config validation..."
validate_claude_config || {
  echo "❌ FAIL: Config validation failed"
  exit 1
}
echo "✅ PASS: Config valid"

# Test 4: Docker environment
echo "Test 4: Docker environment..."
validate_docker_environment || {
  echo "❌ FAIL: Docker environment validation failed"
  exit 1
}
echo "✅ PASS: Docker environment OK"

# Test 5: Error logging
echo "Test 5: Error logging..."
log_error "Test error message" "test_context"
[[ -f "$ERROR_LOG" ]] || {
  echo "❌ FAIL: Error log not created"
  exit 1
}
echo "✅ PASS: Error logging works"

# Test 6: Pre-sync backup
echo "Test 6: Pre-sync backup..."
pre_sync_backup
[[ -f /tmp/claude-last-backup ]] || {
  echo "❌ FAIL: Pre-sync backup marker not created"
  exit 1
}
echo "✅ PASS: Pre-sync backup OK"

echo ""
echo "✅ All Phase 1 tests passed (6/6)!"
echo "Ready to proceed to Phase 2"
```

---

## 📋 Phase 1 Checklist

**Перед началом**:
- [ ] Выполнить Pre-Implementation Checklist
- [ ] Backup текущей системы
- [ ] Проверить зависимости

**Реализация**:
- [ ] Создать `lib/backup.sh`
- [ ] Создать `lib/validation.sh`
- [ ] Создать `lib/error_handling.sh`
- [ ] Создать `tests/phase1-foundation-tests.sh`

**Тестирование**:
- [ ] Запустить `./tests/phase1-foundation-tests.sh`
- [ ] Убедиться что все 6 тестов проходят
- [ ] Проверить backup в ~/.claude-backups/

**Завершение**:
- [ ] Коммит: `git add lib/ tests/`
- [ ] Коммит: `git commit -m "feat(phase1): foundation & safety layer"`
- [ ] Готовность к Phase 2: ✅

---

**📊 Success Metrics**:
- Backup creation: < 5 seconds
- Backup verification: < 1 second
- Validation: < 1 second
- All tests passing: 6/6

**🔗 Next**: [Phase 2: Core Implementation](./PHASE2_CORE.md)

**📍 Navigation**: [← Back to Plan v3.0](../../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)
