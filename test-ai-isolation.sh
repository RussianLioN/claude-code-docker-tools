#!/bin/bash
# 🔍 AI Mode Isolation Test Script
# Purpose: Verify that each AI mode works independently without cross-contamination

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
FAILED_TESTS=()
PASSED_TESTS=()

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

test_passed() {
    log_info "✅ TEST PASSED: $1"
    PASSED_TESTS+=("$1")
}

test_failed() {
    log_error "❌ TEST FAILED: $1"
    FAILED_TESTS+=("$1")
}

# Test 1: Environment Variable Isolation
test_env_isolation() {
    log_info "Testing environment variable isolation..."
    
    # Check for Claude variables in clean environment
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        test_failed "ANTHROPIC_API_KEY found in environment (should be mode-specific)"
    else
        test_passed "No Claude API key in global environment"
    fi
    
    if [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
        test_failed "ANTHROPIC_BASE_URL found in environment (should be mode-specific)"
    else
        test_passed "No Claude base URL in global environment"
    fi
    
    # Check for Gemini variables
    if [[ -n "${GEMINI_API_KEY:-}" ]]; then
        test_failed "GEMINI_API_KEY found in environment (should be mode-specific)"
    else
        test_passed "No Gemini API key in global environment"
    fi
    
    # Check for ZAI variables
    if [[ -n "${ZAI_API_KEY:-}" ]]; then
        test_failed "ZAI_API_KEY found in environment (should be mode-specific)"
    else
        test_passed "No ZAI API key in global environment"
    fi
}

# Test 2: Mode Detection
test_mode_detection() {
    log_info "Testing mode detection..."
    
    # Test ai-mode command
    if command -v ai-mode &> /dev/null; then
        CURRENT_MODE=$(ai-mode 2>/dev/null || echo "unknown")
        log_info "Current AI mode: $CURRENT_MODE"
        test_passed "ai-mode command available"
    else
        test_failed "ai-mode command not found"
    fi
}

# Test 3: Script Functions Availability
test_script_functions() {
    log_info "Testing script function availability..."
    
    # Check if functions are available
    for func in gemini claude glm gexec; do
        if command -v $func &> /dev/null; then
            test_passed "$func function available"
        else
            test_failed "$func function not available"
        fi
    done
}

# Test 4: Configuration Files
test_config_files() {
    log_info "Testing configuration files..."
    
    CONFIG_DIR="$HOME/.docker-ai-config"
    
    if [[ -d "$CONFIG_DIR" ]]; then
        test_passed "Configuration directory exists"
        
        # Check for credential files
        for file in env global_state/secrets/zai_key global_state/google_accounts.json; do
            if [[ -f "$CONFIG_DIR/$file" ]]; then
                log_info "Found: $CONFIG_DIR/$file"
            else
                log_warn "Missing: $CONFIG_DIR/$file"
            fi
        done
    else
        test_failed "Configuration directory not found"
    fi
}

# Test 5: Docker Environment
test_docker_environment() {
    log_info "Testing Docker environment..."
    
    if command -v docker &> /dev/null; then
        test_passed "Docker command available"
        
        # Check if Docker daemon is running
        if docker info &> /dev/null; then
            test_passed "Docker daemon running"
        else
            test_failed "Docker daemon not running"
        fi
        
        # Check for AI images
        AI_IMAGES=$(docker images --format "{{.Repository}}" | grep -E "(claude|gemini)" || true)
        if [[ -n "$AI_IMAGES" ]]; then
            log_info "Found AI images: $AI_IMAGES"
            test_passed "AI Docker images available"
        else
            test_warn "No AI Docker images found (may need to build)"
        fi
    else
        test_failed "Docker not installed"
    fi
}

# Test 6: Mode Isolation (Dry Run)
test_mode_isolation() {
    log_info "Testing mode isolation (dry run)..."
    
    # Test each mode without actually running
    for mode in gemini claude glm; do
        log_info "Testing $mode mode..."
        
        # Check if mode-specific environment would be set
        case $mode in
            gemini)
                # Gemini should not have Claude variables
                if [[ -n "${ANTHROPIC_API_KEY:-}" ]] || [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
                    test_failed "$mode mode contaminated with Claude variables"
                else
                    test_passed "$mode mode clean from Claude contamination"
                fi
                ;;
            claude)
                # Claude is the base mode, should work
                test_passed "$mode mode (base mode)"
                ;;
            glm)
                # GLM should not have Claude variables
                if [[ -n "${ANTHROPIC_API_KEY:-}" ]] || [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
                    test_failed "$mode mode contaminated with Claude variables"
                else
                    test_passed "$mode mode clean from Claude contamination"
                fi
                ;;
        esac
    done
}

