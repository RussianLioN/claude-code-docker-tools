# PHASE 2: CORE IMPLEMENTATION (Дни 3-7)

**📍 Navigation**: [← Back to Plan v3.0](../../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)

---

## 🎯 Цель Фазы

Реализовать **core functionality** с интеграцией всех критических улучшений:

- macOS Keychain extraction
- Bidirectional sync с защитой данных
- MCP path rewriting
- Resource limits
- Ephemeral containers (--rm)

## 2.1 Keychain Credentials Extraction (macOS)

**Файл**: `lib/keychain.sh`

```bash
#!/bin/bash
# lib/keychain.sh - macOS Keychain integration

set -euo pipefail

# Extract Claude credentials from macOS Keychain
extract_keychain_credentials() {
  # Only на macOS
  if [[ "$OSTYPE" != "darwin"* ]]; then
    return 0
  fi

  echo "🔑 Extracting credentials from macOS Keychain..."

  # Try to get access token
  local access_token=$(security find-generic-password \
    -s "claude.ai" \
    -a "$USER" \
    -w 2>/dev/null || echo "")

  if [[ -z "$access_token" ]]; then
    echo "⚠️ No Keychain credentials found, using file-based auth" >&2
    return 0
  fi

  # Try to get refresh token (may be stored separately)
  local refresh_token=$(security find-generic-password \
    -s "claude.ai.refresh" \
    -a "$USER" \
    -w 2>/dev/null || echo "")

  # Create ~/.claude.json с извлечёнными credentials
  local temp_config="/tmp/claude-keychain-$$.json"

  cat > "$temp_config" <<JSON
{
  "claudeAiOauth": {
    "accessToken": "$access_token",
    "refreshToken": "$refresh_token",
    "expiresAt": $(date -v+7d +%s)000,
    "scopes": ["user:inference", "user:profile", "user:sessions:claude_code"],
    "subscriptionType": "pro"
  }
}
JSON

  # Merge с существующим ~/.claude.json (если есть)
  if [[ -f "$HOME/.claude.json" ]]; then
    # Merge JSON (Keychain credentials имеют приоритет)
    jq -s '.[0] * .[1]' "$HOME/.claude.json" "$temp_config" > "$HOME/.claude.json.tmp"
    mv "$HOME/.claude.json.tmp" "$HOME/.claude.json"
  else
    mv "$temp_config" "$HOME/.claude.json"
  fi

  # Set proper permissions
  chmod 600 "$HOME/.claude.json"

  # Cleanup
  rm -f "$temp_config"

  echo "✅ Keychain credentials extracted"
}

# Store credentials back to Keychain (после успешной auth)
store_to_keychain() {
  local access_token="$1"
  local refresh_token="${2:-}"

  [[ "$OSTYPE" != "darwin"* ]] && return 0

  # Store access token
  security add-generic-password \
    -U \
    -s "claude.ai" \
    -a "$USER" \
    -w "$access_token" \
    2>/dev/null || {
      echo "⚠️ Failed to store credentials in Keychain" >&2
    }

  # Store refresh token (if provided)
  if [[ -n "$refresh_token" ]]; then
    security add-generic-password \
      -U \
      -s "claude.ai.refresh" \
      -a "$USER" \
      -w "$refresh_token" \
      2>/dev/null || true
  fi
}

export -f extract_keychain_credentials
export -f store_to_keychain
```

## 2.2 Enhanced Sync Functions

**Файл**: `lib/sync.sh`

