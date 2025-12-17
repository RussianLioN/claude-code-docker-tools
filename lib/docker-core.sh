#!/bin/bash
# Docker Core Library
# Centralized Docker operations for AI Assistant containers

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Global variables
DOCKER_REGISTRY="${DOCKER_REGISTRY:-local}"
AI_VERSION="${AI_VERSION:-3.1.0}"
CONTAINER_PREFIX="ai-assistant"

# Logging functions
log_docker() {
    echo -e "${GREEN}[DOCKER]${NC} $1"
}

log_docker_error() {
    echo -e "${RED}[DOCKER-ERROR]${NC} $1" >&2
}

log_docker_warn() {
    echo -e "${YELLOW}[DOCKER-WARN]${NC} $1" >&2
}

# Generate unique container ID
generate_container_id() {
    local mode="$1"
    local timestamp=$(date +%s)
    local uuid4=$(python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || echo "unknown")
    echo "${CONTAINER_PREFIX}-${mode}-${timestamp}-${uuid4:0:8}"
}

# Build isolated container
build_isolated_container() {
    local mode="$1"
    local container_dir="containers/${mode}"
    
    log_docker "Building ${mode} isolated container..."
    
    if [[ ! -d "$container_dir" ]]; then
        log_docker_error "Container directory not found: $container_dir"
        return 1
    fi
    
    # Build container with version tag
    local image_name="${CONTAINER_PREFIX}-${mode}:${AI_VERSION}"
    
    if docker build -t "$image_name" "$container_dir"; then
        log_docker "Successfully built ${mode} container: $image_name"
        return 0
    else
        log_docker_error "Failed to build ${mode} container"
        return 1
    fi
}

# Run isolated container with full isolation
run_isolated_container() {
    local mode="$1"
    shift
    local args=("$@")
    
    local container_id=$(generate_container_id "$mode")
    local image_name="${CONTAINER_PREFIX}-${mode}:${AI_VERSION}"
    local config_file="config/active/${mode}.yml"
    
    log_docker "Starting ${mode} container: $container_id"
    
    # Check if image exists
    if ! docker image inspect "$image_name" &>/dev/null; then
        log_docker_error "Image not found: $image_name"
        log_docker "Building ${mode} container..."
        build_isolated_container "$mode" || return 1
    fi
    
    # Load configuration
    local memory_limit="512m"
    local cpu_limit="0.5"
    local pids_limit="100"
    
    if [[ -f "$config_file" ]]; then
        log_docker "Loading configuration from: $config_file"
        # Parse YAML (basic implementation)
        memory_limit=$(grep -A1 "memory_limit:" "$config_file" | tail -1 | sed 's/.*: *//' | tr -d '"')
        cpu_limit=$(grep -A1 "cpu_limit:" "$config_file" | tail -1 | sed 's/.*: *//' | tr -d '"')
        pids_limit=$(grep -A1 "pids_limit:" "$config_file" | tail -1 | sed 's/.*: *//' | tr -d '"')
    fi
    
    # Prepare isolation flags
    local isolation_flags=(
        --rm
        --name "$container_id"
        --memory="$memory_limit"
        --cpus="$cpu_limit"
        --pids-limit="$pids_limit"
        --read-only
        --tmpfs /tmp:noexec,nosuid,size=100m
        --tmpfs /var/tmp:noexec,nosuid,size=50m
        --cap-drop ALL
        --security-opt no-new-privileges:true
        --userns=private
        --cgroupns=private
    )
    
    # Prepare volume mounts
    local volume_mounts=(
        -v "$(pwd)/workspace/${mode}:/workspace/${mode}:rw"
        -v "$(pwd)/config/active/${mode}:/home/${mode}/.config:rw"
        -v "$(pwd)/backups/${mode}:/home/${mode}/.backups:rw"
    )
    
    # Prepare environment variables
    local env_vars=(
        -e AI_MODE="$mode"
        -e AI_VERSION="$AI_VERSION"
        -e CONTAINER_ID="$container_id"
        -e WORKSPACE_DIR="/workspace/${mode}"
    )
    
    # Add SSH agent if available
    if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
        volume_mounts+=(-v "$SSH_AUTH_SOCK:/ssh-agent")
        env_vars+=(-e SSH_AUTH_SOCK="/ssh-agent")
    fi
    
    log_docker "Container configuration:"
    log_docker "  Image: $image_name"
    log_docker "  Memory: $memory_limit"
    log_docker "  CPU: $cpu_limit"
    log_docker "  PIDs limit: $pids_limit"
    
    # Run container
    docker run "${isolation_flags[@]}" "${volume_mounts[@]}" "${env_vars[@]}" "$image_name" "${args[@]}"
}