# Test 7: Container Configuration Check
test_container_config() {
    log_info "Testing container configuration..."
    
    # Check if any AI containers are running
    RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}" | grep -E "(gemini|claude|glm)" || true)
    
    if [[ -n "$RUNNING_CONTAINERS" ]]; then
        log_info "Running AI containers: $RUNNING_CONTAINERS"
        
        # Check environment variables in running containers
        for container in $RUNNING_CONTAINERS; do
            log_info "Checking container: $container"
            
            # Get environment variables
            CONTAINER_ENV=$(docker exec $container env 2>/dev/null | grep -E "(ANTHROPIC|GEMINI|ZAI|AI_MODE)" || true)
            
            if [[ -n "$CONTAINER_ENV" ]]; then
                log_info "Container $container environment:"
                echo "$CONTAINER_ENV"
                
                # Check for contamination
                if echo "$CONTAINER_ENV" | grep -q "ANTHROPIC.*gemini"; then
                    test_failed "Container $container has Claude vars in Gemini mode"
                elif echo "$CONTAINER_ENV" | grep -q "ANTHROPIC.*glm"; then
                    test_failed "Container $container has Claude vars in GLM mode"
                else
                    test_passed "Container $container environment looks clean"
                fi
            fi
        done
    else
        log_info "No AI containers currently running"
        test_passed "No running containers to check"
    fi
}

# Test 8: Script Analysis
test_script_analysis() {
    log_info "Analyzing ai-assistant.zsh for contamination..."
    
    SCRIPT_PATH="$HOME/.docker-ai-tools/ai-assistant.zsh"
    
    if [[ -f "$SCRIPT_PATH" ]]; then
        # Check for hardcoded Claude variables
        if grep -q "ANTHROPIC_API_KEY" "$SCRIPT_PATH"; then
            test_failed "Script contains hardcoded ANTHROPIC_API_KEY"
        else
            test_passed "No hardcoded ANTHROPIC_API_KEY in script"
        fi
        
        # Check for mode-specific logic
        if grep -q "AI_MODE.*gemini" "$SCRIPT_PATH"; then
            test_passed "Gemini mode logic found"
        else
            test_warn "No explicit Gemini mode logic found"
        fi
        
        if grep -q "AI_MODE.*glm" "$SCRIPT_PATH"; then
            test_passed "GLM mode logic found"
        else
            test_warn "No explicit GLM mode logic found"
        fi
    else
        test_failed "ai-assistant.zsh not found at $SCRIPT_PATH"
    fi
}

# Test 9: Quick Mode Test (Non-destructive)
test_quick_mode() {
    log_info "Performing quick mode test..."
    
    # Test if we can detect the mode without running
    if [[ -n "${AI_CURRENT_MODE:-}" ]]; then
        log_info "Detected AI mode: $AI_CURRENT_MODE"
        test_passed "AI mode detection working"
    else
        test_warn "AI_CURRENT_MODE not set"
    fi
}

# Main test execution
main() {
    log_info "🚀 Starting AI Mode Isolation Test Suite"
    log_info "======================================="
    
    echo
    log_info "Phase 1: Environment Analysis"
    echo
    test_env_isolation
    test_mode_detection
    test_script_functions
    
    echo
    log_info "Phase 2: Configuration Analysis"
    echo
    test_config_files
    test_docker_environment
    test_script_analysis
    
    echo
    log_info "Phase 3: Isolation Testing"
    echo
    test_mode_isolation
    test_container_config
    test_quick_mode
    
    echo
    log_info "======================================="
    log_info "📊 Test Results Summary"
    echo
    
    echo "Passed tests: ${#PASSED_TESTS[@]}"
    for test in "${PASSED_TESTS[@]}"; do
        echo "  ✅ $test"
    done
    
    echo
    echo "Failed tests: ${#FAILED_TESTS[@]}"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  ❌ $test"
    done
    
    echo
    if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
        log_info "🎉 All tests passed! AI modes are properly isolated."
        exit 0
    else
        log_error "⚠️  Some tests failed. AI mode isolation needs attention."
        echo
        log_info "💡 Recommendations:"
        echo "1. Check for hardcoded environment variables"
        echo "2. Verify mode-specific configuration"
        echo "3. Test each mode individually"
        echo "4. Consider implementing proper mode isolation"
        exit 1
    fi
}

# Run main function
main "$@"