```bash
#!/bin/bash
# lib/sync.sh - Bidirectional sync with data protection

set -euo pipefail

source lib/backup.sh
source lib/validation.sh
source lib/error_handling.sh

# Configuration
CLAUDE_STATE_DIR="${CLAUDE_STATE_DIR:-$HOME/.docker-ai-config/global_state/claude_config}"
SYNC_LOCK_FILE="${SYNC_LOCK_FILE:-/tmp/claude-config-sync.lock}"
SYNC_TIMEOUT="${SYNC_TIMEOUT:-30}"

# Sync excludes
SYNC_EXCLUDES=(
  'debug/'
  'shell-snapshots/'
  'statsig/'
  '.DS_Store'
  '*.log'
  '*.tmp'
)

# Acquire lock with retry
acquire_sync_lock() {
  local max_attempts=3
  local attempt=0

  while (( attempt < max_attempts )); do
    {
      if flock -x -w "$SYNC_TIMEOUT" 200; then
        return 0
      fi
    } 200>"$SYNC_LOCK_FILE"

    attempt=$((attempt + 1))
    echo "⚠️ Lock acquisition failed (attempt $attempt/$max_attempts)" >&2
    sleep $((RANDOM % 5 + 1))  # Random backoff 1-5s
  done

  log_error "Failed to acquire sync lock after $max_attempts attempts" "sync_lock"
  return 1
}

# Release lock
release_sync_lock() {
  rm -f "$SYNC_LOCK_FILE" 2>/dev/null || true
}

# Fix MCP server paths (host → container)
fix_mcp_paths() {
  local config_file="$CLAUDE_STATE_DIR/.claude.json"

  [[ -f "$config_file" ]] || return 0

  # Check if MCP config exists
  if ! jq -e '.mcp.servers' "$config_file" >/dev/null 2>&1; then
    return 0
  fi

  echo "🔧 Rewriting MCP server paths..."

  # Rewrite paths: /Users/*/path → /workspace/path
  #                /home/*/path  → /workspace/path
  jq '.mcp.servers |= with_entries(
    .value.args |= map(
      if type == "string" then
        sub("^/Users/[^/]+/"; "/workspace/") |
        sub("^/home/[^/]+/"; "/workspace/")
      else . end
    )
  )' "$config_file" > "$config_file.tmp"

  mv "$config_file.tmp" "$config_file"

  echo "✅ MCP paths rewritten"
}

# Normalize session history paths
normalize_session_history() {
  local projects_dir="$CLAUDE_STATE_DIR/projects"

  [[ -d "$projects_dir" ]] || return 0

  # Find all project directories
  for project_dir in "$projects_dir"/*/; do
    [[ -d "$project_dir" ]] || continue

    local dir_name=$(basename "$project_dir")

    # Try to decode base64
    local decoded_path=$(echo "$dir_name" | base64 -d 2>/dev/null || echo "")

    if [[ -n "$decoded_path" && "$decoded_path" =~ ^/Users/ ]]; then
      # Create symlink для container path
      local container_path="/workspace/$(basename "$decoded_path")"
      local container_encoded=$(echo -n "$container_path" | base64)

      if [[ ! -e "$projects_dir/$container_encoded" ]]; then
        ln -s "$project_dir" "$projects_dir/$container_encoded" 2>/dev/null || true
      fi
    fi
  done
}

# Sync IN (host → staging → container)
sync_claude_config_in() {
  echo "⬇️ Syncing config IN (host → container)..."

  # Acquire lock
  acquire_sync_lock || {
    fatal_error "Cannot acquire sync lock" false
    return 1
  }

  # Ensure cleanup on exit
  trap release_sync_lock EXIT

  # PRE-SYNC BACKUP (критично!)
  pre_sync_backup || {
    log_error "Pre-sync backup failed" "sync_in"
    release_sync_lock
    return 1
  }

  mkdir -p "$CLAUDE_STATE_DIR"

  # Build exclude args
  local exclude_args=()
  for pattern in "${SYNC_EXCLUDES[@]}"; do
    exclude_args+=(--exclude "$pattern")
  done

  # 1. Sync ~/.claude/ directory
  if [[ -d "$HOME/.claude" ]]; then
    rsync -a --delete --checksum --compress \
      "${exclude_args[@]}" \
      "$HOME/.claude/" "$CLAUDE_STATE_DIR/" 2>&1 | tee -a "$HOME/.claude-docker-sync.log" || {
        log_error "Failed to sync ~/.claude/" "sync_in"
        release_sync_lock
        return 1
      }
  else
    echo "⚠️ ~/.claude directory not found, creating..." >&2
    mkdir -p "$HOME/.claude"
  fi

  # 2. CRITICAL: Sync ~/.claude.json from HOME
  if [[ -f "$HOME/.claude.json" ]]; then
    cp "$HOME/.claude.json" "$CLAUDE_STATE_DIR/.claude.json" || {
      log_error "Failed to sync ~/.claude.json" "sync_in"
      release_sync_lock
      return 1
    }
  else
    echo "⚠️ ~/.claude.json not found - authentication may fail!" >&2
  fi

  # 3. Fix MCP server paths
  fix_mcp_paths || {
    log_error "Failed to fix MCP paths" "sync_in"
    # Non-fatal, continue
  }

  # 4. Normalize session history
  normalize_session_history || {
    log_error "Failed to normalize session history" "sync_in"
    # Non-fatal, continue
  }

  # 5. Verify sync integrity
  verify_sync_integrity "$HOME/.claude" "$CLAUDE_STATE_DIR" || {
    log_error "Sync integrity verification failed" "sync_in"

    # CRITICAL: Restore from backup
    local last_backup=$(cat /tmp/claude-last-backup 2>/dev/null || echo "")
    if [[ -n "$last_backup" && -d "$last_backup" ]]; then
      echo "🚨 Restoring from pre-sync backup..." >&2
      rsync -a --delete "$last_backup/claude/" "$HOME/.claude/"
      cp "$last_backup/claude.json" "$HOME/.claude.json" 2>/dev/null || true
    fi

    release_sync_lock
    return 1
  }

  # Force filesystem flush
  sync

  release_sync_lock

  echo "✅ Config synced IN successfully"
}

# Sync OUT (container → staging → host)
sync_claude_config_out() {
  echo "⬆️ Syncing config OUT (container → host)..."

  # Skip in sandbox mode
  if [[ -n "${TRAE_SANDBOX_MODE:-}" ]]; then
    echo "ℹ️ Skipping sync-out in sandbox mode"
    return 0
  fi

  # Acquire lock
  acquire_sync_lock || {
    log_error "Cannot acquire sync lock for sync-out" "sync_out"
    return 0  # Non-fatal для sync-out
  }

  trap release_sync_lock EXIT

  # Pre-sync backup
  pre_sync_backup || {
    log_error "Pre-sync backup failed" "sync_out"
    release_sync_lock
    return 0  # Non-fatal
  }

  mkdir -p "$HOME/.claude"

  # Build exclude args
  local exclude_args=()
  for pattern in "${SYNC_EXCLUDES[@]}"; do
    exclude_args+=(--exclude "$pattern")
  done

  # 1. Sync directory back
  if [[ -d "$CLAUDE_STATE_DIR" ]]; then
    rsync -a --delete --checksum --compress \
      "${exclude_args[@]}" \
      "$CLAUDE_STATE_DIR/" "$HOME/.claude/" 2>&1 | tee -a "$HOME/.claude-docker-sync.log" || {
        log_error "Failed to sync-out ~/.claude/" "sync_out"
        release_sync_lock
        return 0  # Non-fatal
      }
  fi

  # 2. CRITICAL: Sync ~/.claude.json back
  if [[ -f "$CLAUDE_STATE_DIR/.claude.json" ]]; then
    cp "$CLAUDE_STATE_DIR/.claude.json" "$HOME/.claude.json" || {
      log_error "Failed to sync-out ~/.claude.json" "sync_out"
      release_sync_lock
      return 0  # Non-fatal
    }
  fi

  # Force filesystem flush
  sync

  release_sync_lock

  echo "✅ Config synced OUT successfully"
}

# Export functions
export -f sync_claude_config_in
export -f sync_claude_config_out
export -f fix_mcp_paths
export -f normalize_session_history
```

