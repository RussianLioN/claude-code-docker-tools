#!/bin/bash
# AI Assistant Isolated Deployment Script
# Step-by-step deployment: Claude → GLM-4.6 → Gemini

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Version
DEPLOYMENT_VERSION="3.1.0"

# Logging functions
log_deploy() {
    echo -e "${GREEN}[DEPLOY]${NC} $1"
}

log_deploy_error() {
    echo -e "${RED}[DEPLOY-ERROR]${NC} $1" >&2
}

log_deploy_warn() {
    echo -e "${YELLOW}[DEPLOY-WARN]${NC} $1" >&2
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Source libraries
source "$(dirname "$0")/lib/docker-core.sh"
source "$(dirname "$0")/lib/config-manager.sh"

# Show deployment banner
show_banner() {
    echo -e "${BLUE}"
    echo "🚀 AI Assistant Isolated Deployment v${DEPLOYMENT_VERSION}"
    echo "=================================================="
    echo -e "${NC}"
    echo "Step-by-step deployment with full isolation:"
    echo "  1️⃣ Claude Sonnet 4.5"
    echo "  2️⃣ GLM-4.6 (True GLM, not Claude masking)"
    echo "  3️⃣ Gemini CLI 2.5-Pro"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_deploy_error "Docker not found. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log_deploy_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check Python for UUID generation
    if ! command -v python3 &> /dev/null; then
        log_deploy_warn "Python3 not found. UUID generation may fail."
    fi
    
    # Check directories
    if [[ ! -d "containers" ]]; then
        log_deploy_error "Containers directory not found. Please run from project root."
        exit 1
    fi
    
    log_deploy "✅ Prerequisites check passed"
}

# Initialize configuration
init_deployment() {
    log_step "Initializing deployment configuration..."
    
    # Initialize directories
    init_config_dirs
    
    # Show available templates
    list_templates
    
    log_deploy "✅ Configuration initialized"
}

# Deploy Claude Code
deploy_claude() {
    log_step "Deploying Claude Sonnet 4.5 (Step 1/3)..."
    
    # Load or create Claude configuration
    if ! load_config "claude"; then
        log_deploy_error "Failed to load Claude configuration"
        return 1
    fi
    
    # Validate configuration
    if ! validate_config "claude"; then
        log_deploy_error "Claude configuration validation failed"
        return 1
    fi
    
    # Build container
    log_deploy "Building Claude isolated container..."
    if ! build_isolated_container "claude"; then
        log_deploy_error "Failed to build Claude container"
        return 1
    fi
    
    # Test container
    log_deploy "Testing Claude container..."
    if docker run --rm --name "claude-test-$(date +%s)" \
        -v "$(pwd)/workspace/claude:/workspace/claude" \
        -v "$(pwd)/config/active/claude:/home/claude/.config" \
        ai-assistant-claude:${DEPLOYMENT_VERSION} \
        --version; then
        log_deploy "✅ Claude container test successful"
    else
        log_deploy_error "Claude container test failed"
        return 1
    fi
    
    log_deploy "✅ Claude Sonnet 4.5 deployed successfully"
    return 0
}

# Deploy GLM-4.6
deploy_glm() {
    log_step "Deploying GLM-4.6 (Step 2/3)..."
    
    # Load or create GLM configuration
    if ! load_config "glm"; then
        log_deploy_error "Failed to load GLM configuration"
        return 1
    fi
    
    # Validate configuration
    if ! validate_config "glm"; then
        log_deploy_error "GLM configuration validation failed"
        return 1
    fi
    
    # Build container
    log_deploy "Building GLM isolated container..."
    if ! build_isolated_container "glm"; then
        log_deploy_error "Failed to build GLM container"
        return 1
    fi
    
    # Test container
    log_deploy "Testing GLM container..."
    if docker run --rm --name "glm-test-$(date +%s)" \
        -v "$(pwd)/workspace/glm:/workspace/glm" \
        -v "$(pwd)/config/active/glm:/home/glm/.config" \
        ai-assistant-glm:${DEPLOYMENT_VERSION} \
        --version; then
        log_deploy "✅ GLM container test successful"
    else
        log_deploy_error "GLM container test failed"
        return 1
    fi
    
    log_deploy "✅ GLM-4.6 deployed successfully"
    return 0
}

# Deploy Gemini CLI
deploy_gemini() {
    log_step "Deploying Gemini CLI 2.5-Pro (Step 3/3)..."
    
    # Load or create Gemini configuration
    if ! load_config "gemini"; then
        log_deploy_error "Failed to load Gemini configuration"
        return 1
    fi
    
    # Validate configuration
    if ! validate_config "gemini"; then
        log_deploy_error "Gemini configuration validation failed"
        return 1
    fi
    
    # Build container
    log_deploy "Building Gemini isolated container..."
    if ! build_isolated_container "gemini"; then
        log_deploy_error "Failed to build Gemini container"
        return 1
    fi
    
    # Test container
    log_deploy "Testing Gemini container..."
    if docker run --rm --name "gemini-test-$(date +%s)" \
        -v "$(pwd)/workspace/gemini:/workspace/gemini" \
        -v "$(pwd)/config/active/gemini:/home/gemini/.config" \
        ai-assistant-gemini:${DEPLOYMENT_VERSION} \
        --version; then
        log_deploy "✅ Gemini container test successful"
    else
        log_deploy_error "Gemini container test failed"
        return 1
    fi
    
    log_deploy "✅ Gemini CLI 2.5-Pro deployed successfully"
    return 0
}

# Interactive deployment
interactive_deployment() {
    log_deploy "Starting interactive deployment..."
    
    # Step 1: Claude
    echo ""
    echo "🤖 Step 1/3: Claude Sonnet 4.5"
    echo "This will deploy Claude Code with full isolation."
    read -p "Deploy Claude? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z "$REPLY" ]]; then
        if deploy_claude; then
            log_deploy "✅ Claude deployment completed"
        else
            log_deploy_error "❌ Claude deployment failed"
            return 1
        fi
    else
        log_deploy_warn "⏭️ Skipping Claude deployment"
    fi
    
    # Step 2: GLM
    echo ""
    echo "🧠 Step 2/3: GLM-4.6"
    echo "This will deploy true GLM-4.6 (not Claude masking)."
    read -p "Deploy GLM-4.6? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z "$REPLY" ]]; then
        if deploy_glm; then
            log_deploy "✅ GLM deployment completed"
        else
            log_deploy_error "❌ GLM deployment failed"
            return 1
        fi
    else
        log_deploy_warn "⏭️ Skipping GLM deployment"
    fi
    
    # Step 3: Gemini
    echo ""
    echo "🔮 Step 3/3: Gemini CLI 2.5-Pro"
    echo "This will deploy Gemini CLI with full isolation."
    read -p "Deploy Gemini? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z "$REPLY" ]]; then
        if deploy_gemini; then
            log_deploy "✅ Gemini deployment completed"
        else
            log_deploy_error "❌ Gemini deployment failed"
            return 1
        fi
    else
        log_deploy_warn "⏭️ Skipping Gemini deployment"
    fi
    
    log_deploy "🎉 Interactive deployment completed!"
}

# Automated deployment
automated_deployment() {
    log_deploy "Starting automated deployment..."
    
    local failed_deployments=0
    
    # Deploy all in sequence
    if ! deploy_claude; then
        ((failed_deployments++))
    fi
    
    if ! deploy_glm; then
        ((failed_deployments++))
    fi
    
    if ! deploy_gemini; then
        ((failed_deployments++))
    fi
    
    if [[ $failed_deployments -eq 0 ]]; then
        log_deploy "🎉 All deployments completed successfully!"
        return 0
    else
        log_deploy_error "❌ ${failed_deployments} deployment(s) failed"
        return 1
    fi
}

# Show deployment status
show_status() {
    log_step "Checking deployment status..."
    
    echo ""
    echo "Container Status:"
    echo "================"
    
    for mode in claude glm gemini; do
        local health=$(health_check "$mode" 2>/dev/null || echo "unknown")
        local status_symbol="❌"
        
        case "$health" in
            "healthy")
                status_symbol="✅"
                ;;
            "unhealthy")
                status_symbol="⚠️"
                ;;
            "unknown")
                status_symbol="❓"
                ;;
        esac
        
        echo "  $(echo ${mode} | tr '[:lower:]' '[:upper:]'): ${status_symbol} ${health}"
    done
    
    echo ""
    echo "Images Available:"
    echo "================"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep "ai-assistant" || echo "  No AI Assistant images found"
}

