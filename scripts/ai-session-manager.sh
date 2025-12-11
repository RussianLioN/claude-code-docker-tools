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

# Initialize session manager
init_session_manager() {
    local -r action="${1:-"status"}"

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

    # This would integrate with the actual container startup logic
    # For now, we'll simulate the startup
    simulate_container_start "${instance_name}" "${main_port}" "${ssh_port}" "${workspace_dir}" "${container_name}"

    echo -e "${GREEN}✅ Instance '${instance_name}' started successfully${NC}"
    echo "📍 Workspace: ${workspace_dir}"
    echo "🌐 Main Port: ${main_port}"
    echo "🔑 SSH Port: ${ssh_port}"
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

    # This would integrate with actual container stop logic
    simulate_container_stop "${container_name}"

    # Update instance status
    update_instance_status "${instance_name}" "stopped"

    echo -e "${GREEN}✅ Instance '${instance_name}' stopped successfully${NC}"
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

# Simulate container startup (placeholder)
simulate_container_start() {
    local instance_name="${1}"
    local main_port="${2}"
    local ssh_port="${3}"
    local workspace_dir="${4}"
    local container_name="${5}"

    echo "  📦 Starting Docker container: ${container_name}"
    echo "  🔗 Port mapping: ${main_port}:8080, ${ssh_port}:22"
    echo "  📂 Workspace: ${workspace_dir}"

    # Create log file
    local log_file="${SESSION_LOG_DIR}/${instance_name}.log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Container started" > "${log_file}"

    # Simulate startup delay
    sleep 1

    echo "  ✅ Container started successfully"
}

# Simulate container stop (placeholder)
simulate_container_stop() {
    local container_name="${1}"

    echo "  🛑 Stopping Docker container: ${container_name}"

    # Simulate stop delay
    sleep 0.5

    echo "  ✅ Container stopped"
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