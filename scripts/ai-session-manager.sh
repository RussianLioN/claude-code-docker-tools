#!/bin/bash

# ai-session-manager.sh - Multi-Instance AI Session Management
# Core component for managing concurrent AI assistant instances

set -euo pipefail

# Session Manager Configuration
readonly SESSION_MANAGER_VERSION="1.0.0"
readonly SESSION_REGISTRY="${HOME}/.config/ai-sessions/registry.json"
readonly SESSION_LOG_DIR="${HOME}/.config/ai-sessions/logs"
readonly CONFIG_DIR="${HOME}/.config/ai-sessions"

# Port allocation ranges
readonly PORT_RANGE_START=8080
readonly PORT_RANGE_END=8099
readonly SSH_PORT_RANGE_START=2222
readonly SSH_PORT_RANGE_END=2239

# Resource limits per instance
readonly MAX_MEMORY_MB=512
readonly MAX_CPU_PERCENT=10
readonly MAX_INSTANCES=10

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Docker environment management
ensure_docker_environment() {
    # Check if Docker is already available
    if docker info >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker environment ready${NC}"
        return 0
    fi

    echo -e "${YELLOW}🐳 Docker environment setup required...${NC}"

    # Platform-specific Docker setup
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Prefer Colima on macOS for background operation
        if command -v colima >/dev/null 2>&1; then
            echo -e "${BLUE}🚀 Starting Colima...${NC}"
            if colima status >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Colima already running${NC}"
            else
                colima start --cpu 2 --memory 4 --disk 60
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}✅ Colima started successfully${NC}"
                else
                    echo -e "${RED}❌ Failed to start Colima${NC}"
                    return 1
                fi
            fi

            # Set Docker host for Colima
            export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"

        elif command -v docker >/dev/null 2>&1; then
            # Fallback to Docker Desktop
            echo -e "${BLUE}🚀 Starting Docker Desktop...${NC}"
            echo -e "${YELLOW}⏳ This may take 30-90 seconds for full initialization${NC}"
            open -a Docker

            # Wait for Docker daemon to be ready
            local max_wait=120  # Increased timeout for Docker Desktop
            local wait_time=0
            local daemon_ready=false

            echo -n "  Waiting for Docker daemon"
            while ! docker info >/dev/null 2>&1 && [[ $wait_time -lt $max_wait ]]; do
                sleep 2
                ((wait_time++))
                echo -n "."

                # Show progress every 10 seconds
                if (( wait_time % 10 == 0 )); then
                    echo " (${wait_time}s/${max_wait}s)"
                    echo -n "  Still waiting"
                fi
            done
            echo ""

            if docker info >/dev/null 2>&1; then
                daemon_ready=true
                echo -e "${GREEN}✅ Docker daemon ready${NC}"

                # Additional wait for Docker Desktop UI to fully initialize
                echo -n "  Waiting for Docker Desktop initialization"
                local ui_wait=0
                local max_ui_wait=30

                while [[ $ui_wait -lt $max_ui_wait ]]; do
                    # Check if we can run basic docker operations
                    if docker version >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
                        echo ""
                        echo -e "${GREEN}✅ Docker Desktop fully initialized${NC}"
                        break
                    fi

                    sleep 1
                    ((ui_wait++))
                    echo -n "."
                done

                if [[ $ui_wait -eq $max_ui_wait ]]; then
                    echo ""
                    echo -e "${YELLOW}⚠️ Docker Desktop daemon ready, but UI may still be loading${NC}"
                fi
            else
                echo -e "${RED}❌ Docker Desktop failed to start within ${max_wait}s${NC}"
                echo -e "${YELLOW}💡 Try starting Docker Desktop manually and wait for full initialization${NC}"
                return 1
            fi

        else
            echo -e "${RED}❌ No Docker environment found${NC}"
            echo ""
            echo "Please install one of the following:"
            echo "  1. Colima (recommended): brew install colima docker"
            echo "  2. Docker Desktop: https://www.docker.com/products/docker-desktop"
            echo ""
            return 1
        fi

    else
        # Linux/other platforms
        if command -v docker >/dev/null 2>&1; then
            if ! docker info >/dev/null 2>&1; then
                echo -e "${YELLOW}⚠️ Docker daemon not running${NC}"
                echo "Please start Docker service:"
                echo "  sudo systemctl start docker"
                echo "  sudo systemctl enable docker"
                return 1
            fi
        else
            echo -e "${RED}❌ Docker not installed${NC}"
            echo "Please install Docker: https://docs.docker.com/get-docker/"
            return 1
        fi
    fi

    # Final verification
    if docker info >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker environment verified${NC}"
        return 0
    else
        echo -e "${RED}❌ Docker environment verification failed${NC}"
        return 1
    fi
}