# Cleanup deployment
cleanup_deployment() {
    log_step "Cleaning up deployment..."
    
    read -p "Remove all AI Assistant containers and images? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_deploy "Removing containers..."
        clean_containers "all"
        
        log_deploy "Removing images..."
        docker images --format "{{.Repository}}:{{.Tag}}" | grep "ai-assistant" | while read -r image; do
            if [[ -n "$image" ]]; then
                log_deploy "Removing image: $image"
                docker rmi "$image" || log_deploy_warn "Failed to remove: $image"
            fi
        done
        
        log_deploy "✅ Cleanup completed"
    else
        log_deploy "Cleanup cancelled"
    fi
}

# Show help
show_help() {
    echo "AI Assistant Isolated Deployment v${DEPLOYMENT_VERSION}"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  interactive    Interactive step-by-step deployment"
    echo "  automated     Automated deployment of all containers"
    echo "  status        Show deployment status"
    echo "  cleanup       Clean up containers and images"
    echo "  help          Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 interactive    # Deploy interactively"
    echo "  $0 automated     # Deploy all automatically"
    echo "  $0 status        # Check current status"
    echo "  $0 cleanup       # Clean up everything"
}

# Main function
main() {
    local command="${1:-interactive}"
    
    show_banner
    
    case "$command" in
        "interactive")
            check_prerequisites
            init_deployment
            interactive_deployment
            ;;
        "automated")
            check_prerequisites
            init_deployment
            automated_deployment
            ;;
        "status")
            show_status
            ;;
        "cleanup")
            cleanup_deployment
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_deploy_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"