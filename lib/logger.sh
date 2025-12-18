#!/bin/bash
# Centralized logging system

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default log level
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Log file
LOG_DIR="${LOG_DIR:-$(dirname "${BASH_SOURCE[0]}")/../logs}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/ai-assistant.log}"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Logging functions
log_debug() {
    [[ "$LOG_LEVEL" == "DEBUG" ]] && echo -e "${BLUE}[DEBUG]${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Log rotation
rotate_logs() {
    local max_files="${1:-5}"

    if [[ -f "$LOG_FILE" ]]; then
        for ((i=max_files; i>0; i--)); do
            local old_file="${LOG_FILE}.${i}"
            local new_file="${LOG_FILE}.$((i-1))"

            [[ -f "$new_file" ]] && mv "$new_file" "$old_file"
        done

        mv "$LOG_FILE" "${LOG_FILE}.0"
    fi
}
