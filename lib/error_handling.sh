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
    disaster_recovery
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
