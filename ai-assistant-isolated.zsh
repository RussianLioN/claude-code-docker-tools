#!/bin/zsh

# AI Assistant zsh - Enhanced Isolated Container Implementation
# Based on proven working patterns with improved isolation

AI_TOOLS_HOME=${0:a:h}

# Set configuration directories with fallback logic
export DOCKER_AI_CONFIG_HOME="${HOME}/.docker-ai-config"
export LEGACY_DOCKER_CONFIG_HOME="${HOME}/.docker-gemini-config"

# Enhanced isolated state directories
export CLAUDE_STATE_DIR="${DOCKER_AI_CONFIG_HOME}/claude-isolated"
export GLM_STATE_DIR="${DOCKER_AI_CONFIG_HOME}/glm-isolated"
export GEMINI_STATE_DIR="${DOCKER_AI_CONFIG_HOME}/gemini-isolated"

# Credential paths with fallback
export GLOBAL_AUTH="$DOCKER_AI_CONFIG_HOME/google_accounts.json"
export GLOBAL_SETTINGS="$DOCKER_AI_CONFIG_HOME/settings.json"
export CLAUDE_CONFIG="$DOCKER_AI_CONFIG_HOME/claude_config.json"
export GLM_CONFIG="$DOCKER_AI_CONFIG_HOME/glm_config.json"
export GH_CONFIG_DIR="$DOCKER_AI_CONFIG_HOME/gh_config"

# Check if migration is needed
check_and_migrate_credentials() {
  # Load credential manager
  local credential_manager="${AI_TOOLS_HOME}/scripts/credential-manager.sh"

  if [[ -f "$credential_manager" ]]; then
    # Auto-migrate on first run
    if [[ ! -f "$GLOBAL_AUTH" && -f "$LEGACY_DOCKER_CONFIG_HOME/google_accounts.json" ]]; then
      echo "🔄 Обнаружены legacy credentials, выполняю миграцию..." >&2
      "$credential_manager" migrate
    fi
  fi
}

# Create global config directory
mkdir -p "$DOCKER_AI_CONFIG_HOME"
mkdir -p "$GH_CONFIG_DIR"

# Create isolated state directories
mkdir -p "$CLAUDE_STATE_DIR" "$GLM_STATE_DIR" "$GEMINI_STATE_DIR"

# Load environment variables if exist
if [[ -f "$DOCKER_AI_CONFIG_HOME/env" ]]; then
  source "$DOCKER_AI_CONFIG_HOME/env"
fi

# Auto-detect Trae IDE sandbox mode
if [[ ! -w "$(dirname "$DOCKER_AI_CONFIG_HOME")" ]]; then
  export TRAE_SANDBOX_MODE=1
  echo "🔒 Обнаружен Trae IDE sandbox режим" >&2
fi

# --- 1. EXPERT SYSTEM CHECKS ---

function ensure_docker_running() {
  if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker не запущен. Пожалуйста, запустите Docker Desktop." >&2
    return 1
  fi
}

function ensure_ssh_loaded() {
  if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
    echo "⚠️ SSH agent не запущен. Git операции могут не работать." >&2
  fi
}

# --- 2. ENHANCED ISOLATION FUNCTIONS ---

# Generate UUID4 for container identification
generate_container_uuid() {
  local mode="$1"
  local timestamp=$(date +%s)
  local uuid4=$(python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || echo "unknown")
  echo "${mode}-${timestamp}-${uuid4:0:8}"
}