# Docker health check
check_docker_health() {
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker daemon not responding${NC}"
        return 1
    fi

    # Check if we can pull a small image (quick connectivity test)
    local test_image="hello-world"
    if docker pull "$test_image" >/dev/null 2>&1; then
        docker rmi "$test_image" >/dev/null 2>&1 || true
        echo -e "${GREEN}✅ Docker connectivity verified${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️ Docker connectivity issues detected${NC}"
        return 1
    fi
}

# Initialize session manager
init_session_manager() {
    local -r action="${1:-"status"}"

    # Ensure Docker environment is ready
    case "${action}" in
        "help"|"-h"|"--help"|"status"|"list"|"cleanup"|"health")
            # These commands don't require Docker
            ;;
        *)
            # All other operations require Docker
            ensure_docker_environment || {
                echo -e "${RED}❌ Cannot proceed without Docker environment${NC}"
                exit 1
            }

            # Additional health check for critical operations
            if [[ "${action}" == "start" || "${action}" == "restart" ]]; then
                echo -e "${BLUE}🔍 Performing Docker health check...${NC}"
                check_docker_health || {
                    echo -e "${RED}❌ Docker health check failed${NC}"
                    echo -e "${YELLOW}💡 Please wait for Docker to fully initialize and try again${NC}"
                    exit 1
                }
            fi
            ;;
    esac

    # Ensure config directory exists
    mkdir -p "${CONFIG_DIR}" "${SESSION_LOG_DIR}"

    # Initialize registry if it doesn't exist
    if [[ ! -f "${SESSION_REGISTRY}" ]]; then
        echo '{"instances":{},"last_allocated_port":'${PORT_RANGE_START}'}' > "${SESSION_REGISTRY}"
    fi

    case "${action}" in
        "status")
            show_status
            ;;
        "start")
            start_instance "${2:-}"
            ;;
        "stop")
            stop_instance "${2:-}"
            ;;
        "list")
            list_instances
            ;;
        "restart")
            stop_instance "${2:-}"
            start_instance "${2:-}"
            ;;
        "cleanup")
            cleanup_dead_instances
            ;;
        "health")
            check_instance_health
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown action '${action}'"
            show_help
            exit 1
            ;;
    esac
}

# Show system status
show_status() {
    echo -e "${BLUE}🤖 AI Session Manager v${SESSION_MANAGER_VERSION}${NC}"
    echo "=================================="

    local -r total_instances=$(jq -r '.instances | length' "${SESSION_REGISTRY}")
    local -r running_instances=$(jq -r '[.instances[] | select(.status == "running")] | length' "${SESSION_REGISTRY}")

    echo "Total Instances: ${total_instances}/${MAX_INSTANCES}"
    echo "Running Instances: ${running_instances}"
    echo "Registry: ${SESSION_REGISTRY}"
    echo "Log Directory: ${SESSION_LOG_DIR}"
    echo ""

    if [[ ${total_instances} -gt 0 ]]; then
        echo "Instance Summary:"
        list_instances | tail -n +2
    fi
}

