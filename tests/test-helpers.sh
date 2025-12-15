#!/bin/bash

# Test Helper Functions for AI Assistant Ephemeral Architecture
# Utilities for mocking, setup, and validation

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test tracking
TEST_HOOKS_CALLED=0
TEST_MOCKS_ACTIVE=false

# Mock functions for safe testing
enable_docker_mocks() {
    TEST_MOCKS_ACTIVE=true
    echo "🔧 Docker mocks enabled (safe testing mode)"
}

disable_docker_mocks() {
    TEST_MOCKS_ACTIVE=false
    echo "🔧 Docker mocks disabled (real testing mode)"
}

# Hook into docker commands for testing
mock_docker_commands() {
    if [[ "$TEST_MOCKS_ACTIVE" == "true" ]]; then
        # Mock docker command for safe testing
        docker() {
            local command="$1"
            shift

            case "$command" in
                "run")
                    echo "mock-docker-run: $*"
                    echo "MOCK_CONTAINER_ID: mock_container_123456"
                    return 0
                    ;;
                "ps")
                    echo "MOCK_DOCKER_PS_OUTPUT"
                    return 0
                    ;;
                "rm")
                    echo "MOCK_DOCKER_RM: $*"
                    return 0
                    ;;
                "stop")
                    echo "MOCK_DOCKER_STOP: $*"
                    return 0
                    ;;
                "kill")
                    echo "MOCK_DOCKER_KILL: $*"
                    return 0
                    ;;
                "info")
                    echo "MOCK_DOCKER_INFO"
                    return 0
                    ;;
                "images")
                    echo "REPOSITORY          TAG                 IMAGE ID            SIZE"
                    echo "claude-code-tools latest              abcdef1234567    1.55GB"
                    return 0
                    ;;
                *)
                    echo "MOCK_DOCKER_UNKNOWN: $command $*"
                    return 0
                    ;;
            esac
        }

        # Mock docker-compose if needed
        docker-compose() {
            echo "MOCK_DOCKER_COMPOSE: $*"
            return 0
        }

        # Mock git commands for safe testing
        git() {
            local command="$1"
            shift

            case "$command" in
                "init")
                    echo "Initialized empty Git repository"
                    return 0
                    ;;
                "status")
                    echo "On branch master"
                    echo "No commits yet"
                    return 0
                    ;;
                "add")
                    return 0
                    ;;
                "commit")
                    echo "[master abc1234] Test commit"
                    return 0
                    ;;
                "rev-parse")
                    echo "/test/path"
                    return 0
                    ;;
                *)
                    echo "MOCK_GIT: $command $*"
                    return 0
                    ;;
            esac
        }

        # Mock gh command
        gh() {
            echo "MOCK_GITHUB_CLI: $*"
            return 0
        }

        # Mock ssh commands
        ssh-add() {
            echo "MOCK_SSH_ADD: $*"
            return 0
        }

        ssh() {
            echo "MOCK_SSH: $*"
            return 0
        }
    fi
}

# Restore original commands
restore_original_commands() {
    if [[ "$TEST_MOCKS_ACTIVE" == "true" ]]; then
        unset -f docker 2>/dev/null || true
        unset -f docker-compose 2>/dev/null || true
        unset -f git 2>/dev/null || true
        unset -f gh 2>/dev/null || true
        unset -f ssh-add 2>/dev/null || true
        unset -f ssh 2>/dev/null || true
        TEST_MOCKS_ACTIVE=false
        echo "🔧 Restored original commands"
    fi
}

# Setup isolated test environment
setup_isolated_environment() {
    local test_name="$1"
    local test_dir="/tmp/ai-assistant-test-${test_name}-$(date +%s)"

    echo "🧪 Setting up isolated environment: $test_dir"

    # Create test directory
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Create test git repository
    git init >/dev/null 2>&1

    # Create basic project structure
    mkdir -p src tests docs
    echo "# Test Project" > README.md

    # Configure git user for testing
    git config user.name "Test User"
    git config user.email "test@example.com"

    echo "$test_dir"
}