# Enhanced configuration preparation with isolation
function prepare_isolated_configuration() {
  local command="$1"
  
  # Set workspace and container directories
  export TARGET_DIR="${TARGET_DIR:-$(pwd)}"
  export CONTAINER_BASE_DIR="/workspace"
  export CONTAINER_WORKDIR="${CONTAINER_BASE_DIR}/$(basename "$TARGET_DIR")"
  
  # Isolated state directory selection
  case "$command" in
    "claude")
      export ACTIVE_STATE_DIR="$CLAUDE_STATE_DIR"
      ;;
    "glm")
      export ACTIVE_STATE_DIR="$GLM_STATE_DIR"
      ;;
    "gemini")
      export ACTIVE_STATE_DIR="$GEMINI_STATE_DIR"
      ;;
    *)
      export ACTIVE_STATE_DIR="$CLAUDE_STATE_DIR"
      ;;
  esac
  
  # Create isolated state directory
  mkdir -p "$ACTIVE_STATE_DIR"
  
  # Copy configuration files to isolated directory
  if [[ -f "$GLOBAL_AUTH" ]]; then
    cp "$GLOBAL_AUTH" "$ACTIVE_STATE_DIR/google_accounts.json"
  fi

  if [[ -f "$GLOBAL_SETTINGS" ]]; then
    cp "$GLOBAL_SETTINGS" "$ACTIVE_STATE_DIR/settings.json"
  fi

  if [[ -f "$CLAUDE_CONFIG" ]]; then
    cp "$CLAUDE_CONFIG" "$ACTIVE_STATE_DIR/claude_config.json"
  fi

  if [[ -f "$GLM_CONFIG" ]]; then
    cp "$GLM_CONFIG" "$ACTIVE_STATE_DIR/glm_config.json"
  fi

  # SSH known hosts
  export SSH_KNOWN_HOSTS="$HOME/.ssh/known_hosts"
  touch "$SSH_KNOWN_HOSTS"

  # Git config
  export GIT_CONFIG="$HOME/.gitconfig"
  touch "$GIT_CONFIG"
  
  # Clean SSH config for container
  export SSH_CONFIG_CLEAN="/tmp/ssh-config-clean"
  cat "$HOME/.ssh/config" 2>/dev/null | sed 's/^Match host \*.*//' > "$SSH_CONFIG_CLEAN" || touch "$SSH_CONFIG_CLEAN"
}

# Enhanced cleanup with isolation
function cleanup_isolated_configuration() {
  # Expert sync-out pattern with sandbox detection
  if [[ -n "$TRAE_SANDBOX_MODE" || ! -w "$(dirname "$GLOBAL_AUTH")" ]]; then
    echo "📦 Sandbox режим: пропускаю синхронизацию конфигурации" >&2
    return 0
  fi
  
  # Sync back only the active state directory
  if [[ -f "$ACTIVE_STATE_DIR/google_accounts.json" ]]; then
    cp "$ACTIVE_STATE_DIR/google_accounts.json" "$GLOBAL_AUTH" 2>/dev/null || true
  fi

  if [[ -f "$ACTIVE_STATE_DIR/settings.json" ]]; then
    cp "$ACTIVE_STATE_DIR/settings.json" "$GLOBAL_SETTINGS" 2>/dev/null || true
  fi

  if [[ -f "$ACTIVE_STATE_DIR/claude_config.json" ]]; then
    cp "$ACTIVE_STATE_DIR/claude_config.json" "$CLAUDE_CONFIG" 2>/dev/null || true
  fi
  
  if [[ -f "$ACTIVE_STATE_DIR/glm_config.json" ]]; then
    cp "$ACTIVE_STATE_DIR/glm_config.json" "$GLM_CONFIG" 2>/dev/null || true
  fi
}

# --- 3. ENHANCED CONTAINER EXECUTION ---