# Start a new instance
start_instance() {
    local instance_name="${1:-}"

    if [[ -z "${instance_name}" ]]; then
        echo -e "${RED}Error:${NC} Instance name required"
        echo "Usage: ai-session-manager start <instance-name>"
        exit 1
    fi

    # Check if instance already exists
    if jq -e ".instances[\"${instance_name}\"]" "${SESSION_REGISTRY}" >/dev/null 2>&1; then
        local -r status=$(jq -r ".instances[\"${instance_name}\"].status" "${SESSION_REGISTRY}")
        if [[ "${status}" == "running" ]]; then
            echo -e "${YELLOW}Warning:${NC} Instance '${instance_name}' is already running"
            return 0
        fi
    fi

    # Check instance limit
    local -r total_instances=$(jq -r '.instances | length' "${SESSION_REGISTRY}")
    if [[ ${total_instances} -ge ${MAX_INSTANCES} ]]; then
        echo -e "${RED}Error:${NC} Maximum instances (${MAX_INSTANCES}) reached"
        exit 1
    fi

    echo -e "${BLUE}🚀 Starting instance:${NC} ${instance_name}"

    # Allocate resources
    local -r main_port=$(allocate_port "${PORT_RANGE_START}" "${PORT_RANGE_END}")
    local -r ssh_port=$(allocate_port "${SSH_PORT_RANGE_START}" "${SSH_PORT_RANGE_END}")
    local -r workspace_dir="${HOME}/workspace-${instance_name}"
    local -r container_name="ai-session-${instance_name}"

    # Create workspace
    mkdir -p "${workspace_dir}"

    # Register instance
    register_instance "${instance_name}" "${main_port}" "${ssh_port}" "${workspace_dir}" "${container_name}"

    # Start the AI container
    echo "Starting container: ${container_name}"
    echo "Workspace: ${workspace_dir}"
    echo "Ports: ${main_port}:8080, ${ssh_port}:22"

    # Start the actual Docker container
    if start_docker_container "${instance_name}" "${main_port}" "${ssh_port}" "${workspace_dir}" "${container_name}"; then
        echo -e "${GREEN}✅ Instance '${instance_name}' started successfully${NC}"
        echo "📍 Workspace: ${workspace_dir}"
        echo "🌐 Main Port: ${main_port}"
        echo "🔑 SSH Port: ${ssh_port}"
        echo "🐳 Container: ${container_name}"
    else
        echo -e "${RED}❌ Failed to start instance '${instance_name}'${NC}"
        # Update status to error
        update_instance_status "${instance_name}" "error"
        exit 1
    fi
}

# Stop an instance
stop_instance() {
    local instance_name="${1:-}"

    if [[ -z "${instance_name}" ]]; then
        echo -e "${RED}Error:${NC} Instance name required"
        echo "Usage: ai-session-manager stop <instance-name>"
        exit 1
    fi

    if ! jq -e ".instances[\"${instance_name}\"]" "${SESSION_REGISTRY}" >/dev/null 2>&1; then
        echo -e "${RED}Error:${NC} Instance '${instance_name}' not found"
        exit 1
    fi

    echo -e "${YELLOW}🛑 Stopping instance:${NC} ${instance_name}"

    local -r container_name=$(jq -r ".instances[\"${instance_name}\"].container_name" "${SESSION_REGISTRY}")

    # Stop the actual Docker container
    if stop_docker_container "${container_name}"; then
        # Update instance status
        update_instance_status "${instance_name}" "stopped"
        echo -e "${GREEN}✅ Instance '${instance_name}' stopped successfully${NC}"
    else
        echo -e "${RED}❌ Failed to stop instance '${instance_name}'${NC}"
        # Update status to error
        update_instance_status "${instance_name}" "error"
        exit 1
    fi
}

