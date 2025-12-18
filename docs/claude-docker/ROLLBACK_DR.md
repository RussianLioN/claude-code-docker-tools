# Rollback & Disaster Recovery

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)

---

## 🔄 Automated Rollback

### Rollback Triggers

**Automated rollback происходит при**:

1. **E2E tests failed** после deployment
2. **Error rate > 10%** в течение 5 минут
3. **Critical alert** triggered (data corruption)
4. **Smoke tests failed** после config change
5. **Manual invocation** пользователем

---

### Rollback Process

```
┌─────────────────────────────────────────┐
│ 1. Detect failure condition             │
│    ├─ Error rate threshold              │
│    ├─ Test failure                      │
│    └─ Manual trigger                    │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 2. Stop new operations                  │
│    ├─ Stop accepting new sessions       │
│    └─ Wait for current sessions to end  │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 3. Restore config from last good backup │
│    ├─ find_good_backup()                │
│    ├─ restore_from_backup()             │
│    └─ verify_recovery()                 │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 4. Rollback Git commit (GitOps)         │
│    ├─ git revert HEAD                   │
│    ├─ git push origin main              │
│    └─ reconcile_config()                │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 5. Verification                         │
│    ├─ validate_claude_config()          │
│    ├─ smoke_test()                      │
│    └─ run_basic_e2e_tests()             │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 6. Log incident & alert                 │
│    ├─ Log rollback event                │
│    ├─ Send alert to team                │
│    └─ Create incident report            │
└─────────────────────────────────────────┘
```

---

### Manual Rollback

```bash
# Rollback to previous version (automated)
disaster_recovery

# Rollback to specific backup
restore_from_backup "$HOME/.claude-backups/20250118-143000"

# Rollback to Git tag
git checkout claude-v2.0
source ai-assistant.zsh

# Rollback Git commit (GitOps)
git revert HEAD
git push origin main
# Reconciliation loop will auto-apply
```

---

## 🆘 Disaster Recovery

### DR Scenarios

| Scenario | Recovery Method | RTO | RPO |
|----------|----------------|-----|-----|
| **Config corruption** | Restore from last backup | < 2 min | < 1 hour |
| **Complete data loss** | Restore from cloud backup | < 10 min | < 1 hour |
| **Git repo damaged** | Clone from remote + restore config | < 5 min | < 1 hour |
| **System crash** | Auto-recovery on next start | < 1 min | 0 (no data loss) |
| **Accidental deletion** | Restore from pre-sync backup | < 1 min | 0 (immediate) |

**Definitions**:
- **RTO** (Recovery Time Objective): Максимальное время восстановления
- **RPO** (Recovery Point Objective): Максимальная допустимая потеря данных

---

### DR Implementation

**Файл**: `lib/disaster_recovery.sh`

```bash
#!/bin/bash
# lib/disaster_recovery.sh - Automated disaster recovery

set -euo pipefail

source lib/backup.sh
source lib/validation.sh
source lib/error_handling.sh

# Find last good backup
find_good_backup() {
  local backup_dir

  # Try backups from newest to oldest
  for backup_dir in $(ls -dt "$BACKUP_ROOT"/*/ 2>/dev/null); do
    if verify_backup "$backup_dir" 2>/dev/null; then
      echo "$backup_dir"
      return 0
    fi
  done

  # No valid backup found
  log_error "No valid backup found" "disaster_recovery"
  return 1
}

# Restore from backup
restore_from_backup() {
  local backup_dir="$1"

  echo "🚨 Restoring from backup: $backup_dir"

  if [[ ! -d "$backup_dir" ]]; then
    log_error "Backup directory not found: $backup_dir" "restore"
    return 1
  fi

  # Stop all Claude containers
  docker ps -q -f name=claude-session | xargs -r docker kill 2>/dev/null || true

  # Backup current state (in case restore fails)
  local emergency_backup="/tmp/claude-emergency-$(date +%s)"
  mkdir -p "$emergency_backup"
  rsync -a "$HOME/.claude/" "$emergency_backup/claude/" 2>/dev/null || true
  cp "$HOME/.claude.json" "$emergency_backup/claude.json" 2>/dev/null || true

  # Restore config
  rsync -a --delete "$backup_dir/claude/" "$HOME/.claude/" || {
    log_error "Failed to restore ~/.claude/" "restore"
    return 1
  }

  # Restore ~/.claude.json
  if [[ -f "$backup_dir/claude.json" ]]; then
    cp "$backup_dir/claude.json" "$HOME/.claude.json" || {
      log_error "Failed to restore ~/.claude.json" "restore"
      return 1
    }
    chmod 600 "$HOME/.claude.json"
  fi

  echo "✅ Config restored from backup"
}

# Verify recovery
verify_recovery() {
  echo "🔍 Verifying recovery..."

  # Validate config
  validate_claude_config || {
    log_error "Config validation failed after recovery" "verify_recovery"
    return 1
  }

  # Smoke test
  claude --version >/dev/null 2>&1 || {
    log_error "Smoke test failed after recovery" "verify_recovery"
    return 1
  }

  echo "✅ Recovery verified"
  return 0
}

# Main disaster recovery function
disaster_recovery() {
  echo "🚨 DISASTER RECOVERY INITIATED"
  log_event "critical" "disaster_recovery_start" "{}"

  # Find last good backup
  local backup_dir=$(find_good_backup)
  if [[ -z "$backup_dir" ]]; then
    echo "❌ No valid backup found - manual intervention required"
    log_event "critical" "disaster_recovery_failed" "{\"reason\":\"no_backup\"}"
    return 1
  fi

  echo "📦 Found valid backup: $backup_dir"

  # Restore from backup
  restore_from_backup "$backup_dir" || {
    echo "❌ Restore failed - manual intervention required"
    log_event "critical" "disaster_recovery_failed" "{\"reason\":\"restore_failed\"}"
    return 1
  }

  # Verify recovery
  verify_recovery || {
    echo "❌ Verification failed - manual intervention required"
    log_event "critical" "disaster_recovery_failed" "{\"reason\":\"verification_failed\"}"
    return 1
  }

  echo ""
  echo "✅ DISASTER RECOVERY COMPLETE"
  log_event "info" "disaster_recovery_success" "{\"backup\":\"$backup_dir\"}"

  # Send alert
  send_alert "high" "Disaster recovery completed successfully" "Restored from: $backup_dir"

  return 0
}

# Export functions
export -f disaster_recovery
export -f find_good_backup
export -f restore_from_backup
export -f verify_recovery
```