## 2.3 Updated Claude Function (ai-assistant.zsh)

**Изменения в `ai-assistant.zsh`**:

```bash
# После строки 175: Source новых библиотек
source "${SCRIPT_DIR}/lib/backup.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/validation.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/error_handling.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/keychain.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/sync.sh" 2>/dev/null || true

# Обновить claude() функцию (начиная со строки ~400)
claude() {
  local container_name="claude-session-${USER}-$(date +%s)-$(openssl rand -hex 4)"
  local TRACE_ID=$(uuidgen)
  local start_time=$(date +%s%3N)

  # Log start
  log_event "info" "claude_start" "{\"args\":\"$*\",\"trace_id\":\"$TRACE_ID\"}"

  # Pre-flight validations
  validate_docker_environment || {
    fatal_error "Docker environment validation failed" false
    return 1
  }

  # Extract Keychain credentials (macOS)
  extract_keychain_credentials || {
    log_error "Failed to extract Keychain credentials" "keychain"
    # Non-fatal, продолжаем с file-based auth
  }

  # Sync config IN
  sync_claude_config_in || {
    fatal_error "Config sync failed, cannot start Claude" false
    return 1
  }

  # Prepare environment variables
  local env_vars=(
    -e "CLAUDE_CONFIG_DIR=/root/.claude-config"
    -e "XDG_CONFIG_HOME=/root/.claude-config"
    -e "TRACE_ID=$TRACE_ID"
  )

  # Add Z.AI variables if configured
  if [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
    env_vars+=(
      -e "ANTHROPIC_BASE_URL=$ANTHROPIC_BASE_URL"
      -e "ANTHROPIC_AUTH_TOKEN=$ANTHROPIC_AUTH_TOKEN"
      -e "ANTHROPIC_MODEL=${ANTHROPIC_MODEL:-glm-4.6}"
    )
  fi

  # Resource limits
  local resource_limits=(
    --memory="2g"
    --memory-swap="2g"
    --cpus="2.0"
    --pids-limit=100
    --ulimit nofile=1024:1024
  )

  # Health check
  local health_check=(
    --health-cmd='claude --version || exit 1'
    --health-interval=5s
    --health-timeout=2s
    --health-retries=1
  )

  # Volume mounts (CRITICAL: use :consistent!)
  local volumes=(
    -v "${CLAUDE_STATE_DIR}":/root/.claude-config:consistent
    -v "${TARGET_DIR}":"${CONTAINER_BASE_DIR}":cached
  )

  # Docker run with ALL improvements
  docker run --rm \
    --name "$container_name" \
    --interactive \
    --tty \
    "${env_vars[@]}" \
    "${resource_limits[@]}" \
    "${health_check[@]}" \
    "${volumes[@]}" \
    "$ai_image" \
    claude-code-tools "$@"

  local exit_code=$?

  # Sync config OUT (даже при ошибке!)
  sync_claude_config_out || {
    log_error "Config sync-out failed" "sync_out"
    # Non-fatal, не блокируем exit
  }

  # Log end + metrics
  local end_time=$(date +%s%3N)
  local duration=$((end_time - start_time))

  log_event "info" "claude_end" "{\"exit_code\":$exit_code,\"duration_ms\":$duration,\"trace_id\":\"$TRACE_ID\"}"
  collect_metrics "claude.invocation" 1 "{\"status\":\"$([ $exit_code -eq 0 ] && echo success || echo error)\",\"duration_ms\":$duration}"

  return $exit_code
}
```

