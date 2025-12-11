# SESSION_MANAGEMENT_ARCHITECTURE.md

> **🔄 Multi-Instance Session Management Architecture**
> *Comprehensive design for managing multiple concurrent AI assistant instances*

**📍 Navigation**: [← Back to CLAUDE.md](./CLAUDE.md)

## 📑 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Components](#core-components)
3. [Data Structures](#data-structures)
4. [Implementation Details](#implementation-details)
5. [API Specification](#api-specification)
6. [Integration Guide](#integration-guide)
7. [Deployment Strategy](#deployment-strategy)
8. [Monitoring & Observability](#monitoring--observability)

---

## Architecture Overview

### 🎯 Problem Statement

**Current Limitations**:
- Single instance per host
- Manual port management
- No resource isolation
- Difficult to track running instances
- No centralized control

**Target Capabilities**:
- ✅ Run N+ concurrent AI instances
- ✅ Dynamic port allocation
- ✅ Resource monitoring & limits
- ✅ Instance lifecycle management
- ✅ Health checks & auto-recovery

### 🏗️ High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Session Manager                        │
│  ┌───────────────────────────────────────────────────┐  │
│  │              ai-session-manager.sh               │  │
│  │  ┌─────────────┬─────────────┬─────────────────┐ │  │
│  │  │   Instance  │   Resource  │    Health       │ │  │
│  │  │  Registry   │  Monitor    │   Checker       │ │  │
│  │  └─────────────┴─────────────┴─────────────────┘ │  │
│  │  ┌─────────────┬─────────────┬─────────────────┐ │  │
│  │  │   Port      │   Config    │    Event        │ │  │
│  │  │  Allocator  │  Manager    │   Logger        │ │  │
│  │  └─────────────┴─────────────┴─────────────────┘ │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┼─────────────┐
                ▼             ▼             ▼
    ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
    │   Instance #1   │ │   Instance #2   │ │   Instance #N   │
    │  Project A +    │ │  Project B +    │ │  Project C +    │
    │   Claude CLI    │ │   Gemini CLI    │ │   Gemini CLI    │
    └─────────────────┘ └─────────────────┘ └─────────────────┘
```

---

## Core Components

### 1. Session Manager Controller

**File**: `ai-session-manager.sh`

```bash
#!/bin/bash
# AI Session Manager - Core controller for multi-instance management

set -euo pipefail

# Configuration
SESSION_DIR="${HOME}/.ai-sessions"
REGISTRY_FILE="${SESSION_DIR}/registry.json"
LOG_DIR="${SESSION_DIR}/logs"
SOCKET_DIR="${SESSION_DIR}/sockets"
BASE_PORT=9000
MAX_PORT=9999

# Ensure directories exist
mkdir -p "$SESSION_DIR" "$LOG_DIR" "$SOCKET_DIR"

# Load registry
load_registry() {
  if [[ -f "$REGISTRY_FILE" ]]; then
    cat "$REGISTRY_FILE" | jq -r '.instances // {}'
  else
    echo "{}"
  fi
}

# Save registry
save_registry() {
  local data="$1"
  echo "{\"instances\":$data}" > "$REGISTRY_FILE"
}
```

### 2. Instance Registry

**Purpose**: Central state management for all AI instances

**Data Structure**:
```json
{
  "instances": {
    "project-a-claude": {
      "id": "project-a-claude",
      "project_path": "/Users/dev/project-a",
      "project_name": "project-a",
      "mode": "claude",
      "status": "running",
      "pid": 12345,
      "container_id": "abc123def456",
      "port": 9001,
      "socket_path": "/Users/dev/.ai-sessions/sockets/project-a-claude.sock",
      "resources": {
        "memory_limit": "1Gi",
        "cpu_limit": "500m",
        "memory_usage": "512Mi",
        "cpu_usage": "15%"
      },
      "timestamps": {
        "created": "2025-12-11T10:30:00Z",
        "started": "2025-12-11T10:30:05Z",
        "last_health_check": "2025-12-11T10:35:00Z"
      },
      "config": {
        "model": "claude-3-5-sonnet-20241022",
        "max_tokens": 4096,
        "temperature": 0.7
      }
    }
  }
}
```

### 3. Port Allocator

```bash
# Port management with conflict resolution
allocate_port() {
  local preferred_port=${1:-}
  local port

  # Try preferred port first
  if [[ -n "$preferred_port" ]] && is_port_available "$preferred_port"; then
    echo "$preferred_port"
    return 0
  fi

  # Dynamic allocation
  for ((port=BASE_PORT; port<=MAX_PORT; port++)); do
    if is_port_available "$port"; then
      echo "$port"
      return 0
    fi
  done

  echo "ERROR: No available ports in range $BASE_PORT-$MAX_PORT" >&2
  return 1
}

is_port_available() {
  local port=$1

  # Check if port is in use
  if lsof -i ":$port" >/dev/null 2>&1; then
    return 1
  fi

  # Check if port is allocated in registry
  local registry=$(load_registry)
  if echo "$registry" | jq -e ".[] | select(.port == $port)" >/dev/null; then
    return 1
  fi

  return 0
}
```

### 4. Resource Monitor

```bash
# Resource monitoring with thresholds
monitor_resources() {
  local registry=$(load_registry)
  local alerts=()

  while IFS= read -r instance; do
    local instance_id=$(echo "$instance" | jq -r '.id')
    local container_id=$(echo "$instance" | jq -r '.container_id')

    if [[ "$container_id" != "null" ]]; then
      local stats=$(docker stats --no-stream --format \
        "{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" "$container_id" 2>/dev/null || echo "")

      if [[ -n "$stats" ]]; then
        local cpu_percent=$(echo "$stats" | cut -f1 | sed 's/%//')
        local mem_usage=$(echo "$stats" | cut -f2)
        local mem_percent=$(echo "$stats" | cut -f3 | sed 's/%//')

        # Check thresholds
        if (( $(echo "$cpu_percent > 80" | bc -l) )); then
          alerts+=("HIGH_CPU:$instance_id:$cpu_percent")
        fi

        if (( $(echo "$mem_percent > 85" | bc -l) )); then
          alerts+=("HIGH_MEM:$instance_id:$mem_percent")
        fi

        # Update registry with current stats
        update_instance_resources "$instance_id" "$cpu_percent" "$mem_usage"
      fi
    fi
  done <<< "$(echo "$registry" | jq -c '.[]')"

  # Process alerts
  for alert in "${alerts[@]}"; do
    process_alert "$alert"
  done
}

update_instance_resources() {
  local instance_id=$1
  local cpu=$2
  local mem=$3

  local registry=$(load_registry)
  local updated=$(echo "$registry" | jq \
    --arg id "$instance_id" \
    --arg cpu "$cpu" \
    --arg mem "$mem" \
    '.[$id].resources.cpu_usage = $cpu | .[$id].resources.memory_usage = $mem')

  save_registry "$updated"
}
```

### 5. Health Checker

```bash
# Health monitoring with auto-recovery
health_checker() {
  local registry=$(load_registry)
  local unhealthy_instances=()

  while IFS= read -r instance; do
    local instance_id=$(echo "$instance" | jq -r '.id')
    local port=$(echo "$instance" | jq -r '.port')
    local socket=$(echo "$instance" | jq -r '.socket_path')

    local healthy=true

    # Check 1: Container running
    if ! docker inspect --format='{{.State.Running}}' "$(echo "$instance" | jq -r '.container_id')" 2>/dev/null | grep -q "true"; then
      healthy=false
    fi

    # Check 2: Port responsive
    if ! nc -z localhost "$port" 2>/dev/null; then
      healthy=false
    fi

    # Check 3: Socket accessible
    if [[ -S "$socket" ]] && ! nc -U -z "$socket" 2>/dev/null; then
      healthy=false
    fi

    # Update health status
    update_instance_health "$instance_id" $healthy

    if [[ "$healthy" == "false" ]]; then
      unhealthy_instances+=("$instance_id")
    fi

  done <<< "$(echo "$registry" | jq -c '.[]')"

  # Auto-recovery for unhealthy instances
  for instance_id in "${unhealthy_instances[@]}"; do
    attempt_recovery "$instance_id"
  done
}

attempt_recovery() {
  local instance_id=$1
  local registry=$(load_registry)
  local instance_info=$(echo "$registry" | jq -r ".[\"$instance_id\"]")

  local project=$(echo "$instance_info" | jq -r '.project_name')
  local mode=$(echo "$instance_info" | jq -r '.mode')

  echo "⚠️ Instance $instance_id is unhealthy, attempting recovery..."

  # Stop current instance
  stop_instance "$instance_id" true

  # Wait before restart
  sleep 5

  # Restart instance
  if start_instance "$project" "$mode" "$instance_id"; then
    echo "✅ Successfully recovered $instance_id"
  else
    echo "❌ Failed to recover $instance_id"
    # Send notification
    send_alert "RECOVERY_FAILED:$instance_id"
  fi
}
```

---

## Data Structures

### Instance Registry Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "instances": {
      "type": "object",
      "patternProperties": {
        "^[a-zA-Z0-9_-]+-[a-zA-Z]+$": {
          "type": "object",
          "properties": {
            "id": {"type": "string"},
            "project_path": {"type": "string"},
            "project_name": {"type": "string"},
            "mode": {"enum": ["claude", "gemini"]},
            "status": {"enum": ["initializing", "running", "paused", "stopped", "error"]},
            "pid": {"type": "integer"},
            "container_id": {"type": "string"},
            "port": {"type": "integer", "minimum": 1024, "maximum": 65535},
            "socket_path": {"type": "string"},
            "resources": {
              "type": "object",
              "properties": {
                "memory_limit": {"type": "string"},
                "cpu_limit": {"type": "string"},
                "memory_usage": {"type": "string"},
                "cpu_usage": {"type": "string"}
              }
            },
            "timestamps": {
              "type": "object",
              "properties": {
                "created": {"type": "string", "format": "date-time"},
                "started": {"type": "string", "format": "date-time"},
                "last_health_check": {"type": "string", "format": "date-time"}
              }
            },
            "config": {
              "type": "object",
              "properties": {
                "model": {"type": "string"},
                "max_tokens": {"type": "integer"},
                "temperature": {"type": "number", "minimum": 0, "maximum": 2}
              }
            }
          },
          "required": ["id", "project_name", "mode", "status", "port"]
        }
      }
    }
  }
}
```

### Configuration Per Instance

```yaml
# ~/.ai-sessions/configs/{instance_id}.yml
instance:
  id: "project-a-claude"
  project: "/Users/dev/project-a"
  mode: "claude"

resources:
  memory:
    limit: "1Gi"
    warning_threshold: "800Mi"
    critical_threshold: "950Mi"
  cpu:
    limit: "500m"
    warning_threshold: "400m"
    critical_threshold: "480m"

health:
  check_interval: "30s"
  timeout: "5s"
  max_retries: 3
  retry_delay: "10s"

networking:
  preferred_port: 9001
  port_range: [9000, 9999]

ai_config:
  claude:
    model: "claude-3-5-sonnet-20241022"
    max_tokens: 4096
    temperature: 0.7
  gemini:
    model: "gemini-2.5-pro"
    max_output_tokens: 8192
    temperature: 0.9
```

---

## Implementation Details

### Main Session Manager Functions

```bash
#!/bin/bash
# ai-session-manager.sh - Main implementation

# Core functions
start_instance() {
  local project_name=$1
  local mode=$2
  local instance_id=${3:-"${project_name}-${mode}"}

  echo "🚀 Starting instance: $instance_id"

  # Check if already exists
  if is_instance_running "$instance_id"; then
    echo "⚠️ Instance $instance_id already running"
    return 1
  fi

  # Load configuration
  local config_file="${SESSION_DIR}/configs/${instance_id}.yml"
  if [[ ! -f "$config_file" ]]; then
    create_default_config "$instance_id" "$project_name" "$mode"
  fi

  # Allocate port
  local port=$(allocate_port)
  if [[ -z "$port" ]]; then
    echo "❌ Failed to allocate port for $instance_id"
    return 1
  fi

  # Create socket path
  local socket_path="${SOCKET_DIR}/${instance_id}.sock"

  # Prepare volume mounts
  local project_path=$(pwd)
  local state_dir="${SESSION_DIR}/states/${instance_id}"
  mkdir -p "$state_dir"

  # Start container
  local container_id=$(docker run -d \
    --name "ai-${instance_id}" \
    --label "ai.instance=${instance_id}" \
    --label "ai.mode=${mode}" \
    --label "ai.project=${project_name}" \
    -p "${port}:${port}" \
    -v "${project_path}:/app/${project_name}" \
    -v "${state_dir}:/root/.ai" \
    -v "${socket_path}:/tmp/ai.sock" \
    -e AI_MODE="$mode" \
    -e AI_INSTANCE_ID="$instance_id" \
    -e AI_PORT="$port" \
    -e AI_SOCKET_PATH="/tmp/ai.sock" \
    --memory="$(get_config "$instance_id" "resources.memory.limit" "1Gi")" \
    --cpus="$(get_config "$instance_id" "resources.cpu.limit" "0.5")" \
    claude-code-tools)

  if [[ $? -eq 0 ]]; then
    # Register instance
    register_instance "$instance_id" "$project_name" "$project_path" "$mode" \
                   "$container_id" "$port" "$socket_path"

    # Wait for health
    wait_for_healthy "$instance_id" 30

    echo "✅ Instance $instance_id started successfully"
    echo "   Port: $port"
    echo "   Socket: $socket_path"
    return 0
  else
    echo "❌ Failed to start container for $instance_id"
    return 1
  fi
}

stop_instance() {
  local instance_id=$1
  local force=${2:-false}

  if ! is_instance_registered "$instance_id"; then
    echo "⚠️ Instance $instance_id not found"
    return 1
  fi

  echo "🛑 Stopping instance: $instance_id"

  local registry=$(load_registry)
  local container_id=$(echo "$registry" | jq -r ".[\"$instance_id\"].container_id")

  # Graceful shutdown
  if [[ "$force" != "true" ]]; then
    echo "   Attempting graceful shutdown..."
    docker stop --time=10 "$container_id" 2>/dev/null || true
    sleep 2
  fi

  # Force kill if still running
  if docker ps -q --filter "id=$container_id" | grep -q .; then
    echo "   Force killing container..."
    docker kill "$container_id" 2>/dev/null || true
  fi

  # Remove container
  docker rm "$container_id" 2>/dev/null || true

  # Update registry
  update_instance_status "$instance_id" "stopped"

  # Cleanup resources
  cleanup_instance_resources "$instance_id"

  echo "✅ Instance $instance_id stopped"
}

list_instances() {
  local registry=$(load_registry)

  if [[ $(echo "$registry" | jq 'length') -eq 0 ]]; then
    echo "📭 No running instances"
    return 0
  fi

  echo "🤖 AI Instances Status:"
  echo ""
  printf "%-20s %-10s %-8s %-12s %-15s %s\n" \
    "PROJECT" "MODE" "PORT" "STATUS" "RESOURCES" "UPTIME"
  echo "$(printf '=%.0s' {1..80})"

  while IFS= read -r instance; do
    local id=$(echo "$instance" | jq -r '.id')
    local project=$(echo "$instance" | jq -r '.project_name')
    local mode=$(echo "$instance" | jq -r '.mode')
    local port=$(echo "$instance" | jq -r '.port')
    local status=$(echo "$instance" | jq -r '.status')
    local cpu=$(echo "$instance" | jq -r '.resources.cpu_usage // "N/A"')
    local mem=$(echo "$instance" | jq -r '.resources.memory_usage // "N/A"')
    local resources="${cpu}/${mem}"

    # Calculate uptime
    local started=$(echo "$instance" | jq -r '.timestamps.started // .timestamps.created')
    local uptime="N/A"
    if [[ "$started" != "null" ]]; then
      uptime=$(calculate_uptime "$started")
    fi

    # Color coding
    local color_code=""
    case "$status" in
      "running") color_code="\033[32m" ;;  # Green
      "error") color_code="\033[31m" ;;    # Red
      "paused") color_code="\033[33m" ;;   # Yellow
    esac

    printf "%-20s %-10s %-8s ${color_code}%-12s\033[0m %-15s %s\n" \
      "$project" "$mode" "$port" "$status" "$resources" "$uptime"

  done <<< "$(echo "$registry" | jq -c '.[]' | sort)"
}

attach_to_instance() {
  local instance_id=$1

  if ! is_instance_running "$instance_id"; then
    echo "❌ Instance $instance_id is not running"
    return 1
  fi

  local registry=$(load_registry)
  local container_id=$(echo "$registry" | jq -r ".[\"$instance_id\"].container_id")

  echo "🔌 Attaching to instance: $instance_id"
  docker exec -it "$container_id" /bin/bash
}
```

### Integration with ai-assistant.zsh

```bash
# Enhanced ai-assistant.zsh with session management

# Load session manager
source "${AI_TOOLS_HOME}/ai-session-manager.sh"

# Enhanced gemini function
gemini() {
  local project_name=$(basename $(git rev-parse --show-toplevel 2>/dev/null || pwd))
  local instance_id="${project_name}-gemini"

  # Check if already running
  if is_instance_running "$instance_id"; then
    echo "✅ Gemini already running for $project_name"
    attach_to_instance "$instance_id"
    return 0
  fi

  # Start new instance
  if start_instance "$project_name" "gemini" "$instance_id"; then
    echo "🚀 Gemini started for $project_name (Instance: $instance_id)"

    # Setup cleanup on exit
    trap 'stop_instance "$instance_id" 2>/dev/null || true' EXIT

    # Attach to container
    attach_to_instance "$instance_id"
  else
    echo "❌ Failed to start Gemini for $project_name"
    return 1
  fi
}

# Enhanced claude function
claude() {
  local project_name=$(basename $(git rev-parse --show-toplevel 2>/dev/null || pwd))
  local instance_id="${project_name}-claude"

  # Check if already running
  if is_instance_running "$instance_id"; then
    echo "✅ Claude already running for $project_name"
    attach_to_instance "$instance_id"
    return 0
  fi

  # Start new instance
  if start_instance "$project_name" "claude" "$instance_id"; then
    echo "🚀 Claude started for $project_name (Instance: $instance_id)"

    # Setup cleanup on exit
    trap 'stop_instance "$instance_id" 2>/dev/null || true' EXIT

    # Attach to container
    attach_to_instance "$instance_id"
  else
    echo "❌ Failed to start Claude for $project_name"
    return 1
  fi
}

# New session management commands
ai-list() {
  list_instances
}

ai-stop() {
  local instance_id=$1
  if [[ -z "$instance_id" ]]; then
    echo "Usage: ai-stop <instance-id>"
    echo ""
    echo "Available instances:"
    list_instances | grep "running" | awk '{print $1 "-" $2}'
    return 1
  fi

  stop_instance "$instance_id"
}

ai-stop-all() {
  local registry=$(load_registry)
  local count=$(echo "$registry" | jq 'length')

  if [[ $count -eq 0 ]]; then
    echo "📭 No instances to stop"
    return 0
  fi

  echo "🛑 Stopping all $count instances..."

  while IFS= read -r instance_id; do
    stop_instance "$instance_id"
  done <<< "$(echo "$registry" | jq -r 'keys[]')"

  echo "✅ All instances stopped"
}

ai-restart() {
  local instance_id=$1
  if [[ -z "$instance_id" ]]; then
    echo "Usage: ai-restart <instance-id>"
    return 1
  fi

  echo "🔄 Restarting instance: $instance_id"

  local registry=$(load_registry)
  local project=$(echo "$registry" | jq -r ".[\"$instance_id\"].project_name")
  local mode=$(echo "$registry" | jq -r ".[\"$instance_id\"].mode")

  stop_instance "$instance_id"
  sleep 2
  start_instance "$project" "$mode" "$instance_id"
}

ai-logs() {
  local instance_id=$1
  local follow=${2:-false}

  if [[ -z "$instance_id" ]]; then
    echo "Usage: ai-logs <instance-id> [--follow]"
    return 1
  fi

  local registry=$(load_registry)
  local container_id=$(echo "$registry" | jq -r ".[\"$instance_id\"].container_id")

  if [[ "$follow" == "--follow" ]]; then
    docker logs -f "$container_id"
  else
    docker logs --tail 50 "$container_id"
  fi
}

ai-stats() {
  local registry=$(load_registry)

  if [[ $(echo "$registry" | jq 'length') -eq 0 ]]; then
    echo "📭 No running instances"
    return 0
  fi

  echo "📊 Resource Usage Statistics:"
  echo ""

  while IFS= read -r instance; do
    local id=$(echo "$instance" | jq -r '.id')
    local container_id=$(echo "$instance" | jq -r '.container_id')

    echo "🤖 $id:"
    docker stats --no-stream --format "  CPU: {{.CPUPerc}}\n  Memory: {{.MemUsage}} ({{.MemPerc}})\n  Net I/O: {{.NetIO}}\n  Block I/O: {{.BlockIO}}" "$container_id"
    echo ""
  done <<< "$(echo "$registry" | jq -c '.[]')"
}
```

---

## API Specification

### Session Manager CLI API

```bash
# Instance lifecycle
ai-session start <project> <mode> [instance-id]
ai-session stop <instance-id> [--force]
ai-session restart <instance-id>
ai-session attach <instance-id>

# Instance discovery
ai-session list [--status running|stopped|all]
ai-session show <instance-id>
ai-session find <project> [mode]

# Resource management
ai-session stats [--watch]
ai-session logs <instance-id> [--follow] [--tail N]
ai-session top

# Configuration
ai-session config <instance-id> [--edit]
ai-session config set <instance-id> <key> <value>
ai-session config get <instance-id> <key>

# Health operations
ai-session health check [instance-id]
ai-session health watch
ai-session heal <instance-id>
```

### REST API (Optional Extension)

```yaml
# API Server Specification
/api/v1/instances:
  GET: List all instances
  POST: Create new instance

/api/v1/instances/{id}:
  GET: Get instance details
  PUT: Update instance
  DELETE: Stop instance

/api/v1/instances/{id}/logs:
  GET: Get instance logs

/api/v1/instances/{id}/stats:
  GET: Get resource statistics

/api/v1/health:
  GET: Overall health status

/api/v1/resources:
  GET: Resource utilization summary
```

---

## Integration Guide

### Step 1: Installation

```bash
# 1. Clone session manager
git clone <session-manager-repo> ~/.ai-sessions/manager
cd ~/.ai-sessions/manager

# 2. Install dependencies
brew install jq bc nc

# 3. Setup shell integration
echo 'source ~/.ai-sessions/manager/ai-session-manager.sh' >> ~/.zshrc
echo 'source ~/.ai-sessions/manager/ai-assistant-enhanced.zsh' >> ~/.zshrc

# 4. Create initial directories
mkdir -p ~/.ai-sessions/{configs,states,logs,sockets}
```

### Step 2: Configuration

```bash
# Create default configuration
cat > ~/.ai-sessions/config/default.yml << 'EOF'
defaults:
  resources:
    memory_limit: "1Gi"
    cpu_limit: "500m"
  health:
    check_interval: "30s"
    timeout: "5s"
  networking:
    port_range: [9000, 9999]

global:
  max_instances: 10
  auto_cleanup: true
  log_retention: "7d"
EOF
```

### Step 3: Testing

```bash
# Test single instance
cd ~/project-a
gemini  # Should start new instance

# Test multiple instances
cd ~/project-b
gemini  # Should start second instance

cd ~/project-c
claude  # Should start third instance

# List all instances
ai-list

# Monitor resources
ai-stats --watch
```

---

## Deployment Strategy

### Phase 1: Core Implementation (Week 1)

**Tasks**:
1. ✅ Session manager controller
2. ✅ Instance registry
3. ✅ Port allocator
4. ✅ Basic health checks
5. ✅ CLI integration

**Deliverables**:
- `ai-session-manager.sh`
- Enhanced `ai-assistant.zsh`
- Basic documentation

### Phase 2: Advanced Features (Week 2)

**Tasks**:
1. Resource monitoring
2. Auto-recovery mechanisms
3. Configuration management
4. Logging system
5. Alert notifications

**Deliverables**:
- Resource monitor
- Health checker
- Configuration templates
- Alert system

### Phase 3: Production Readiness (Week 3)

**Tasks**:
1. Performance optimization
2. Security hardening
3. Complete documentation
4. Testing suite
5. Monitoring dashboard

**Deliverables**:
- Optimized implementation
- Security audit report
- Complete docs
- Test suite
- Monitoring tools

---

## Monitoring & Observability

### Metrics Collection

```bash
# System metrics
collect_system_metrics() {
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}')
  local memory_pressure=$(memory_pressure | grep "System-wide memory free percentage" | awk '{print $5}')

  echo "{\"timestamp\":\"$timestamp\",\"cpu\":\"$cpu_usage\",\"memory_free\":\"$memory_pressure\"}"
}

# Instance metrics
collect_instance_metrics() {
  local registry=$(load_registry)
  local metrics=()

  while IFS= read -r instance; do
    local id=$(echo "$instance" | jq -r '.id')
    local container_id=$(echo "$instance" | jq -r '.container_id')

    local stats=$(docker stats --no-stream --format \
      "{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" \
      "$container_id" 2>/dev/null)

    if [[ -n "$stats" ]]; then
      local cpu=$(echo "$stats" | cut -f1)
      local mem=$(echo "$stats" | cut -f2)
      local net=$(echo "$stats" | cut -f3)
      local block=$(echo "$stats" | cut -f4)

      metrics+=("{\"instance\":\"$id\",\"cpu\":\"$cpu\",\"memory\":\"$mem\",\"net_io\":\"$net\",\"block_io\":\"$block\"}")
    fi
  done <<< "$(echo "$registry" | jq -c '.[]')"

  echo "[${metrics[@]}]" | jq -s '.'
}
```

### Logging Strategy

```bash
# Structured logging
log_event() {
  local level=$1
  local component=$2
  local message=$3
  local metadata=${4:-"{}"}

  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local log_entry="{
    \"timestamp\": \"$timestamp\",
    \"level\": \"$level\",
    \"component\": \"$component\",
    \"message\": \"$message\",
    \"metadata\": $metadata
  }"

  echo "$log_entry" >> "${LOG_DIR}/session-manager.log"

  # Also output to console with colors
  case "$level" in
    "ERROR") echo -e "\033[31m[ERROR]\033[0m $message" ;;
    "WARN") echo -e "\033[33m[WARN]\033[0m $message" ;;
    "INFO") echo -e "\033[32m[INFO]\033[0m $message" ;;
    "DEBUG") echo -e "\033[36m[DEBUG]\033[0m $message" ;;
  esac
}
```

### Dashboard Integration

```bash
# Generate metrics for dashboard
generate_dashboard_data() {
  local registry=$(load_registry)
  local system_metrics=$(collect_system_metrics)
  local instance_metrics=$(collect_instance_metrics)

  jq -n \
    --argjson system "$system_metrics" \
    --argjson instances "$instance_metrics" \
    --argjson registry "$registry" \
    '{
      "timestamp": now,
      "system": $system,
      "instances": $instances,
      "summary": {
        "total": $registry | length,
        "running": [$registry | to_entries[] | select(.value.status == "running")] | length,
        "stopped": [$registry | to_entries[] | select(.value.status == "stopped")] | length,
        "error": [$registry | to_entries[] | select(.value.status == "error")] | length
      }
    }'
}
```

---

## 🏷️ Document Tags

```
Priority: CRITICAL
Type: ARCHITECTURE_SPECIFICATION
Scope: MULTI_INSTANCE_MANAGEMENT
Version: 1.0
Last Updated: 2025-12-11
Validated: ✅
Related: CLAUDE.md, AI_SYSTEM_INSTRUCTIONS.md, GIT_WORKFLOWS.md
Implementation_Status: PLANNED
```

---

*This architecture specification provides a complete solution for managing multiple concurrent AI assistant instances with proper resource isolation, health monitoring, and automated recovery capabilities.*