#!/bin/zsh

# AI Assistant Ephemeral Architecture Test Suite
# Tests for expert ephemeral container patterns based on old-scripts/gemini.zsh

set -eo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
readonly AI_ASSISTANT_SCRIPT="${PROJECT_ROOT}/ai-assistant.zsh"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test results
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test environment
TEST_TEMP_DIR=""
ORIGINAL_DOCKER_HOST=""

# Test framework functions
log_test() {
    local test_name="$1"
    local test_result="$2"
    local details="${3:-}"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [[ "$test_result" == "PASS" ]]; then
        echo -e "  ${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [[ "$test_result" == "FAIL" ]]; then
        echo -e "  ${RED}❌ FAIL${NC}: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        if [[ -n "$details" ]]; then
            echo -e "    ${RED}Details:${NC} $details"
        fi
    elif [[ "$test_result" == "SKIP" ]]; then
        echo -e "  ${YELLOW}⏭️ SKIP${NC}: $test_name"
        TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
        if [[ -n "$details" ]]; then
            echo -e "    ${YELLOW}Reason:${NC} $details"
        fi
    else
        echo -e "  ${YELLOW}⚠️  $test_result${NC}: $test_name"
        if [[ -n "$details" ]]; then
            echo -e "    ${YELLOW}Info:${NC} $details"
        fi
    fi
}

# Setup test environment
setup_test_environment() {
    echo "🧪 Setting up test environment..."

    # Create temp directory for tests
    TEST_TEMP_DIR=$(mktemp -d)
    echo "  📁 Test temp dir: $TEST_TEMP_DIR"

    # Backup original DOCKER_HOST if exists
    if [[ -n "${DOCKER_HOST:-}" ]]; then
        ORIGINAL_DOCKER_HOST="$DOCKER_HOST"
        echo "  🔧 Backing up DOCKER_HOST: $ORIGINAL_DOCKER_HOST"
    fi

    # Source ai-assistant functions
    if [[ ! -f "$AI_ASSISTANT_SCRIPT" ]]; then
        log_test "AI assistant script exists" "FAIL" "File not found: $AI_ASSISTANT_SCRIPT"
        return 1
    fi

    # Source with --quiet flag and capture functions
    AI_TOOLS_HOME="$PROJECT_ROOT"
    source "$AI_ASSISTANT_SCRIPT" --quiet 2>/dev/null || true

    echo "  ✅ Test environment ready"
    return 0
}

# Cleanup test environment
cleanup_test_environment() {
    echo "🧹 Cleaning up test environment..."

    # Kill any running test containers
    docker ps -q --filter "name=test-*" | xargs -r docker kill 2>/dev/null || true
    docker ps -aq --filter "name=test-*" | xargs -r docker rm 2>/dev/null || true

    # Remove temp directory
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
        echo "  🗑️ Removed temp directory"
    fi

    # Restore DOCKER_HOST
    if [[ -n "$ORIGINAL_DOCKER_HOST" ]]; then
        export DOCKER_HOST="$ORIGINAL_DOCKER_HOST"
        echo "  🔄 Restored DOCKER_HOST"
    elif [[ -n "${DOCKER_HOST:-}" ]]; then
        unset DOCKER_HOST
        echo "  🗑️ Unset DOCKER_HOST"
    fi

    echo "  ✅ Cleanup completed"
}

# Test 1: Docker Detection
test_docker_detection() {
    echo -e "\n${BLUE}🐳 Test 1: Docker Environment Detection${NC}"

    # Test Docker command availability
    if command -v docker >/dev/null 2>&1; then
        log_test "Docker command available" "PASS"
    else
        log_test "Docker command available" "FAIL" "Docker not installed"
        return 1
    fi

    # Test Docker daemon can be checked
    if timeout 5 docker info >/dev/null 2>&1; then
        log_test "Docker daemon responsive" "PASS"
    else
        log_test "Docker daemon responsive" "SKIP" "Docker daemon not responding within timeout"
    fi

    # Test ensure_docker_running function exists
    if whence -f ensure_docker_running >/dev/null 2>&1; then
        log_test "ensure_docker_running function exists" "PASS"
    else
        log_test "ensure_docker_running function exists" "FAIL" "Function not found in ai-assistant.zsh"
        return 1
    fi

    return 0
}

