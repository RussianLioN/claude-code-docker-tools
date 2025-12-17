#!/bin/bash
# Gemini CLI Isolated Entrypoint
# Optimized for Gemini 2.5-Pro with full isolation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log_gemini() {
    echo -e "${GREEN}[GEMINI]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

# Validate environment
validate_gemini_environment() {
    log_gemini "Validating Gemini CLI environment..."
    
    # Check Gemini CLI
    if ! command -v gemini &> /dev/null; then
        log_error "Gemini CLI not found"
        exit 1
    fi
    
    # Check configuration directory
    if [[ ! -d "$GEMINI_CONFIG_DIR" ]]; then
        log_warn "Creating Gemini config directory: $GEMINI_CONFIG_DIR"
        mkdir -p "$GEMINI_CONFIG_DIR"
    fi
    
    # Check Google Cloud credentials
    if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" && ! -f "$GEMINI_CONFIG_DIR/credentials.json" ]]; then
        log_warn "Google Cloud credentials not found. Please set GOOGLE_APPLICATION_CREDENTIALS or place in config"
    fi
    
    log_gemini "Environment validation completed"
}

# Setup Gemini environment
setup_gemini_environment() {
    log_gemini "Setting up Gemini CLI environment..."
    
    # Set Gemini-specific environment
    export AI_MODE="gemini"
    export AI_PROVIDER="gemini"
    export AI_MODEL="${GEMINI_MODEL:-gemini-2.5-pro}"
    export AI_VERSION="3.1.0"
    
    # Google Cloud configuration
    export GOOGLE_CLOUD_PROJECT="${GOOGLE_CLOUD_PROJECT:-claude-code-docker-tools}"
    export GOOGLE_APPLICATION_CREDENTIALS="${GOOGLE_APPLICATION_CREDENTIALS:-$GEMINI_CONFIG_DIR/credentials.json}"
    
    # Load project-specific configuration if exists
    if [[ -f "/workspace/gemini/config.yml" ]]; then
        log_gemini "Loading project configuration..."
        # Parse YAML config (basic implementation)
        source "/workspace/gemini/config.yml"
    fi
    
    # Create workspace if not exists
    mkdir -p "/workspace/gemini"
    cd "/workspace/gemini"
    
    log_gemini "Gemini environment ready"
}

# Gemini-specific optimizations
optimize_gemini_performance() {
    log_gemini "Applying Gemini performance optimizations..."
    
    # Node.js optimizations for Gemini
    export NODE_OPTIONS="--max-old-space-size=4096 --dns-result-order=ipv4first"
    
    # Memory optimizations
    export GEMINI_MAX_TOKENS="${GEMINI_MAX_TOKENS:-4096}"
    export GEMINI_TEMPERATURE="${GEMINI_TEMPERATURE:-0.7}"
    
    # Gemini-specific settings
    export GEMINI_STREAM=true
    export GEMINI_TIMEOUT=30
    
    log_gemini "Performance optimizations applied"
}

# Execute Gemini
execute_gemini() {
    log_gemini "Starting Gemini CLI in isolated environment..."
    log_gemini "Container ID: $(hostname)"
    log_gemini "Workspace: /workspace/gemini"
    log_gemini "Model: $AI_MODEL"
    log_gemini "Project: $GOOGLE_CLOUD_PROJECT"
    
    # Execute Gemini CLI with all arguments
    exec gemini "$@"
}

# Cleanup function
cleanup_gemini() {
    log_gemini "Performing Gemini cleanup..."
    # Save any session data
    if [[ -d "/workspace/gemini/.gemini" ]]; then
        log_gemini "Saving Gemini session data..."
    fi
}

# Trap for cleanup
trap cleanup_gemini EXIT

# Main execution flow
main() {
    log_gemini "🧠 Gemini CLI Isolated Container v3.1.0"
    log_gemini "========================================"
    
    validate_gemini_environment
    setup_gemini_environment
    optimize_gemini_performance
    execute_gemini "$@"
}

# Execute main function
main "$@"