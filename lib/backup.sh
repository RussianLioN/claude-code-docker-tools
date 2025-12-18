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
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
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
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local backup_dir="$BACKUP_ROOT/pre-sync-$timestamp"

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