# Cleanup test environment
cleanup_isolated_environment() {
    local test_dir="${1:-$(pwd)}"

    echo "🧹 Cleaning up test environment: $test_dir"

    # Remove test directory if it looks like a test directory
    if [[ "$test_dir" == /tmp/ai-assistant-test-* ]]; then
        cd /
        rm -rf "$test_dir" 2>/dev/null || echo "Warning: Could not remove $test_dir"
    fi
}

# Capture function output for validation
capture_function_output() {
    local function_name="$1"
    shift
    local output_file="${1:-/tmp/test_output_$(date +%s).txt}"

    echo "📸 Capturing output from: $function_name"

    # Execute function and capture output
    "$function_name" "$@" > "$output_file" 2>&1
    local exit_code=$?

    echo "  📄 Output saved to: $output_file"
    echo "  📋 Exit code: $exit_code"

    # Return exit code and output file path
    echo "$exit_code:$output_file"
}

# Verify container cleanup
verify_container_cleanup() {
    echo "🔍 Verifying container cleanup..."

    local test_containers
    test_containers=$(docker ps -aq --filter "name=test-*" 2>/dev/null || true)

    if [[ -n "$test_containers" ]]; then
        echo "  ⚠️ Found test containers: $test_containers"
        echo "  🗑️ Force removing..."
        docker ps -aq --filter "name=test-*" | xargs -r docker rm -f 2>/dev/null || true
    else
        echo "  ✅ No test containers found"
    fi

    # Check for orphaned volumes (optional)
    local test_volumes
    test_volumes=$(docker volume ls -q --filter "name=test-*" 2>/dev/null || true)

    if [[ -n "$test_volumes" ]]; then
        echo "  📦 Found test volumes: $test_volumes"
        echo "  🗑️ Removing volumes..."
        docker volume ls -q --filter "name=test-*" | xargs -r docker volume rm -f 2>/dev/null || true
    else
        echo "  ✅ No orphaned volumes found"
    fi
}

# Create test configuration files
create_test_configs() {
    local test_dir="$1"

    echo "📝 Creating test configuration files..."

    # Create mock global config
    mkdir -p "$HOME/.docker-ai-config"
    echo '{"model": "test-model", "temperature": 0.7}' > "$HOME/.docker-ai-config/settings.json"

    # Create mock SSH config
    mkdir -p "$HOME/.ssh"
    echo "Host github.com" > "$HOME/.ssh/config"
    echo "    UserKnownHostsFile ~/.ssh/known_hosts" >> "$HOME/.ssh/config"

    # Create mock known_hosts
    echo "github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC" > "$HOME/.ssh/known_hosts"
}

# Clean test configuration files
cleanup_test_configs() {
    echo "🗑️ Cleaning up test configuration files..."

    rm -rf "$HOME/.docker-ai-config" 2>/dev/null || true
    rm -f "$HOME/.ssh/config.test" 2>/dev/null || true
}

# Assert functions for testing
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    if [[ "$expected" == "$actual" ]]; then
        echo "✅ $message"
        return 0
    else
        echo "❌ $message"
        echo "   Expected: '$expected'"
        echo "   Actual:   '$actual'"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String not found}"

    if [[ "$haystack" == *"$needle"* ]]; then
        echo "✅ $message"
        return 0
    else
        echo "❌ $message"
        echo "   Looking for: '$needle'"
        echo "   In: '$haystack'"
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"
    local message="${2:-File does not exist: $file_path}"

    if [[ -f "$file_path" ]]; then
        echo "✅ $message"
        return 0
    else
        echo "❌ $message"
        return 1
    fi
}

assert_directory_exists() {
    local dir_path="$1"
    local message="${2:-Directory does not exist: $dir_path}"

    if [[ -d "$dir_path" ]]; then
        echo "✅ $message"
        return 0
    else
        echo "❌ $message"
        return 1
    fi
}

# Performance measurement utilities
measure_time() {
    local description="$1"
    shift

    echo "⏱️ Measuring: $description"

    local start_time
    start_time=$(date +%s%N)

    "$@"
    local exit_code=$?

    local end_time
    end_time=$(date +%s%N)

    local duration=$(( (end_time - start_time) / 1000000 ))
    echo "⏱️ $description completed in ${duration}ms (exit: $exit_code)"

    return $exit_code
}

