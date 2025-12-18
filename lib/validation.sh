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
    errors+=("$HOME/.claude.json not found - authentication will fail")
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
  local available_memory
  available_memory=$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)
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
    local source_size
    source_size=$(stat -f%z "$source_file" 2>/dev/null || echo 0)
    local target_size
    target_size=$(stat -f%z "$target_file" 2>/dev/null || echo 0)

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