# Test 2: SSH Management
test_ssh_management() {
    echo -e "\n${BLUE}🔑 Test 2: SSH Management${NC}"

    # Test SSH agent command availability
    if command -v ssh-add >/dev/null 2>&1; then
        log_test "ssh-add command available" "PASS"
    else
        log_test "ssh-add command available" "SKIP" "OpenSSH not available"
    fi

    # Test ensure_ssh_loaded function exists
    if whence -f ensure_ssh_loaded >/dev/null 2>&1; then
        log_test "ensure_ssh_loaded function exists" "PASS"
    else
        log_test "ensure_ssh_loaded function exists" "FAIL" "Function not found in ai-assistant.zsh"
        return 1
    fi

    # Test SSH agent can be checked
    if timeout 3 ssh-add -l >/dev/null 2>&1; then
        log_test "SSH agent check works" "PASS"
    else
        log_test "SSH agent check works" "SKIP" "SSH agent not responding or empty"
    fi

    return 0
}

# Test 3: Configuration Management
test_config_management() {
    echo -e "\n${BLUE}⚙️ Test 3: Configuration Management${NC}"

    # Test prepare_configuration function exists
    if whence -f prepare_configuration 2>/dev/null >/dev/null; then
        log_test "prepare_configuration function exists" "PASS"
    else
        log_test "prepare_configuration function exists" "FAIL" "Function not found in ai-assistant.zsh"
        return 1
    fi

    # Test configuration directories
    local config_dir="${HOME}/.docker-ai-config"
    if [[ -d "$config_dir" ]]; then
        log_test "Global config directory exists" "PASS"
    else
        log_test "Global config directory exists" "SKIP" "Will be created by prepare_configuration"
    fi

    # Test cleanup_configuration function exists
    if whence -f cleanup_configuration 2>/dev/null >/dev/null; then
        log_test "cleanup_configuration function exists" "PASS"
    else
        log_test "cleanup_configuration function exists" "FAIL" "Function not found in ai-assistant.zsh"
        return 1
    fi

    return 0
}

# Test 4: Basic Container Execution
test_basic_container_execution() {
    echo -e "\n${BLUE}🐳 Test 4: Basic Container Execution${NC}"

    # Test if gexec function exists
    if whence -f gexec 2>/dev/null >/dev/null; then
        log_test "gexec function exists" "PASS"
    else
        log_test "gexec function exists" "FAIL" "Function not found in ai-assistant.zsh"
        return 1
    fi

    # Test simple container command
    echo "  🧪 Testing basic container command..."
    local test_output
    if test_output=$(gexec 'echo "Container test successful"' 2>&1); then
        if echo "$test_output" | grep -q "Container test successful"; then
            log_test "Basic container execution" "PASS"
        else
            log_test "Basic container execution" "FAIL" "Unexpected output: $test_output"
        fi
    else
        log_test "Basic container execution" "FAIL" "Command failed"
        return 1
    fi

    return 0
}

# Test 5: Container File Access
test_container_file_access() {
    echo -e "\n${BLUE}📁 Test 5: Container File Access${NC}"

    # Test file creation and access
    echo "  🧪 Testing file operations in container..."

    local test_file="$TEST_TEMP_DIR/test-container-file.txt"
    if gexec "echo 'Test content' > $test_file" >/dev/null 2>&1; then
        log_test "File creation in container" "PASS"

        # Test file reading
        if gexec "cat $test_file" 2>/dev/null | grep -q "Test content"; then
            log_test "File reading in container" "PASS"
        else
            log_test "File reading in container" "FAIL" "Content not found"
        fi

        # Cleanup
        rm -f "$test_file" 2>/dev/null || true
    else
        log_test "File creation in container" "FAIL" "Could not create test file"
    fi

    # Test project directory access
    echo "  🧪 Testing project directory access..."
    if gexec 'ls -la | head -3' >/dev/null 2>&1; then
        log_test "Project directory listing" "PASS"
    else
        log_test "Project directory listing" "FAIL" "Could not list project directory"
    fi

    return 0
}