# Stop container
stop_container() {
    local mode="$1"
    local pattern="${CONTAINER_PREFIX}-${mode}-*"
    
    log_docker "Stopping ${mode} containers..."
    
    local containers=$(docker ps --format "{{.Names}}" | grep "^${pattern}$" || true)
    
    if [[ -z "$containers" ]]; then
        log_docker_warn "No running ${mode} containers found"
        return 0
    fi
    
    echo "$containers" | while read -r container; do
        log_docker "Stopping container: $container"
        docker stop "$container" || log_docker_warn "Failed to stop: $container"
    done
}

# Clean containers
clean_containers() {
    local mode="${1:-all}"
    
    log_docker "Cleaning ${mode} containers..."
    
    if [[ "$mode" == "all" ]]; then
        # Remove all AI Assistant containers
        docker ps -a --format "{{.Names}}" | grep "^${CONTAINER_PREFIX}-" | while read -r container; do
            log_docker "Removing container: $container"
            docker rm -f "$container" || log_docker_warn "Failed to remove: $container"
        done
    else
        # Remove specific mode containers
        docker ps -a --format "{{.Names}}" | grep "^${CONTAINER_PREFIX}-${mode}-" | while read -r container; do
            log_docker "Removing container: $container"
            docker rm -f "$container" || log_docker_warn "Failed to remove: $container"
        done
    fi
}

# List containers
list_containers() {
    local mode="${1:-all}"
    
    log_docker "Listing ${mode} containers..."
    
    if [[ "$mode" == "all" ]]; then
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep "${CONTAINER_PREFIX}" || log_docker_warn "No containers found"
    else
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep "${CONTAINER_PREFIX}-${mode}" || log_docker_warn "No ${mode} containers found"
    fi
}

# Show container logs
show_logs() {
    local mode="$1"
    local pattern="${CONTAINER_PREFIX}-${mode}-*"
    
    local containers=$(docker ps --format "{{.Names}}" | grep "^${pattern}$" || true)
    
    if [[ -z "$containers" ]]; then
        log_docker_warn "No running ${mode} containers found"
        return 1
    fi
    
    echo "$containers" | head -1 | while read -r container; do
        log_docker "Showing logs for: $container"
        docker logs -f "$container"
    done
}

# Health check
health_check() {
    local mode="$1"
    local pattern="${CONTAINER_PREFIX}-${mode}-*"
    
    local containers=$(docker ps --format "{{.Names}}" | grep "^${pattern}$" || true)
    
    if [[ -z "$containers" ]]; then
        echo "unhealthy"
        return 1
    fi
    
    local healthy_count=0
    echo "$containers" | while read -r container; do
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
        if [[ "$health" == "healthy" ]]; then
            ((healthy_count++))
        fi
    done
    
    if [[ $healthy_count -gt 0 ]]; then
        echo "healthy"
        return 0
    else
        echo "unhealthy"
        return 1
    fi
}

# Export functions
export -f generate_container_id
export -f build_isolated_container
export -f run_isolated_container
export -f stop_container
export -f clean_containers
export -f list_containers
export -f show_logs
export -f health_check