---

### DR Runbook

**Step-by-Step Recovery Procedure**:

```bash
# STEP 1: Assess damage
echo "=== Damage Assessment ==="
ls -lh ~/.claude/
cat ~/.claude.json 2>/dev/null || echo "~/.claude.json missing"
docker ps -a -f name=claude-session

# STEP 2: Stop all operations
docker ps -q -f name=claude-session | xargs -r docker kill

# STEP 3: Run automated DR
disaster_recovery

# STEP 4: Verify system operational
validate_claude_config
claude --version
claude --help

# STEP 5: Check logs
tail -20 ~/.claude-docker-events.jsonl
tail -20 ~/.claude-docker-errors.log

# STEP 6: Resume normal operations
echo "✅ System recovered and operational"
```

---

### Emergency Recovery (Nuclear Option)

**When automated DR fails**:

```bash
# STEP 1: Backup current state (even if corrupted)
tar -czf ~/claude-emergency-backup-$(date +%s).tar.gz \
  ~/.claude ~/.claude.json ~/.docker-ai-config 2>/dev/null || true

# STEP 2: Clean everything
rm -rf ~/.claude ~/.claude.json ~/.docker-ai-config
rm -rf ~/.claude-docker-*
docker ps -q -f name=claude-session | xargs -r docker kill
docker system prune -af

# STEP 3: Restore from cloud backup (COPY 3)
if command -v rclone &>/dev/null; then
  echo "Downloading from cloud backup..."
  rclone copy "$RCLONE_REMOTE/latest.tar.gz" ~/
  tar -xzf ~/latest.tar.gz -C ~/
fi

# STEP 4: Restore from external drive (COPY 2)
if [[ -d "$EXTERNAL_BACKUP_PATH" ]]; then
  echo "Restoring from external drive..."
  latest_backup=$(ls -t "$EXTERNAL_BACKUP_PATH"/*.tar.gz | head -1)
  tar -xzf "$latest_backup" -C ~/
fi

# STEP 5: Re-run setup
./install.sh

# STEP 6: Extract credentials
extract_keychain_credentials

# STEP 7: Verify
validate_claude_config
claude --version

echo "✅ Emergency recovery complete"
```

---

## Backup Verification

**Regular backup testing** (should be automated):

```bash
#!/bin/bash
# Test backup integrity weekly

echo "🧪 Testing backup integrity..."

# Find latest backup
latest_backup=$(readlink -f "$BACKUP_ROOT/latest")

# Verify backup
verify_backup "$latest_backup" || {
  echo "❌ Latest backup corrupted!"
  send_alert "critical" "Backup integrity check failed" "Latest backup: $latest_backup"
  exit 1
}

# Test restore (dry-run)
temp_restore="/tmp/claude-restore-test-$$"
mkdir -p "$temp_restore"

rsync -a "$latest_backup/claude/" "$temp_restore/" || {
  echo "❌ Restore test failed!"
  exit 1
}

# Validate restored config
if [[ -f "$temp_restore/settings.json" ]]; then
  jq empty "$temp_restore/settings.json" || {
    echo "❌ Restored config invalid!"
    exit 1
  }
fi

# Cleanup
rm -rf "$temp_restore"

echo "✅ Backup integrity verified"
```

---

## Recovery Metrics

**Track recovery operations**:

```bash
# Log recovery event
log_event "info" "disaster_recovery" "{
  \"backup_used\": \"$backup_dir\",
  \"recovery_time_seconds\": $duration,
  \"data_loss_hours\": $data_loss_hours,
  \"trigger\": \"$trigger\"
}"

# Calculate metrics
jq -s 'map(select(.event == "disaster_recovery")) |
       {
         total_recoveries: length,
         avg_recovery_time: (map(.recovery_time_seconds) | add / length),
         max_data_loss: (map(.data_loss_hours) | max)
       }' \
  ~/.claude-docker-events.jsonl
```

---

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)