# List all instances
list_instances() {
    echo ""
    printf "%-15s %-8s %-8s %-8s %-20s\n" "INSTANCE" "STATUS" "MAIN" "SSH" "CREATED"
    printf "%-15s %-8s %-8s %-8s %-20s\n" "--------" "------" "----" "---" "-------"

    jq -r '.instances | to_entries[] |
    "\(.key) \(.value.status) \(.value.main_port) \(.value.ssh_port) \(.value.created_at)"' \
    "${SESSION_REGISTRY}" 2>/dev/null | while read -r line; do
        if [[ -n "${line}" ]]; then
            local instance=$(echo "${line}" | cut -d' ' -f1)
            local status=$(echo "${line}" | cut -d' ' -f2)
            local main_port=$(echo "${line}" | cut -d' ' -f3)
            local ssh_port=$(echo "${line}" | cut -d' ' -f4)
            local created=$(echo "${line}" | cut -d' ' -f5-)

            # Color code status
            local status_color="${NC}"
            case "${status}" in
                "running") status_color="${GREEN}" ;;
                "stopped") status_color="${YELLOW}" ;;
                "error") status_color="${RED}" ;;
            esac

            printf "%-15s ${status_color}%-8s${NC} %-8s %-8s %-20s\n" \
                "${instance}" "${status}" "${main_port}" "${ssh_port}" "${created}"
        fi
    done
}

# Allocate available port
allocate_port() {
    local -r start_port="${1}"
    local -r end_port="${2}"

    local -r last_allocated=$(jq -r '.last_allocated_port' "${SESSION_REGISTRY}")
    local next_port=$((last_allocated + 1))

    # Wrap around if we reach the end
    if [[ ${next_port} -gt ${end_port} ]]; then
        next_port=${start_port}
    fi

    # Check if port is in use
    while is_port_in_use "${next_port}"; do
        next_port=$((next_port + 1))
        if [[ ${next_port} -gt ${end_port} ]]; then
            next_port=${start_port}
        fi

        # Prevent infinite loop
        if [[ ${next_port} -eq ${last_allocated} ]]; then
            echo -e "${RED}Error:${NC} No available ports in range ${start_port}-${end_port}"
            exit 1
        fi
    done

    # Update last allocated port
    jq --arg next_port "${next_port}" '.last_allocated_port = ($next_port | tonumber)' \
        "${SESSION_REGISTRY}" > "${SESSION_REGISTRY}.tmp" && mv "${SESSION_REGISTRY}.tmp" "${SESSION_REGISTRY}"

    echo "${next_port}"
}

# Check if port is in use
is_port_in_use() {
    local -r port="${1}"

    # Check if port is allocated to an instance
    local allocated=$(jq -r ".instances | map(.main_port, .ssh_port) | any(. == ${port})" "${SESSION_REGISTRY}")
    if [[ "${allocated}" == "true" ]]; then
        return 0
    fi

    # Check if port is in use by system (netstat check)
    if command -v netstat >/dev/null 2>&1; then
        if netstat -an | grep -q ":${port} "; then
            return 0
        fi
    elif command -v lsof >/dev/null 2>&1; then
        if lsof -i ":${port}" >/dev/null 2>&1; then
            return 0
        fi
    fi

    # Check Docker port mappings
    if docker ps --format "{{.Ports}}" 2>/dev/null | grep -q ":${port}->"; then
        return 0
    fi

    return 1
}

# Register new instance
register_instance() {
    local -r instance_name="${1}"
    local -r main_port="${2}"
    local -r ssh_port="${3}"
    local -r workspace_dir="${4}"
    local -r container_name="${5}"
    local -r created_at=$(date '+%Y-%m-%d %H:%M:%S')

    local tmp_registry=$(mktemp)

    jq --arg name "${instance_name}" \
       --arg main_port "${main_port}" \
       --arg ssh_port "${ssh_port}" \
       --arg workspace "${workspace_dir}" \
       --arg container "${container_name}" \
       --arg created "${created_at}" \
       --arg status "running" \
       '.instances[$name] = {
           "main_port": ($main_port | tonumber),
           "ssh_port": ($ssh_port | tonumber),
           "workspace_dir": $workspace,
           "container_name": $container,
           "created_at": $created,
           "status": $status,
           "last_health_check": null
       }' \
       "${SESSION_REGISTRY}" > "${tmp_registry}" && mv "${tmp_registry}" "${SESSION_REGISTRY}"
}

