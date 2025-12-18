#!/bin/bash

# docker-integration-tests.sh - Comprehensive Docker Integration Testing
# Tests Session Manager with real Docker containers and AI IDE functionality

set -euo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
readonly SESSION_MANAGER="${PROJECT_ROOT}/scripts/ai-session-manager.sh"

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

# Test framework functions
log_test() {
    local test_name="$1"
    local status="$2"
    local details="${3:-}"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [[ "$status" == "PASS" ]]; then
        echo -e "  ${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [[ "$status" == "FAIL" ]]; then
        echo -e "  ${RED}❌ FAIL${NC}: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        if [[ -n "$details" ]]; then
            echo -e "    ${RED}Details:${NC} $details"
        fi
    else
        echo -e "  ${YELLOW}⚠️  $status${NC}: $test_name"
        if [[ -n "$details" ]]; then
            echo -e "    ${YELLOW}Info:${NC} $details"
        fi
    fi
}

# Test 1: Docker Environment Detection
test_docker_environment() {
    echo -e "\n${BLUE}🧪 Test 1: Docker Environment Detection${NC}"

    # Test Docker is available
    if command -v docker >/dev/null 2>&1; then
        log_test "Docker command available" "PASS"
    else
        log_test "Docker command available" "FAIL" "Docker not installed"
        return 1
    fi

    # Test Docker daemon is running
    if docker info >/dev/null 2>&1; then
        log_test "Docker daemon running" "PASS"
    else
        log_test "Docker daemon running" "FAIL" "Docker daemon not responding"
        return 1
    fi

    # Test claude-code-tools image exists
    if docker images --format "table {{.Repository}}" | grep -q "claude-code-tools"; then
        log_test "claude-code-tools image exists" "PASS"
    else
        log_test "claude-code-tools image exists" "FAIL" "Image not found"
        return 1
    fi

    return 0
}

# Test 2: Session Manager Basic Operations
test_session_manager_basic() {
    echo -e "\n${BLUE}🧪 Test 2: Session Manager Basic Operations${NC}"

    # Test help command
    if "$SESSION_MANAGER" help >/dev/null 2>&1; then
        log_test "Session manager help command" "PASS"
    else
        log_test "Session manager help command" "FAIL" "Help command failed"
    fi

    # Test status command
    if "$SESSION_MANAGER" status >/dev/null 2>&1; then
        log_test "Session manager status command" "PASS"
    else
        log_test "Session manager status command" "FAIL" "Status command failed"
    fi

    # Test list command
    if "$SESSION_MANAGER" list >/dev/null 2>&1; then
        log_test "Session manager list command" "PASS"
    else
        log_test "Session manager list command" "FAIL" "List command failed"
    fi

    return 0
}

# Test 3: Container Lifecycle
test_container_lifecycle() {
    echo -e "\n${BLUE}🧪 Test 3: Container Lifecycle Management${NC}"

    local test_instance="test-lifecycle-$(date +%s)"

    # Test container start
    echo "  Starting test instance: $test_instance"
    if "$SESSION_MANAGER" start "$test_instance" >/dev/null 2>&1; then
        log_test "Container start" "PASS"
    else
        log_test "Container start" "FAIL" "Failed to start container"
        return 1
    fi

    # Give container time to fully initialize
    echo "  Waiting for container initialization..."
    sleep 5

    # Test container is running
    local container_name="ai-session-${test_instance}"
    if docker ps --format "{{.Names}}" | grep -q "$container_name"; then
        log_test "Container running verification" "PASS"
    else
        log_test "Container running verification" "FAIL" "Container not found in docker ps"
    fi

    # Test container accessibility
    local container_id=$(docker ps -qf "name=$container_name")
    if [[ -n "$container_id" ]]; then
        if docker exec "$container_id" echo "test" >/dev/null 2>&1; then
            log_test "Container accessibility" "PASS"
        else
            log_test "Container accessibility" "FAIL" "Cannot execute commands in container"
        fi
    else
        log_test "Container accessibility" "FAIL" "Container ID not found"
    fi

    # Test container stop
    echo "  Stopping test instance: $test_instance"
    if "$SESSION_MANAGER" stop "$test_instance" >/dev/null 2>&1; then
        log_test "Container stop" "PASS"
    else
        log_test "Container stop" "FAIL" "Failed to stop container"
    fi

    # Test container cleanup
    sleep 2
    if ! docker ps -a --format "{{.Names}}" | grep -q "$container_name"; then
        log_test "Container cleanup" "PASS"
    else
        log_test "Container cleanup" "FAIL" "Container still exists after stop"
    fi

    return 0
}