function run_isolated_container() {
  local command="$1"
  shift

  # Expert Docker flags pattern
  local DOCKER_FLAGS="-i"
  if [ -t 1 ] && [ -z "$1" ]; then
    DOCKER_FLAGS="-it"
  fi

  # Use proven working image
  local ai_image="claude-code-tools"
  
  # Ensure variables are set
  if [[ -z "${TARGET_DIR}" || -z "${CONTAINER_WORKDIR}" || -z "${ACTIVE_STATE_DIR}" ]]; then
    echo "❌ Ошибка: переменные не установлены. Вызовите prepare_isolated_configuration() сначала." >&2
    return 1
  fi

  # Generate unique container ID
  local container_id=$(generate_container_uuid "$command")
  local container_name="${command##*/}-isolated-${container_id}"
  local container_hostname="${command}-isolated-env"

  # Resource limits for isolation
  local -a resource_limits=(
    "--memory=1g"
    "--cpus=1.0"
    "--pids-limit=100"
  )

  # Environment variables
  local -a env_vars
  env_vars+=("-e" "AI_MODE=$command")
  env_vars+=("-e" "CONTAINER_ID=$container_id")
  env_vars+=("-e" "NODE_OPTIONS=--dns-result-order=ipv4first")

  # Set GOOGLE_CLOUD_PROJECT
  local project_id="${GOOGLE_CLOUD_PROJECT:-claude-code-docker-tools}"
  if [[ -n "$project_id" ]]; then
    env_vars+=("-e" "GOOGLE_CLOUD_PROJECT=$project_id")
  fi

  # Special handling for GLM mode
  if [[ "$command" == "glm" ]]; then
    # GLM Mode via Z.AI logic (preserved from working version)
    local zai_key="${ZAI_API_KEY:-}"
    if [[ -z "$zai_key" && -f "$DOCKER_AI_CONFIG_HOME/global_state/secrets/zai_key" ]]; then
       zai_key=$(cat "$DOCKER_AI_CONFIG_HOME/global_state/secrets/zai_key")
    fi
    
    if [[ -z "$zai_key" ]]; then
       echo "❌ Ошибка: ZAI_API_KEY не найден." >&2
       echo "   Установите переменную окружения ZAI_API_KEY или сохраните ключ в secrets." >&2
       return 1
    fi

    # Generate GLM settings
    local glm_settings_file="$ACTIVE_STATE_DIR/settings.json"
    cat > "$glm_settings_file" <<EOF
{
  "ANTHROPIC_AUTH_TOKEN": "$zai_key",
  "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
  "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
  "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.6",
  "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.6",
  "ANTHROPIC_MODEL": "glm-4.6",
  "alwaysThinkingEnabled": true,
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "$zai_key",
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.6",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.6",
    "ANTHROPIC_MODEL": "glm-4.6",
    "alwaysThinkingEnabled": "true"
  },
  "includeCoAuthoredBy": false
}
EOF

    # FORCE AI_MODE=claude so entrypoint.sh launches claude binary
    env_vars+=("-e" "AI_MODE=claude")
    env_vars+=("-e" "ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic")
    env_vars+=("-e" "ANTHROPIC_API_KEY=$zai_key")
  fi

  # System command handling
  if [[ "$command" == "/bin/sh" || "$command" == "sh" || "$command" == "bash" || "$command" == "/bin/bash" ]]; then
    docker run $DOCKER_FLAGS --name "$container_name" \
      --entrypoint "$command" \
      --network host \
      "${resource_limits[@]}" \
      "${env_vars[@]}" \
      -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
      -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
      -v "${SSH_KNOWN_HOSTS}":/root/.ssh/known_hosts \
      -v "${SSH_CONFIG_CLEAN}":/root/.ssh/config \
      -v "${GIT_CONFIG}":/root/.gitconfig \
      -v "${GH_CONFIG_DIR}":/root/.config/gh \
      -v "${ACTIVE_STATE_DIR}":/root/.claude-config \
      -w "${CONTAINER_WORKDIR}" \
      -v "${TARGET_DIR}":"${CONTAINER_BASE_DIR}" \
      "$ai_image" "$@"
  else
    # AI command execution with isolation
    echo "🚀 Запуск ${command} в изолированном контейнере: $container_name" >&2
    
    docker run $DOCKER_FLAGS --name "$container_name" \
      --hostname "$container_hostname" \
      --network host \
      "${resource_limits[@]}" \
      "${env_vars[@]}" \
      -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
      -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
      -v "${SSH_KNOWN_HOSTS}":/root/.ssh/known_hosts \
      -v "${SSH_CONFIG_CLEAN}":/root/.ssh/config \
      -v "${GIT_CONFIG}":/root/.gitconfig \
      -v "${GH_CONFIG_DIR}":/root/.config/gh \
      -v "${ACTIVE_STATE_DIR}":/root/.claude-config \
      -w "${CONTAINER_WORKDIR}" \
      -v "${TARGET_DIR}":"${CONTAINER_BASE_DIR}" \
      --entrypoint "/bin/sh" \
      "$ai_image" -c "$command \$@; echo '👋 ${command^} завершен.'; exec /bin/bash"
      
    local exit_code=$?
    
    # Enhanced sync-out with isolation
    echo "💾 Сохранение изолированной сессии ${command}..." >&2
    mkdir -p "$ACTIVE_STATE_DIR"
    chmod 755 "$ACTIVE_STATE_DIR" 2>/dev/null || true
    
    if docker cp "$container_name":/root/.claude-config/. "$ACTIVE_STATE_DIR/" >/dev/null 2>&1; then
       echo "✅ Изолированная сессия ${command} сохранена в $ACTIVE_STATE_DIR" >&2
    else
       echo "⚠️ Ошибка сохранения сессии ${command}." >&2
    fi
    
    docker rm -f "$container_name" >/dev/null 2>&1
    return $exit_code
  fi
}

# --- 4. AI FUNCTIONS WITH ENHANCED ISOLATION ---