# Test 6: AI Mode Function
test_ai_mode_function() {
    echo -e "\n${BLUE}🤖 Test 6: AI Mode Function${NC}"

    # Test ai-mode function exists
    if whence -f ai-mode >/dev/null 2>&1; then
        log_test "ai-mode function exists" "PASS"
    else
        log_test "ai-mode function exists" "FAIL" "Function not found in ai-assistant.zsh"
        return 1
    fi

    # Test ai-mode help output
    echo "  🧪 Testing ai-mode help..."
    local help_output
    if help_output=$(ai-mode help 2>&1); then
        if echo "$help_output" | grep -q "AI Assistant.*Двойной режим работы"; then
            log_test "ai-mode help output" "PASS"
        else
            log_test "ai-mode help output" "FAIL" "Unexpected help output format"
        fi

        # Test for key sections in help
        if echo "$help_output" | grep -q "gemini.*Gemini AI Assistant"; then
            log_test "ai-mode help includes gemini" "PASS"
        else
            log_test "ai-mode help includes gemini" "FAIL" "Gemini section not found"
        fi

        if echo "$help_output" | grep -q "claude.*Claude Code Assistant"; then
            log_test "ai-mode help includes claude" "PASS"
        else
            log_test "ai-mode help includes claude" "FAIL" "Claude section not found"
        fi
    else
        log_test "ai-mode help execution" "FAIL" "Help command failed"
        return 1
    fi

    return 0
}

# Test 7: Container Cleanup
test_container_cleanup() {
    echo -e "\n${BLUE}🧹 Test 7: Container Cleanup${NC}"

    # Count containers before test
    local containers_before
    containers_before=$(docker ps -aq --filter "name=test-*" 2>/dev/null | wc -l)
    echo "  📊 Containers before test: $containers_before"

    # Run a simple container command
    gexec 'echo "cleanup test"' >/dev/null 2>&1

    # Count containers after test - should be same as before (ephemeral)
    local containers_after
    containers_after=$(docker ps -aq --filter "name=test-*" 2>/dev/null | wc -l)
    echo "  📊 Containers after test: $containers_after"

    if [[ $containers_before -eq $containers_after ]]; then
        log_test "Ephemeral container cleanup" "PASS" "No orphaned containers"
    else
        log_test "Ephemeral container cleanup" "FAIL" "Found orphaned containers: $((containers_after - containers_before))"
    fi

    return 0
}

# Test 8: Error Handling
test_error_handling() {
    echo -e "\n${BLUE}⚠️ Test 8: Error Handling${NC}"

    # Test invalid ai-mode argument
    echo "  🧪 Testing invalid ai-mode argument..."
    local error_output
    if error_output=$(ai-mode invalid-mode 2>&1); then
        if echo "$error_output" | grep -q "Неизвестный режим"; then
            log_test "Invalid ai-mode handling" "PASS"
        else
            log_test "Invalid ai-mode handling" "FAIL" "Expected error message not found"
        fi
    else
        log_test "Invalid ai-mode handling" "FAIL" "Should have returned error"
    fi

    # Test gexec with empty command (should show usage)
    echo "  🧪 Testing gexec with no arguments..."
    if gexec 2>&1 | grep -q "Выполнение команды в AI окружении"; then
        log_test "gexec empty argument handling" "PASS"
    else
        log_test "gexec empty argument handling" "FAIL" "Expected usage message not found"
    fi

    return 0
}

# Test 9: Configuration Sync
test_configuration_sync() {
    echo -e "\n${BLUE}🔄 Test 9: Configuration Sync${NC}"

    # Create test project directory
    local test_project_dir="$TEST_TEMP_DIR/test-project"
    mkdir -p "$test_project_dir"

    # Change to test project
    cd "$test_project_dir"

    # Initialize git repo
    git init >/dev/null 2>&1

    # Test prepare_configuration in git repo
    echo "  🧪 Testing prepare_configuration in git repo..."
    if prepare_configuration >/dev/null 2>&1; then
        # Check if .ai-state directory was created
        if [[ -d ".ai-state" ]]; then
            log_test "Git repo .ai-state creation" "PASS"
        else
            log_test "Git repo .ai-state creation" "FAIL" ".ai-state directory not created"
        fi

        # Check if SSH config was sanitized
        if [[ -f ".ai-state/ssh_config_clean" ]]; then
            log_test "SSH config sanitization" "PASS"
        else
            log_test "SSH config sanitization" "FAIL" "SSH config not sanitized"
        fi

        # Test cleanup_configuration
        if cleanup_configuration >/dev/null 2>&1; then
            log_test "Configuration cleanup" "PASS"
        else
            log_test "Configuration cleanup" "FAIL" "Cleanup function failed"
        fi
    else
        log_test "Git repo configuration sync" "FAIL" "prepare_configuration failed"
    fi

    # Return to original directory
    cd "$PROJECT_ROOT"

    # Cleanup test project
    rm -rf "$test_project_dir"

    return 0
}