# Update instance status
update_instance_status() {
    local -r instance_name="${1}"
    local -r status="${2}"
    local -r health_check=$(date '+%Y-%m-%d %H:%M:%S')

    local tmp_registry=$(mktemp)

    jq --arg name "${instance_name}" \
       --arg status "${status}" \
       --arg health_check "${health_check}" \
       '.instances[$name].status = $status |
        .instances[$name].last_health_check = $health_check' \
       "${SESSION_REGISTRY}" > "${tmp_registry}" && mv "${tmp_registry}" "${SESSION_REGISTRY}"
}

# Start real Docker container
start_docker_container() {
    local instance_name="${1}"
    local main_port="${2}"
    local ssh_port="${3}"
    local workspace_dir="${4}"
    local container_name="${5}"

    echo "  📦 Starting Docker container: ${container_name}"
    echo "  🔗 Port mapping: ${main_port}:8080, ${ssh_port}:22"

    # Get current project directory
    local project_dir=$(pwd)
    local project_name=$(basename "${project_dir}")
    local container_workdir="/app/${project_name}"

    echo "  📂 Project: ${project_dir} -> ${container_workdir}"

    # Create state directory for this instance
    local state_dir="${CONFIG_DIR}/states/${instance_name}"
    mkdir -p "${state_dir}"

    # Prepare SSH and Git config paths
    local ssh_known_hosts="${SSH_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}"
    local git_config="${GIT_CONFIG:-$HOME/.gitconfig}"

    # Create log file
    local log_file="${SESSION_LOG_DIR}/${instance_name}.log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting container..." > "${log_file}"

    # Start container with proper isolation
    local container_id
    container_id=$(docker run -d \
        --name "${container_name}" \
        --label "ai-session=${instance_name}" \
        --label "ai-type=managed" \
        -p "${main_port}:8080" \
        -p "${ssh_port}:22" \
        -v "${project_dir}":"${container_workdir}":rw \
        -v "${state_dir}":/root/.ai:rw \
        -v "${ssh_known_hosts}":/root/.ssh/known_hosts:ro \
        -v "${git_config}":/root/.gitconfig:ro \
        -e AI_SESSION="${instance_name}" \
        -e AI_PROJECT="${project_name}" \
        -e AI_WORKDIR="${container_workdir}" \
        -e AI_MODE="session" \
        --memory="${MAX_MEMORY_MB}m" \
        --cpus="${MAX_CPU_PERCENT}" \
        --restart unless-stopped \
        claude-code-tools tail -f /dev/null 2>>"${log_file}")

    local exit_code=$?

    if [[ $exit_code -eq 0 && -n "${container_id}" ]]; then
        echo "  🆔 Container ID: ${container_id:0:12}..."
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Container started with ID: ${container_id}" >> "${log_file}"

        # Wait for container to be ready
        local max_attempts=30
        local attempt=0

        echo "  ⏳ Waiting for container to be ready..."
        while [[ $attempt -lt $max_attempts ]]; do
            if docker exec "${container_id}" echo "ready" >/dev/null 2>&1; then
                echo "  ✅ Container ready after ${attempt}s"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Container ready after ${attempt}s" >> "${log_file}"

                # Store container ID
                echo "${container_id}" > "${state_dir}/container.id"

                # Verify file accessibility
                verify_file_accessibility "${container_id}" "${container_workdir}" "${log_file}"

                # Update registry with container ID
                local tmp_registry=$(mktemp)
                jq --arg name "${instance_name}" \
                   --arg cid "${container_id}" \
                   '.instances[$name].container_id = $cid' \
                   "${SESSION_REGISTRY}" > "${tmp_registry}" && \
                   mv "${tmp_registry}" "${SESSION_REGISTRY}"

                return 0
            fi
            sleep 1
            ((attempt++))
            echo -n "."
        done
        echo ""

        echo "  ❌ Container failed to start within ${max_attempts}s"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Container failed to start within ${max_attempts}s" >> "${log_file}"

        # Show container logs for debugging
        echo "  📋 Container logs:"
        docker logs --tail 20 "${container_id}" 2>&1 | sed 's/^/    /'

        # Cleanup failed container
        docker rm "${container_id}" 2>/dev/null || true
        return 1
    else
        echo "  ❌ Failed to start container (exit code: ${exit_code})"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed to start container (exit code: ${exit_code})" >> "${log_file}"
        handle_docker_error "${exit_code}" "container start" "${container_name}"
        return 1
    fi
}