function claude() {
  # Native bypass check
  if [[ "$1" == "--native" || "$1" == "--local" ]]; then
    shift
    echo "🖥️  Запуск нативной версии Claude..." >&2
    command claude "$@"
    return $?
  fi

  ensure_docker_running
  ensure_ssh_loaded
  prepare_isolated_configuration "claude"

  local is_interactive=false
  if [ -t 1 ] && [ -z "$1" ]; then
    is_interactive=true
  fi

  run_isolated_container claude "$@"
  local exit_code=$?

  cleanup_isolated_configuration

  if [[ "$is_interactive" == "true" && -n "$GIT_ROOT" ]]; then
    echo -e "\n👋 Сеанс Claude завершен." >&2
  fi

  return $exit_code
}

function glm() {
  ensure_docker_running
  ensure_ssh_loaded
  prepare_isolated_configuration "glm"

  local is_interactive=false
  if [ -t 1 ] && [ -z "$1" ]; then
    is_interactive=true
  fi

  run_isolated_container glm "$@"
  local exit_code=$?

  cleanup_isolated_configuration

  if [[ "$is_interactive" == "true" && -n "$GIT_ROOT" ]]; then
    echo -e "\n👋 Сеанс GLM завершен." >&2
  fi

  return $exit_code
}

function gemini() {
  ensure_docker_running
  ensure_ssh_loaded
  prepare_isolated_configuration "gemini"

  local is_interactive=false
  if [ -t 1 ] && [ -z "$1" ]; then
    is_interactive=true
  fi

  run_isolated_container gemini "$@"
  local exit_code=$?

  cleanup_isolated_configuration

  if [[ "$is_interactive" == "true" && -n "$GIT_ROOT" ]]; then
    echo -e "\n👋 Сеанс Gemini завершен." >&2
  fi

  return $exit_code
}

# --- 5. EXPERT AI COMMIT FUNCTIONS ---

function aic() {
  echo "🤖 Gemini AI Commit (DevOps стиль)" >&2
  gemini commit "$@"
}

function cic() {
  echo "🤖 Claude AI Commit (SE стиль)" >&2
  claude commit "$@"
}

# --- 6. EXPERT SYSTEM OPERATIONS ---

function gexec() {
  ensure_docker_running
  prepare_isolated_configuration "claude"

  echo "🔧 Выполнение команды в AI окружении: $*" >&2
  run_isolated_container /bin/bash "$@"
  cleanup_isolated_configuration
}

# --- 7. ENHANCED STATUS FUNCTIONS ---

function ai-status() {
  echo "🤖 AI Assistant Isolated Status" >&2
  echo "=============================" >&2
  
  # Docker status
  if docker info >/dev/null 2>&1; then
    echo "✅ Docker: запущен" >&2
  else
    echo "❌ Docker: не запущен" >&2
  fi
  
  # SSH status
  if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
    echo "✅ SSH Agent: запущен" >&2
  else
    echo "⚠️ SSH Agent: не запущен" >&2
  fi
  
  # Configuration directories
  echo "" >&2
  echo "📁 Изолированные директории:" >&2
  echo "  Claude: $CLAUDE_STATE_DIR" >&2
  echo "  GLM: $GLM_STATE_DIR" >&2
  echo "  Gemini: $GEMINI_STATE_DIR" >&2
  
  # Running containers
  echo "" >&2
  echo "🐳 Изолированные контейнеры:" >&2
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep "isolated" || echo "  Нет запущенных контейнеров" >&2
}

# --- 8. CLEANUP FUNCTIONS ---

function ai-cleanup() {
  echo "🧹 Очистка изолированных контейнеров..." >&2
  
  # Remove all isolated containers
  local containers=$(docker ps -aq --filter "name=isolated")
  if [[ -n "$containers" ]]; then
    docker rm -f $containers >/dev/null 2>&1
    echo "✅ Контейнеры удалены" >&2
  else
    echo "ℹ️ Нет контейнеров для удаления" >&2
  fi
  
  # Clean up old state directories (optional)
  read -p "Удалить старые state директории? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$CLAUDE_STATE_DIR" "$GLM_STATE_DIR" "$GEMINI_STATE_DIR"
    mkdir -p "$CLAUDE_STATE_DIR" "$GLM_STATE_DIR" "$GEMINI_STATE_DIR"
    echo "✅ State директории очищены" >&2
  fi
}

# Auto-initialization
check_and_migrate_credentials