# Test 4: Project File Mapping
test_project_file_mapping() {
    echo -e "\n${BLUE}🧪 Test 4: Project File Mapping${NC}"

    local test_instance="test-mapping-$(date +%s)"
    local project_dir="$PROJECT_ROOT"
    local project_name="claude-code-docker-tools"

    echo "  Starting test instance for file mapping: $test_instance"
    if "$SESSION_MANAGER" start "$test_instance" >/dev/null 2>&1; then
        log_test "Container start for file mapping" "PASS"
    else
        log_test "Container start for file mapping" "FAIL"
        return 1
    fi

    # Wait for container initialization
    sleep 5

    local container_name="ai-session-${test_instance}"
    local container_id=$(docker ps -qf "name=$container_name")
    local container_workdir="/app/$project_name"

    # Test project directory exists in container
    if docker exec "$container_id" test -d "$container_workdir"; then
        log_test "Project directory mapped" "PASS"
    else
        log_test "Project directory mapped" "FAIL" "Directory not found in container"
    fi

    # Test specific files are accessible
    local test_files=("README.md" "Dockerfile" "CLAUDE.md" "scripts/ai-session-manager.sh")
    for file in "${test_files[@]}"; do
        if docker exec "$container_id" test -f "$container_workdir/$file"; then
            log_test "File accessible: $file" "PASS"
        else
            log_test "File accessible: $file" "FAIL" "File not found in container"
        fi
    done

    # Test write permissions
    local test_file="$container_workdir/.test-write"
    if docker exec "$container_id" touch "$test_file" 2>/dev/null; then
        docker exec "$container_id" rm "$test_file" 2>/dev/null
        log_test "Write permissions" "PASS"
    else
        log_test "Write permissions" "FAIL" "Cannot write to project directory"
    fi

    # Cleanup
    echo "  Cleaning up test instance: $test_instance"
    "$SESSION_MANAGER" stop "$test_instance" >/dev/null 2>&1

    return 0
}

# Test 5: AI IDE Functionality
test_ai_ide_functionality() {
    echo -e "\n${BLUE}🧪 Test 5: AI IDE Functionality in Container${NC}"

    local test_instance="test-ai-$(date +%s)"

    echo "  Starting test instance for AI IDE: $test_instance"
    if "$SESSION_MANAGER" start "$test_instance" >/dev/null 2>&1; then
        log_test "Container start for AI IDE test" "PASS"
    else
        log_test "Container start for AI IDE test" "FAIL"
        return 1
    fi

    # Wait for full initialization
    sleep 10

    local container_name="ai-session-${test_instance}"
    local container_id=$(docker ps -qf "name=$container_name")

    # Test entrypoint is working
    if docker exec "$container_id" which claude >/dev/null 2>&1; then
        log_test "Claude CLI available in container" "PASS"
    else
        log_test "Claude CLI available in container" "FAIL" "Claude not found"
    fi

    if docker exec "$container_id" which gemini >/dev/null 2>&1; then
        log_test "Gemini CLI available in container" "PASS"
    else
        log_test "Gemini CLI available in container" "FAIL" "Gemini not found"
    fi

    # Test node environment (since container is node:22-alpine)
    if docker exec "$container_id" node --version >/dev/null 2>&1; then
        log_test "Node.js environment" "PASS"
    else
        log_test "Node.js environment" "FAIL" "Node.js not working"
    fi

    # Test basic AI command execution
    echo "  Testing basic AI command execution..."
    local ai_test_result=$(docker exec "$container_id" timeout 10s claude --version 2>/dev/null || echo "timeout")
    if [[ "$ai_test_result" != "timeout" && -n "$ai_test_result" ]]; then
        log_test "Claude command execution" "PASS"
    else
        log_test "Claude command execution" "FAIL" "Command timed out or failed"
    fi

    # Cleanup
    echo "  Cleaning up AI IDE test instance: $test_instance"
    "$SESSION_MANAGER" stop "$test_instance" >/dev/null 2>&1

    return 0
}

# Main test runner
run_all_tests() {
    echo -e "${BLUE}🚀 Docker Integration Test Suite${NC}"
    echo "=================================="
    echo "Testing Session Manager with real Docker containers"
    echo ""

    # Run test suites
    test_docker_environment
    test_session_manager_basic
    test_container_lifecycle
    test_project_file_mapping
    test_ai_ide_functionality

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

    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✅ All tests passed! Ready for user acceptance testing${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some tests failed! Fix issues before proceeding${NC}"
        exit 1
    fi
}

# Show help
show_help() {
    cat << EOF
Docker Integration Test Suite

USAGE:
    $0 [command]

COMMANDS:
    run         Run all integration tests
    docker      Test Docker environment only
    basic       Test Session Manager basic operations
    container   Test container lifecycle
    mapping     Test project file mapping
    ai          Test AI IDE functionality
    help        Show this help

EXAMPLES:
    $0 run                    # Run all tests
    $0 docker                 # Test Docker only
    $0 container              # Test container operations

EOF
}

# Main execution
case "${1:-run}" in
    "run")
        run_all_tests
        ;;
    "docker")
        test_docker_environment
        ;;
    "basic")
        test_session_manager_basic
        ;;
    "container")
        test_container_lifecycle
        ;;
    "mapping")
        test_project_file_mapping
        ;;
    "ai")
        test_ai_ide_functionality
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