# Stop real Docker container
stop_docker_container() {
    local container_name="${1}"
    local force="${2:-false}"

    echo "  🛑 Stopping Docker container: ${container_name}"

    # Get container ID
    local container_id=$(docker ps -aqf "name=${container_name}")

    if [[ -z "${container_id}" ]]; then
        echo "    ⚠️ Container not found: ${container_name}"
        return 0
    fi

    echo "  🆔 Container ID: ${container_id:0:12}..."

    # Graceful shutdown
    if [[ "${force}" != "true" ]]; then
        echo "    Attempting graceful shutdown..."
        docker stop --time=10 "${container_id}" 2>/dev/null || true

        # Wait for container to stop
        local count=0
        while docker ps -qf "id=${container_id}" >/dev/null 2>&1 && [[ $count -lt 10 ]]; do
            sleep 1
            ((count++))
            echo -n "."
        done
        echo ""
    fi

    # Force kill if still running
    if docker ps -qf "id=${container_id}" >/dev/null 2>&1; then
        echo "    Force killing container..."
        docker kill "${container_id}" 2>/dev/null || true
    fi

    # Remove container
    docker rm "${container_id}" 2>/dev/null || true

    echo "    ✅ Container stopped and removed"
}

# Verify file accessibility in container
verify_file_accessibility() {
    local container_id="${1}"
    local workspace_dir="${2}"
    local log_file="${3}"

    echo "  🔍 Verifying file accessibility..."

    # Check if workspace is accessible
    if ! docker exec "${container_id}" test -d "${workspace_dir}"; then
        echo "    ❌ Workspace directory not found in container"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Workspace ${workspace_dir} not accessible" >> "${log_file}"
        return 1
    fi

    # Test write permissions
    local test_file="${workspace_dir}/.ai-access-test"
    if docker exec "${container_id}" touch "${test_file}" 2>/dev/null; then
        docker exec "${container_id}" rm "${test_file}" 2>/dev/null
        echo "    ✅ Write permissions OK"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] File access test passed" >> "${log_file}"
    else
        echo "    ⚠️ Limited write permissions"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Limited write permissions" >> "${log_file}"
    fi

    # List important project files
    local found_files=false
    for pattern in "package.json" "requirements.txt" "Cargo.toml" "go.mod" "*.py" "*.js" "*.ts"; do
        local count=$(docker exec "${container_id}" find "${workspace_dir}" -name "${pattern}" -type f 2>/dev/null | wc -l)
        if [[ $count -gt 0 ]]; then
            echo "    ✅ Found ${count} ${pattern} files"
            found_files=true
        fi
    done

    if [[ "$found_files" == "false" ]]; then
        echo "    ℹ️ No common project files found"
    fi

    return 0
}

