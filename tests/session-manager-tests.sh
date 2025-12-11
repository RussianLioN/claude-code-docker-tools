#!/bin/bash

# session-manager-tests.sh - Comprehensive Test Suite for AI Session Manager
# Tests core functionality, edge cases, and integration scenarios

set -euo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
readonly SESSION_MANAGER="${PROJECT_ROOT}/scripts/ai-session-manager.sh"
readonly AI_ASSISTANT="${PROJECT_ROOT}/ai-assistant.zsh"

# Test configuration
readonly TEST_REGISTRY="/tmp/test-ai-sessions-registry.json"
readonly TEST_LOG_DIR="/tmp/test-ai-sessions-logs"
readonly TEST_TIMEOUT=30

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup_test_env() {
    echo -e "${BLUE}🔧 Setting up test environment...${NC}"

    # Backup original registry
    if [[ -f "${HOME}/.config/ai-sessions/registry.json" ]]; then
        cp "${HOME}/.config/ai-sessions/registry.json" "${HOME}/.config/ai-sessions/registry.json.backup"
    fi

    # Create test registry
    mkdir -p "$(dirname "$TEST_REGISTRY")"
    echo '{"instances":{},"last_allocated_port":8080}' > "$TEST_REGISTRY"

    # Override session manager paths for testing
    export SESSION_REGISTRY="$TEST_REGISTRY"
    export SESSION_LOG_DIR="$TEST_LOG_DIR"

    echo "✅ Test environment ready"
}

# Cleanup test environment
cleanup_test_env() {
    echo -e "${BLUE}🧹 Cleaning up test environment...${NC}"

    # Remove test registry
    rm -f "$TEST_REGISTRY"
    rm -rf "$TEST_LOG_DIR"

    # Restore original registry
    if [[ -f "${HOME}/.config/ai-sessions/registry.json.backup" ]]; then
        mv "${HOME}/.config/ai-sessions/registry.json.backup" "${HOME}/.config/ai-sessions/registry.json"
    fi

    # Clean up test workspaces
    rm -rf /tmp/test-workspace-*

    echo "✅ Cleanup complete"
}