# Memory usage measurement
measure_memory() {
    local description="$1"
    shift

    echo "🧠 Measuring memory usage: $description"

    # Get memory usage before
    local mem_before=$(ps -o pid,ppid,rss,vsz | grep -E "^[[:space:]]*[0-9]+" | awk '{sum+=$3} END {print sum}')

    # Run the command
    "$@"
    local exit_code=$?

    # Get memory usage after
    local mem_after=$(ps -o pid,ppid,rss,vsz | grep -E "^[[:space:]]*[0-9]+" | awk '{sum+=$3} END {print sum}')

    local mem_used=$((mem_after - mem_before))
    echo "🧠 $description used ${mem_used}KB of memory"

    return $exit_code
}

# Count Docker resources
count_docker_resources() {
    echo "🐳 Counting Docker resources..."

    local containers
    containers=$(docker ps -q 2>/dev/null | wc -l)
    echo "  📦 Running containers: $containers"

    local images
    images=$(docker images -q 2>/dev/null | wc -l)
    echo "  🖼️ Images: $images"

    local volumes
    volumes=$(docker volume ls -q 2>/dev/null | wc -l)
    echo "  📦 Volumes: $volumes"

    return 0
}

# Hook into function calls for debugging
debug_function_call() {
    local function_name="$1"
    shift

    if [[ $TEST_HOOKS_CALLED -gt 0 ]]; then
        echo "🔍 DEBUG: Calling $function_name with args: $*"
    fi

    TEST_HOOKS_CALLED=$((TEST_HOOKS_CALLED + 1))

    # Call the actual function
    "$function_name" "$@"
    local result=$?

    TEST_HOOKS_CALLED=$((TEST_HOOKS_CALLED - 1))

    return $result
}

# Enable debug mode
enable_debug_mode() {
    TEST_HOOKS_CALLED=1
    echo "🐛 Debug mode enabled - all function calls will be traced"
}

# Disable debug mode
disable_debug_mode() {
    TEST_HOOKS_CALLED=0
    echo "🔧 Debug mode disabled"
}

# Wait for container to be ready (helper for tests)
wait_for_container() {
    local container_name="$1"
    local max_wait="${2:-30}"
    local wait_count=0

    echo "⏳ Waiting for container: $container_name"

    while [[ $wait_count -lt $max_wait ]]; do
        if docker exec "$container_name" echo "ready" >/dev/null 2>&1; then
            echo "✅ Container ready after ${wait_count}s"
            return 0
        fi
        sleep 1
        ((wait_count++))
        echo -n "."
    done

    echo ""
    echo "❌ Container not ready after ${max_wait}s"
    return 1
}

# Check if Docker daemon is healthy
check_docker_health() {
    local max_wait="${1:-30}"
    local wait_count=0

    while [[ $wait_count -lt $max_wait ]]; do
        if docker info >/dev/null 2>&1; then
            echo "✅ Docker daemon is healthy"
            return 0
        fi
        sleep 1
        ((wait_count++))
        echo -n "."
    done

    echo ""
    echo "❌ Docker daemon not responding after ${max_wait}s"
    return 1
}

# Test framework version info
show_test_framework_info() {
    echo "🧪 AI Assistant Test Framework v1.0"
    echo "   Testing: Expert Ephemeral Architecture"
    echo "   Based on: old-scripts/gemini.zsh patterns"
    echo "   Status: Ready for production testing"
}

# Export all functions for use in test scripts
export -f enable_docker_mocks
export -f disable_docker_mocks
export -f mock_docker_commands
export -f restore_original_commands
export -f setup_isolated_environment
export -f cleanup_isolated_environment
export -f capture_function_output
export -f verify_container_cleanup
export -f create_test_configs
export -f cleanup_test_configs
export -f assert_equals
export -f assert_contains
export -f assert_file_exists
export -f assert_directory_exists
export -f measure_time
export -f measure_memory
export -f count_docker_resources
export -f debug_function_call
export -f enable_debug_mode
export -f disable_debug_mode
export -f wait_for_container
export -f check_docker_health
export -f show_test_framework_info