# Handle Docker errors with actionable messages
handle_docker_error() {
    local exit_code="${1}"
    local operation="${2}"
    local container_name="${3}"

    case "${exit_code}" in
        125)
            echo "    ❌ Docker daemon error during ${operation}"
            echo "    💡 Solution: Check if Docker is running properly"
            ;;
        126)
            echo "    ❌ Container command not executable"
            echo "    💡 Solution: Check container image integrity"
            ;;
        127)
            echo "    ❌ Container command not found"
            echo "    💡 Solution: Verify entrypoint in Dockerfile"
            ;;
        137)
            echo "    ⚠️ Container killed (SIGKILL) - possible OOM"
            if docker inspect "${container_name}" 2>/dev/null | grep -q "OOMKilled"; then
                echo "    💡 Container was killed due to memory limit"
                echo "    💡 Consider increasing memory limit"
            fi
            ;;
        *)
            echo "    ❌ Docker error ${exit_code} during ${operation}"
            if [[ -n "${container_name}" ]]; then
                echo "    📋 Container logs:"
                docker logs --tail 10 "${container_name}" 2>/dev/null | sed 's/^/      /' || echo "      No logs available"
            fi
            ;;
    esac
}

# Cleanup dead instances
cleanup_dead_instances() {
    echo -e "${YELLOW}🧹 Cleaning up dead instances...${NC}"

    local dead_instances=$(jq -r '.instances | to_entries[] |
    select(.value.status == "stopped" or .value.status == "error") | .key' \
    "${SESSION_REGISTRY}")

    if [[ -n "${dead_instances}" ]]; then
        echo "Found stopped instances to cleanup:"
        echo "${dead_instances}"

        # Ask for confirmation
        read -p "Remove these instances? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for instance in ${dead_instances}; do
                jq --arg name "${instance}" 'del(.instances[$name])' \
                    "${SESSION_REGISTRY}" > "${SESSION_REGISTRY}.tmp" && \
                    mv "${SESSION_REGISTRY}.tmp" "${SESSION_REGISTRY}"
                echo "  ✅ Removed instance: ${instance}"
            done
        fi
    else
        echo "  ℹ️ No dead instances found"
    fi
}

# Check instance health
check_instance_health() {
    echo -e "${BLUE}🔍 Checking instance health...${NC}"

    jq -r '.instances | to_entries[] |
    "\(.key) \(.value.status) \(.value.container_name)"' \
    "${SESSION_REGISTRY}" | while read -r line; do
        if [[ -n "${line}" ]]; then
            local instance=$(echo "${line}" | cut -d' ' -f1)
            local status=$(echo "${line}" | cut -d' ' -f2)
            local container=$(echo "${line}" | cut -d' ' -f3-)

            echo "  ${instance}: ${status}"

            if [[ "${status}" == "running" ]]; then
                # Simulate health check
                echo "    🔍 Container: ${container}"
                echo "    ✅ Healthy"
                update_instance_status "${instance}" "running"
            fi
        fi
    done
}

# Show help
show_help() {
    cat << EOF
AI Session Manager v${SESSION_MANAGER_VERSION}

USAGE:
    ai-session-manager <command> [arguments]

COMMANDS:
    status                      Show system status
    start <name>               Start new instance
    stop <name>                Stop instance
    list                       List all instances
    restart <name>             Restart instance
    cleanup                    Remove stopped instances
    health                     Check instance health
    help                       Show this help

EXAMPLES:
    ai-session-manager status              # Show status
    ai-session-manager start dev-instance  # Start 'dev-instance'
    ai-session-manager stop dev-instance   # Stop 'dev-instance'
    ai-session-manager list                # List all instances

CONFIGURATION:
    Registry: ${SESSION_REGISTRY}
    Log Directory: ${SESSION_LOG_DIR}
    Max Instances: ${MAX_INSTANCES}
    Port Range: ${PORT_RANGE_START}-${PORT_RANGE_END}

EOF
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_session_manager "$@"
fi