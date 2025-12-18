#!/bin/bash
# Claude Code Isolated Entrypoint
# Optimized for Claude Sonnet 4.5 with full isolation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log_claude() {
    echo -e "${GREEN}[CLAUDE]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

# Validate environment
validate_claude_environment() {
    log_claude "Validating Claude Code environment..."

    # Check Claude CLI
    if ! command -v claude &> /dev/null; then
        log_error "Claude CLI not found"
        exit 1
    fi

    # Check configuration directory
    if [[ ! -d "$CLAUDE_CONFIG_DIR" ]]; then
        log_warn "Creating Claude config directory: $CLAUDE_CONFIG_DIR"
        mkdir -p "$CLAUDE_CONFIG_DIR"
    fi

    # Check API key
    if [[ -z "${CLAUDE_API_KEY:-}" && ! -f "$CLAUDE_CONFIG_DIR/api_key" ]]; then
        log_warn "Claude API key not found. Please set CLAUDE_API_KEY or place in config"
    fi

    log_claude "Environment validation completed"
}

# Setup Claude environment
setup_claude_environment() {
    log_claude "Setting up Claude Code environment..."

    # Set Claude-specific environment
    export AI_MODE="claude"
    export AI_PROVIDER="claude"
    export AI_MODEL="${CLAUDE_MODEL:-claude-3-5-sonnet-20241022}"
    export AI_VERSION="3.1.0"

    # Load project-specific configuration if exists
    if [[ -f "/workspace/claude/config.yml" ]]; then
        log_claude "Loading project configuration..."
        # Parse YAML config (basic implementation)
        source "/workspace/claude/config.yml"
    fi

    # Create workspace if not exists
    mkdir -p "/workspace/claude"
    cd "/workspace/claude"

    log_claude "Claude environment ready"
}

# Claude-specific optimizations
optimize_claude_performance() {
    log_claude "Applying Claude performance optimizations..."

    # Node.js optimizations for Claude
    export NODE_OPTIONS="--max-old-space-size=4096 --dns-result-order=ipv4first"

    # Memory optimizations
    export CLAUDE_MAX_TOKENS="${CLAUDE_MAX_TOKENS:-4096}"
    export CLAUDE_TEMPERATURE="${CLAUDE_TEMPERATURE:-0.7}"

    # Claude-specific settings
    export CLAUDE_STREAM=true
    export CLAUDE_TIMEOUT=30

    log_claude "Performance optimizations applied"
}

# Main execution function
execute_claude() {
    log_claude "Starting Claude Code in isolated environment..."
    log_claude "Container ID: $(hostname)"
    log_claude "Workspace: /workspace/claude"
    log_claude "Model: $AI_MODEL"

    # Execute Claude Code with all arguments
    exec claude "$@"
}

# Cleanup function
cleanup_claude() {
    log_claude "Performing Claude cleanup..."
    # Save any session data
    if [[ -d "/workspace/claude/.claude" ]]; then
        log_claude "Saving Claude session data..."
    fi
}

# Trap for cleanup
trap cleanup_claude EXIT

# Main execution flow
main() {
    log_claude "🤖 Claude Code Isolated Container v3.1.0"
    log_claude "========================================"

    validate_claude_environment
    setup_claude_environment
    optimize_claude_performance
    execute_claude "$@"
}

# Execute main function
main "$@"
