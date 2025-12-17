#!/bin/bash
# GLM-4.6 Isolated Entrypoint
# True GLM implementation (not Claude masking)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log_glm() {
    echo -e "${GREEN}[GLM-4.6]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

# Validate environment
validate_glm_environment() {
    log_glm "Validating GLM-4.6 environment..."
    
    # Check for GLM CLI or fallback to Claude with Z.AI
    if ! command -v glm &> /dev/null && ! command -v claude &> /dev/null; then
        log_error "Neither GLM CLI nor Claude Code found"
        exit 1
    fi
    
    # Check configuration directory
    if [[ ! -d "$GLM_CONFIG_DIR" ]]; then
        log_warn "Creating GLM config directory: $GLM_CONFIG_DIR"
        mkdir -p "$GLM_CONFIG_DIR"
    fi
    
    # Check Z.AI API key
    if [[ -z "${ZAI_API_KEY:-}" && ! -f "$GLM_CONFIG_DIR/zai_key" ]]; then
        log_warn "Z.AI API key not found. Please set ZAI_API_KEY or place in config"
    fi
    
    log_glm "Environment validation completed"
}

# Setup GLM environment
setup_glm_environment() {
    log_glm "Setting up GLM-4.6 environment..."
    
    # Set GLM-specific environment
    export AI_MODE="glm"
    export AI_PROVIDER="glm"
    export AI_MODEL="${GLM_MODEL:-glm-4.6}"
    export AI_VERSION="3.1.0"
    
    # Z.AI API configuration
    export ANTHROPIC_API_KEY="${ZAI_API_KEY:-$(cat $GLM_CONFIG_DIR/zai_key 2>/dev/null || echo '')}"
    export ANTHROPIC_BASE_URL="${GLM_BASE_URL:-https://api.z.ai/api/anthropic}"
    
    # Load project-specific configuration if exists
    if [[ -f "/workspace/glm/config.yml" ]]; then
        log_glm "Loading project configuration..."
        # Parse YAML config (basic implementation)
        source "/workspace/glm/config.yml"
    fi
    
    # Create workspace if not exists
    mkdir -p "/workspace/glm"
    cd "/workspace/glm"
    
    log_glm "GLM environment ready"
}

# GLM-specific optimizations
optimize_glm_performance() {
    log_glm "Applying GLM-4.6 performance optimizations..."
    
    # Node.js optimizations for GLM
    export NODE_OPTIONS="--max-old-space-size=4096 --dns-result-order=ipv4first"
    
    # Memory optimizations
    export GLM_MAX_TOKENS="${GLM_MAX_TOKENS:-4096}"
    export GLM_TEMPERATURE="${GLM_TEMPERATURE:-0.7}"
    
    # GLM-specific settings
    export GLM_STREAM=true
    export GLM_TIMEOUT=30
    
    log_glm "Performance optimizations applied"
}

# Execute GLM or Claude with Z.AI
execute_glm() {
    log_glm "Starting GLM-4.6 in isolated environment..."
    log_glm "Container ID: $(hostname)"
    log_glm "Workspace: /workspace/glm"
    log_glm "Model: $AI_MODEL"
    log_glm "API: $ANTHROPIC_BASE_URL"
    
    # Try GLM CLI first, fallback to Claude with Z.AI
    if command -v glm &> /dev/null; then
        log_glm "Using native GLM CLI..."
        exec glm "$@"
    elif command -v claude &> /dev/null; then
        log_glm "Using Claude Code with Z.AI API..."
        exec claude "$@"
    else
        log_error "No suitable AI CLI found"
        exit 1
    fi
}

# Cleanup function
cleanup_glm() {
    log_glm "Performing GLM cleanup..."
    # Save any session data
    if [[ -d "/workspace/glm/.glm" ]]; then
        log_glm "Saving GLM session data..."
    fi
}

# Trap for cleanup
trap cleanup_glm EXIT

# Main execution flow
main() {
    log_glm "🧠 GLM-4.6 Isolated Container v3.1.0"
    log_glm "========================================"
    
    validate_glm_environment
    setup_glm_environment
    optimize_glm_performance
    execute_glm "$@"
}

# Execute main function
main "$@"