## 2.4 Phase 2 Testing

```bash
#!/bin/bash
# tests/phase2-core-tests.sh

set -euo pipefail

source lib/keychain.sh
source lib/sync.sh

echo "🧪 Phase 2: Core Implementation Tests"

# Test 1: Keychain extraction (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Test 1: Keychain extraction..."
  extract_keychain_credentials
  [[ -f ~/.claude.json ]] || {
    echo "❌ FAIL: ~/.claude.json not created"
    exit 1
  }
  echo "✅ PASS"
fi

# Test 2: Sync IN
echo "Test 2: Sync IN..."
sync_claude_config_in || {
  echo "❌ FAIL: Sync IN failed"
  exit 1
}
echo "✅ PASS"

# Test 3: Sync integrity
echo "Test 3: Sync integrity..."
verify_sync_integrity "$HOME/.claude" "$CLAUDE_STATE_DIR" || {
  echo "❌ FAIL: Sync integrity check failed"
  exit 1
}
echo "✅ PASS"

# Test 4: Claude execution
echo "Test 4: Claude execution..."
claude --version >/dev/null 2>&1 || {
  echo "❌ FAIL: Claude execution failed"
  exit 1
}
echo "✅ PASS"

# Test 5: Container cleanup
echo "Test 5: Container cleanup..."
sleep 2
orphaned=$(docker ps -a -f name=claude-session -q | wc -l)
[[ $orphaned -eq 0 ]] || {
  echo "❌ FAIL: Containers not cleaned up ($orphaned found)"
  exit 1
}
echo "✅ PASS"

# Test 6: Sync OUT
echo "Test 6: Sync OUT..."
echo "test-marker-$$" > "$CLAUDE_STATE_DIR/test-marker.txt"
sync_claude_config_out || {
  echo "❌ FAIL: Sync OUT failed"
  exit 1
}
[[ -f ~/.claude/test-marker.txt ]] || {
  echo "❌ FAIL: File not synced back"
  exit 1
}
rm ~/.claude/test-marker.txt
echo "✅ PASS"

echo ""
echo "✅ All Phase 2 tests passed!"
echo "Ready to proceed to Phase 3"
```

## 📋 Phase 2 Checklist

- [ ] Создать `lib/keychain.sh`
- [ ] Создать `lib/sync.sh`
- [ ] Обновить `ai-assistant.zsh` (claude функция)
- [ ] Запустить `tests/phase2-core-tests.sh`
- [ ] Убедиться что все тесты проходят
- [ ] Коммит: `git commit -m "feat(phase2): core implementation with data protection"`

---

**🔗 Next**: [Phase 3: Production Hardening](./PHASE3_HARDENING.md)

**📍 Navigation**: [← Back to Plan v3.0](../../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)
