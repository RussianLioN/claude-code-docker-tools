#!/bin/zsh

# AI Assistant zsh - Trae IDE Compatible Isolated Implementation
# Based on working patterns with sandbox compatibility

AI_TOOLS_HOME=${0:a:h}

# Trae IDE compatible configuration (project-local)
export DOCKER_AI_CONFIG_HOME="./config/active"
export CLAUDE_STATE_DIR="${DOCKER_AI_CONFIG_HOME}/claude"
export GLM_STATE_DIR="${DOCKER_AI_CONFIG_HOME}/glm"
export GEMINI_STATE_DIR="${DOCKER_AI_CONFIG_HOME}/gemini"

# Create local configuration directories
mkdir -p "$CLAUDE_STATE_DIR" "$GLM_STATE_DIR" "$GEMINI_STATE_DIR"

# Load environment variables if exist
if [[ -f "./.env" ]]; then
  source "./.env"
fi

# --- 1. SYSTEM CHECKS ---

function ensure_docker_running() {
  if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker не запущен. Пожалуйста, запустите Docker Desktop." >&2
    return 1
  fi
}

# --- 2. SIMPLIFIED ISOLATION ---

function prepare_simple_configuration() {
  local command="$1"
  
  # Set workspace to current directory
  export TARGET_DIR="$(pwd)"
  export CONTAINER_BASE_DIR="/workspace"
  export CONTAINER_WORKDIR="${CONTAINER_BASE_DIR}/$(basename "$TARGET_DIR")"
  
  # Select state directory
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
  
  # Create state directory
  mkdir -p "$ACTIVE_STATE_DIR"
}

# --- 3. SIMPLIFIED CONTAINER EXECUTION ---

function run_simple_container() {
  local command="$1"
  shift

  # Docker flags
  local DOCKER_FLAGS="-i"
  if [ -t 1 ] && [ -z "$1" ]; then
    DOCKER_FLAGS="-it"
  fi

  # Use working image
  local ai_image="claude-code-tools"
  
  # Generate simple container name
  local container_name="${command}-$(date +%s)"
  local container_hostname="${command}-dev-env"

  # Environment variables
  local -a env_vars
  env_vars+=("-e" "AI_MODE=$command")
  env_vars+=("-e" "NODE_OPTIONS=--dns-result-order=ipv4first")

  # Set GOOGLE_CLOUD_PROJECT
  local project_id="${GOOGLE_CLOUD_PROJECT:-claude-code-docker-tools}"
  if [[ -n "$project_id" ]]; then
    env_vars+=("-e" "GOOGLE_CLOUD_PROJECT=$project_id")
  fi

  # Special handling for GLM mode
  if [[ "$command" == "glm" ]]; then
    local zai_key="${ZAI_API_KEY:-}"
    if [[ -z "$zai_key" ]]; then
       echo "❌ Ошибка: ZAI_API_KEY не найден." >&2
       echo "   Установите переменную окружения ZAI_API_KEY." >&2
       return 1
    fi

    # GLM settings
    env_vars+=("-e" "AI_MODE=claude")
    env_vars+=("-e" "ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic")
    env_vars+=("-e" "ANTHROPIC_API_KEY=$zai_key")
  fi

  # Run container with working directory mounts
  echo "🚀 Запуск ${command} в контейнере: $container_name" >&2
  
  docker run $DOCKER_FLAGS --name "$container_name" \
    --hostname "$container_hostname" \
    --network host \
    "${env_vars[@]}" \
    -v "${ACTIVE_STATE_DIR}":/root/.claude-config \
    -w "${CONTAINER_WORKDIR}" \
    -v "${TARGET_DIR}":"${CONTAINER_BASE_DIR}" \
    --entrypoint "/bin/sh" \
    "$ai_image" -c "$command \$@; echo '👋 $(echo ${command} | tr '[:lower:]' '[:upper:]') завершен.'; exec /bin/bash"
      
  local exit_code=$?
  
  # Cleanup container
  docker rm -f "$container_name" >/dev/null 2>&1
  return $exit_code
}

# --- 4. AI FUNCTIONS ---

function claude() {
  # Native bypass check
  if [[ "$1" == "--native" || "$1" == "--local" ]]; then
    shift
    echo "🖥️  Запуск нативной версии Claude..." >&2
    command claude "$@"
    return $?
  fi

  ensure_docker_running
  prepare_simple_configuration "claude"
  run_simple_container claude "$@"
}

function glm() {
  ensure_docker_running
  prepare_simple_configuration "glm"
  run_simple_container glm "$@"
}

function gemini() {
  ensure_docker_running
  prepare_simple_configuration "gemini"
  run_simple_container gemini "$@"
}

# --- 5. STATUS FUNCTIONS ---

function ai-status() {
  echo "🤖 AI Assistant Status" >&2
  echo "====================" >&2
  
  # Docker status
  if docker info >/dev/null 2>&1; then
    echo "✅ Docker: запущен" >&2
  else
    echo "❌ Docker: не запущен" >&2
  fi
  
  # Configuration directories
  echo "" >&2
  echo "📁 Конфигурационные директории:" >&2
  echo "  Claude: $CLAUDE_STATE_DIR" >&2
  echo "  GLM: $GLM_STATE_DIR" >&2
  echo "  Gemini: $GEMINI_STATE_DIR" >&2
  
  # Running containers
  echo "" >&2
  echo "🐳 Запущенные контейнеры:" >&2
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep "claude\|glm\|gemini" || echo "  Нет запущенных AI контейнеров" >&2
}

# --- 6. CLEANUP FUNCTIONS ---

function ai-cleanup() {
  echo "🧹 Очистка AI контейнеров..." >&2
  
  # Remove AI containers
  local containers=$(docker ps -aq --filter "name=claude\|glm\|gemini")
  if [[ -n "$containers" ]]; then
    docker rm -f $containers >/dev/null 2>&1
    echo "✅ Контейнеры удалены" >&2
  else
    echo "ℹ️ Нет контейнеров для удаления" >&2
  fi
}

echo "🤖 AI Assistant Isolated (Trae IDE Compatible) загружен" >&2
echo "Используйте: claude, glm, gemini, ai-status, ai-cleanup" >&2