# Test 10: Performance Validation
test_performance_validation() {
    echo -e "\n${BLUE}⚡ Test 10: Performance Validation${NC}"

    # Test container startup time
    echo "  🧪 Measuring container startup time..."
    local start_time
    start_time=$(date +%s%N)

    gexec 'echo "Performance test"' >/dev/null 2>&1

    local end_time
    end_time=$(date +%s%N)

    local duration=$(( (end_time - start_time) / 1000000 )) # Convert nanoseconds to milliseconds

    echo "  ⏱️ Container startup time: ${duration}ms"

    # Performance target: <2 seconds for expert patterns
    if [[ $duration -lt 2000 ]]; then
        log_test "Container startup performance" "PASS" "Started in ${duration}ms"
    else
        log_test "Container startup performance" "FAIL" "Too slow: ${duration}ms (>2000ms)"
    fi

    # Test memory usage (simple check)
    echo "  🧪 Checking for memory leaks..."
    local containers_before
    containers_before=$(docker ps -q 2>/dev/null | wc -l)

    # Run multiple container operations
    for i in {1..5}; do
        gexec "echo 'Performance test $i'" >/dev/null 2>&1
    done

    local containers_after
    containers_after=$(docker ps -q 2>/dev/null | wc -l)

    if [[ $containers_before -eq $containers_after ]]; then
        log_test "Memory leak detection" "PASS" "No container accumulation"
    else
        log_test "Memory leak detection" "FAIL" "Container accumulation detected: $((containers_after - containers_before))"
    fi

    return 0
}

# Main test runner
run_all_tests() {
    echo -e "${BLUE}🚀 AI Assistant Ephemeral Architecture Test Suite${NC}"
    echo "=================================================="
    echo "Testing expert patterns from old-scripts/gemini.zsh"
    echo ""

    # Setup test environment
    if ! setup_test_environment; then
        echo -e "${RED}❌ Failed to setup test environment${NC}"
        exit 1
    fi

    # Trap cleanup for script exit
    trap cleanup_test_environment EXIT

    # Run individual test suites
    test_docker_detection
    test_ssh_management
    test_config_management
    test_basic_container_execution
    test_container_file_access
    test_ai_mode_function
    test_container_cleanup
    test_error_handling
    test_configuration_sync
    test_performance_validation

    # Show results
    echo -e "\n${BLUE}📊 Test Results${NC}"
    echo "=================================="
    echo "Total Tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo -e "Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"

    local success_rate
    if [[ $((TESTS_PASSED + TESTS_SKIPPED)) -gt 0 ]]; then
        success_rate=$(( (TESTS_PASSED * 100) / (TESTS_PASSED + TESTS_SKIPPED)))
        echo "Success Rate: $success_rate%"
    fi

    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✅ All tests passed! Expert ephemeral architecture working correctly.${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some tests failed! Check implementation before proceeding.${NC}"
        exit 1
    fi
}

# Show help
show_help() {
    cat << EOF
AI Assistant Ephemeral Architecture Test Suite

USAGE:
    $0 [command]

COMMANDS:
    run         Run all tests
    docker      Test Docker environment only
    ssh         Test SSH management only
    config      Test configuration management only
    container   Test container execution only
    mode        Test ai-mode function only
    cleanup     Test container cleanup only
    error       Test error handling only
    sync        Test configuration sync only
    performance Test performance validation only
    help        Show this help

EXAMPLES:
    $0 run                    # Run all tests
    $0 container              # Test container operations
    $0 performance             # Test performance metrics

EOF
}

# Main execution
case "${1:-run}" in
    "run")
        run_all_tests
        ;;
    "docker")
        test_docker_detection && test_basic_container_execution && test_container_cleanup
        ;;
    "ssh")
        test_ssh_management
        ;;
    "config")
        test_config_management && test_configuration_sync
        ;;
    "container")
        test_basic_container_execution && test_container_file_access && test_container_cleanup
        ;;
    "mode")
        test_ai_mode_function
        ;;
    "cleanup")
        test_container_cleanup
        ;;
    "error")
        test_error_handling
        ;;
    "sync")
        test_configuration_sync
        ;;
    "performance")
        test_performance_validation
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