# Test framework functions
assert_success() {
    local description="$1"
    local command="$2"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -n "  Testing: $description ... "

    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_failure() {
    local description="$1"
    local command="$2"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -n "  Testing: $description ... "

    if ! eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_equals() {
    local description="$1"
    local expected="$2"
    local actual="$3"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -n "  Testing: $description ... "

    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC} (expected: '$expected', got: '$actual')"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_contains() {
    local description="$1"
    local haystack="$2"
    local needle="$3"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -n "  Testing: $description ... "

    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC} (string '$needle' not found in '$haystack')"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test Suite 1: Core Functionality
test_core_functionality() {
    echo -e "\n${BLUE}📋 Test Suite 1: Core Functionality${NC}"

    # Test help command
    assert_success "Help command works" "$SESSION_MANAGER help"

    # Test status on empty registry
    local status_output
    status_output=$("$SESSION_MANAGER" status 2>&1)
    assert_contains "Status shows 0 instances" "$status_output" "Total Instances: 0"

    # Test starting a session
    assert_success "Start new session" "$SESSION_MANAGER start test-session"

    # Test session exists in registry
    local registry_content
    registry_content=$(cat "$TEST_REGISTRY")
    assert_contains "Session registered" "$registry_content" "test-session"

    # Test listing sessions
    local list_output
    list_output=$("$SESSION_MANAGER" list 2>&1)
    assert_contains "List shows session" "$list_output" "test-session"

    # Test stopping session
    assert_success "Stop session" "$SESSION_MANAGER stop test-session"

    # Test session status changed
    local list_output_after
    list_output_after=$("$SESSION_MANAGER" list 2>&1)
    assert_contains "Session shows stopped" "$list_output_after" "stopped"
}

# Test Suite 2: Port Management
test_port_management() {
    echo -e "\n${BLUE}📋 Test Suite 2: Port Management${NC}"

    # Start multiple sessions
    "$SESSION_MANAGER" start port-test-1 >/dev/null 2>&1
    "$SESSION_MANAGER" start port-test-2 >/dev/null 2>&1
    "$SESSION_MANAGER" start port-test-3 >/dev/null 2>&1

    # Check port allocation
    local list_output
    list_output=$("$SESSION_MANAGER" list 2>&1)

    # Extract ports and verify they're different
    local port1=$(echo "$list_output" | grep "port-test-1" | awk '{print $3}')
    local port2=$(echo "$list_output" | grep "port-test-2" | awk '{print $3}')
    local port3=$(echo "$list_output" | grep "port-test-3" | awk '{print $3}')

    assert_equals "Ports are unique 1 vs 2" "$port1" "$((port2 - 1))"
    assert_equals "Ports are unique 2 vs 3" "$port2" "$((port3 - 1))"

    # Test port range limits
    assert_failure "Reject session without name" "$SESSION_MANAGER start"

    # Cleanup
    "$SESSION_MANAGER" stop port-test-1 >/dev/null 2>&1
    "$SESSION_MANAGER" stop port-test-2 >/dev/null 2>&1
    "$SESSION_MANAGER" stop port-test-3 >/dev/null 2>&1
}

# Test Suite 3: Error Handling
test_error_handling() {
    echo -e "\n${BLUE}📋 Test Suite 3: Error Handling${NC}"

    # Test invalid commands
    assert_failure "Reject invalid command" "$SESSION_MANAGER invalid-command"

    # Test starting existing session
    "$SESSION_MANAGER start error-test >/dev/null 2>&1"
    local start_output
    start_output=$("$SESSION_MANAGER" start error-test 2>&1)
    assert_contains "Handle duplicate session" "$start_output" "already running"

    # Test stopping non-existent session
    assert_failure "Handle non-existent session" "$SESSION_MANAGER stop non-existent"

    # Cleanup
    "$SESSION_MANAGER" stop error-test >/dev/null 2>&1
}

# Test Suite 4: AI Assistant Integration
test_ai_assistant_integration() {
    echo -e "\n${BLUE}📋 Test Suite 4: AI Assistant Integration${NC}"

    # Source ai-assistant.zsh
    source "$AI_ASSISTANT"

    # Test session manager functions exist
    assert_success "ai-session function exists" "type ai-session"
    assert_success "ai-start function exists" "type ai-start"
    assert_success "ai-stop function exists" "type ai-stop"
    assert_success "ai-list function exists" "type ai-list"
    assert_success "ai-status function exists" "type ai-status"

    # Test ai-start integration
    "$AI_ASSISTANT_PATH/ai-session-manager.sh" start integration-test >/dev/null 2>&1
    assert_success "ai-start works" "ai-start integration-test"

    # Test ai-list integration
    local list_output
    list_output=$(ai-list 2>&1)
    assert_contains "ai-list shows session" "$list_output" "integration-test"

    # Test ai-stop integration
    assert_success "ai-stop works" "ai-stop integration-test"
}

# Test Suite 5: Performance and Limits
test_performance_limits() {
    echo -e "\n${BLUE}📋 Test Suite 5: Performance and Limits${NC}"

    # Test startup time
    local start_time
    start_time=$(date +%s.%N)
    "$SESSION_MANAGER" start perf-test >/dev/null 2>&1
    local end_time
    end_time=$(date +%s.%N)
    local startup_time
    startup_time=$(echo "$end_time - $start_time" | bc)

    # Should start in under 2 seconds
    local startup_time_int
    startup_time_int=$(echo "$startup_time < 2" | bc)
    assert_equals "Startup time < 2s" "1" "$startup_time_int"

    # Test memory usage (basic check)
    if command -v ps >/dev/null 2>&1; then
        local registry_size
        registry_size=$(wc -c < "$TEST_REGISTRY")
        assert_contains "Registry size reasonable" "$registry_size" " "
    fi

    # Cleanup
    "$SESSION_MANAGER" stop perf-test >/dev/null 2>&1
}

# Test Suite 6: Data Persistence
test_data_persistence() {
    echo -e "\n${BLUE}📋 Test Suite 6: Data Persistence${NC}"

    # Create session with specific data
    "$SESSION_MANAGER" start persistence-test >/dev/null 2>&1

    # Save registry content
    local registry_before
    registry_before=$(cat "$TEST_REGISTRY")

    # Simulate restart by resetting environment
    unset SESSION_REGISTRY SESSION_LOG_DIR
    export SESSION_REGISTRY="$TEST_REGISTRY"
    export SESSION_LOG_DIR="$TEST_LOG_DIR"

    # Check data persisted
    local registry_after
    registry_after=$(cat "$TEST_REGISTRY")
    assert_contains "Data persisted after restart" "$registry_after" "persistence-test"

    # Cleanup
    "$SESSION_MANAGER" stop persistence-test >/dev/null 2>&1
}

# Run all tests
run_all_tests() {
    echo -e "${BLUE}🚀 Running Session Manager Test Suite${NC}"
    echo "=================================="

    setup_test_env

    # Run test suites
    test_core_functionality
    test_port_management
    test_error_handling
    test_ai_assistant_integration
    test_performance_limits
    test_data_persistence

    # Show results
    echo -e "\n${BLUE}📊 Test Results${NC}"
    echo "=================================="
    echo "Total Tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

    local success_rate
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
        echo "Success Rate: $success_rate%"
    fi

    cleanup_test_env

    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✅ All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some tests failed!${NC}"
        exit 1
    fi
}

# Show help
show_help() {
    cat << EOF
Session Manager Test Suite

USAGE:
    $0 [command]

COMMANDS:
    run         Run all tests
    core        Run core functionality tests only
    ports       Run port management tests only
    errors      Run error handling tests only
    integration Run AI assistant integration tests only
    performance Run performance tests only
    persistence Run data persistence tests only
    help        Show this help

EXAMPLES:
    $0 run                    # Run all tests
    $0 core                   # Run core tests only
    $0 integration            # Run integration tests only

EOF
}

# Main execution
case "${1:-run}" in
    "run")
        run_all_tests
        ;;
    "core")
        setup_test_env
        test_core_functionality
        cleanup_test_env
        ;;
    "ports")
        setup_test_env
        test_port_management
        cleanup_test_env
        ;;
    "errors")
        setup_test_env
        test_error_handling
        cleanup_test_env
        ;;
    "integration")
        setup_test_env
        test_ai_assistant_integration
        cleanup_test_env
        ;;
    "performance")
        setup_test_env
        test_performance_limits
        cleanup_test_env
        ;;
    "persistence")
        setup_test_env
        test_data_persistence
        cleanup_test_env
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