#!/bin/zsh

# AI Assistant zsh - Expert Ephemeral Container Implementation
# Based on proven patterns from old-scripts/gemini.zsh

AI_TOOLS_HOME=${0:a:h}

# Set configuration directories with fallback logic
export DOCKER_AI_CONFIG_HOME="${HOME}/.docker-ai-config"
export LEGACY_DOCKER_CONFIG_HOME="${HOME}/.docker-gemini-config"

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
  # Enhanced Docker detection with Colima support (expert pattern)
  if [[ "$OSTYPE" == "darwin"* ]] && command -v colima >/dev/null 2>&1; then
    if ! colima status >/dev/null 2>&1; then
      echo "🚀 Запускаю Colima..." >&2
      colima start --cpu 2 --memory 4 --disk 60
    fi
    export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"
  elif ! docker info > /dev/null 2>&1; then
    echo "🐳 Docker не запущен. Запускаю..." >&2
    echo "⏳ Это может занять 30-90 секунд для полной инициализации" >&2
    open -a Docker

    # Увеличенный таймаут для Docker Desktop
    local max_wait=120
    local wait_time=0
    echo -n "  Ожидаю Docker daemon" >&2
    while ! docker info >/dev/null 2>&1 && [[ $wait_time -lt $max_wait ]]; do
      sleep 2
      ((wait_time++))
      echo -n "." >&2
      if (( wait_time % 10 == 0 )); then
        echo " (${wait_time}s/${max_wait}s)" >&2
        echo -n "  Все еще жду" >&2
      fi
    done
    echo "" >&2

    # Дополнительное ожидание для UI инициализации
    if docker info >/dev/null 2>&1; then
      echo -n "  Ожидаю инициализации Docker Desktop" >&2
      local ui_wait=0
      local max_ui_wait=30
      while [[ $ui_wait -lt $max_ui_wait ]]; do
        if docker version >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
          break
        fi
        sleep 1
        ((ui_wait++))
        echo -n "." >&2
      done
      echo "" >&2
    fi
    echo "✅ Docker готов!" >&2
  fi
}

function ensure_ssh_loaded() {
  # Expert SSH agent management pattern
  if ! ssh-add -l > /dev/null 2>&1; then
    ssh-add --apple-load-keychain > /dev/null 2>&1
    if ! ssh-add -l > /dev/null 2>&1; then
       echo "⚠️  Внимание: SSH-агент пуст. Git операции могут не работать." >&2
    fi
  fi
}

function check_updates() {
  # Expert update checking pattern
  if [[ "$1" == "interactive" ]]; then
    if ping -c 1 -W 100 8.8.8.8 &> /dev/null; then
      local CURRENT_VER=$(docker run --rm --entrypoint gemini claude-code-tools --version 2>/dev/null)
      local LATEST_VER=$(curl -m 3 -s https://registry.npmjs.org/@google/gemini-cli/latest | grep -o '"version":"[^"]*"' | cut -d'"' -f4)

      if [[ -n "$LATEST_VER" && "$CURRENT_VER" != "$LATEST_VER" ]]; then
        echo "✨ \033[1;35mДоступно обновление Gemini CLI:\033[0m $CURRENT_VER -> $LATEST_VER" >&2
        echo "📦 Для обновления выполните: docker build --build-arg GEMINI_VERSION=$LATEST_VER -t claude-code-tools $AI_TOOLS_HOME" >&2
      fi
    fi
  fi
}

# --- 2. EXPERT CONFIGURATION SYNC PATTERNS ---

function prepare_configuration() {
  # Check and migrate credentials if needed
  # check_and_migrate_credentials  <-- DISABLED to prevent restoring bad credentials

  # Expert sync-in pattern based on old-scripts/gemini.zsh
  local GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

  if [[ -n "$GIT_ROOT" ]]; then
    export TARGET_DIR="$GIT_ROOT"
    # export STATE_DIR="$GIT_ROOT/.ai-state" # DISABLED: Local state causes auth fragmentation
    export STATE_DIR="$DOCKER_AI_CONFIG_HOME/global_state" # ENABLED: Force global state for consistent auth

    # Calculate relative path from git root to current dir
    # This ensures we land in the correct subdirectory inside the container
    local RELATIVE_PATH="${PWD#$GIT_ROOT}"
    # Remove leading slash if present
    RELATIVE_PATH="${RELATIVE_PATH#/}"
  else
    export TARGET_DIR="$(pwd)"
    export STATE_DIR="$DOCKER_AI_CONFIG_HOME/global_state"
    local RELATIVE_PATH=""
  fi

  # Unified state directory for Claude within the project or global state
  export CLAUDE_STATE_DIR="$STATE_DIR/claude_config"
  export GLM_STATE_DIR="$DOCKER_AI_CONFIG_HOME/global_state/glm_config"
  mkdir -p "$GLM_STATE_DIR"

  local PROJECT_NAME=$(basename "$TARGET_DIR")

  # Ensure PROJECT_NAME is not empty and valid
  if [[ -z "$PROJECT_NAME" || "$PROJECT_NAME" == "/" ]]; then
    PROJECT_NAME="project"
  fi

  # Expert Mount Strategy: "Adaptive Workspace"
  # 1. If we are at the project root (RELATIVE_PATH is empty), we mount to /workspace/<PROJECT_NAME>
  #    This ensures the project name is visible in the UI.
  # 2. If we are in a subdirectory (RELATIVE_PATH exists), we mount the root to /workspace
  #    This hides the parent directory name (e.g. "test") and shows the subdirectory path directly (e.g. /workspace/claude-docker-test)

  if [[ -z "$RELATIVE_PATH" ]]; then
    export CONTAINER_BASE_DIR="/workspace/$PROJECT_NAME"
    export CONTAINER_WORKDIR="$CONTAINER_BASE_DIR"
  else
    export CONTAINER_BASE_DIR="/workspace"
    export CONTAINER_WORKDIR="$CONTAINER_BASE_DIR/$RELATIVE_PATH"
  fi

  mkdir -p "$STATE_DIR"
  mkdir -p "$GH_CONFIG_DIR"
  mkdir -p "$CLAUDE_STATE_DIR"
  mkdir -p "$GLM_STATE_DIR"

  # SSH Configuration Sanitization (expert pattern)
  local SSH_CONFIG_SRC="$HOME/.ssh/config"
  export SSH_CONFIG_CLEAN="$STATE_DIR/ssh_config_clean"
  if [[ -f "$SSH_CONFIG_SRC" ]]; then
    grep -vE "UseKeychain|AddKeysToAgent|IdentityFile|IdentitiesOnly" "$SSH_CONFIG_SRC" > "$SSH_CONFIG_CLEAN"
  else
    touch "$SSH_CONFIG_CLEAN"
  fi

  # Sync-in configuration files
  if [[ -f "$GLOBAL_AUTH" ]]; then
    cp "$GLOBAL_AUTH" "$STATE_DIR/google_accounts.json"
    # DEBUG: Check if file was copied
    if [[ ! -s "$STATE_DIR/google_accounts.json" ]]; then
       echo "⚠️  Внимание: google_accounts.json пуст или не скопирован!" >&2
       ls -l "$GLOBAL_AUTH" >&2
    fi
  else
    echo "⚠️  Внимание: Файл авторизации не найден: $GLOBAL_AUTH" >&2
  fi

  if [[ -f "$GLOBAL_SETTINGS" ]]; then
    cp "$GLOBAL_SETTINGS" "$STATE_DIR/settings.json"
  fi

  if [[ -f "$CLAUDE_CONFIG" ]]; then
    cp "$CLAUDE_CONFIG" "$STATE_DIR/claude_config.json"
  fi

  if [[ -f "$GLM_CONFIG" ]]; then
    cp "$GLM_CONFIG" "$STATE_DIR/glm_config.json"
  fi

  # Load Claude API key if available
  if [[ -f "$STATE_DIR/claude.env" ]]; then
    source "$STATE_DIR/claude.env"
  fi

  # SSH known hosts
  export SSH_KNOWN_HOSTS="$HOME/.ssh/known_hosts"
  touch "$SSH_KNOWN_HOSTS"

  # Git config
  export GIT_CONFIG="$HOME/.gitconfig"
  touch "$GIT_CONFIG"
}

function cleanup_configuration() {
  # Expert sync-out pattern with sandbox detection
  if [[ -n "$TRAE_SANDBOX_MODE" || ! -w "$(dirname "$GLOBAL_AUTH")" ]]; then
    # Trae IDE sandbox mode - skip sync-out to avoid permission errors
    echo "📦 Sandbox режим: пропускаю синхронизацию конфигурации" >&2
    return 0
  fi

  # Standard sync-out pattern
  if [[ -f "$STATE_DIR/google_accounts.json" ]]; then
    cp "$STATE_DIR/google_accounts.json" "$GLOBAL_AUTH" 2>/dev/null || true
  fi

  if [[ -f "$STATE_DIR/settings.json" ]]; then
    cp "$STATE_DIR/settings.json" "$GLOBAL_SETTINGS" 2>/dev/null || true
  fi

  if [[ -f "$STATE_DIR/claude_config.json" ]]; then
    cp "$STATE_DIR/claude_config.json" "$CLAUDE_CONFIG" 2>/dev/null || true
  fi

  if [[ -f "$STATE_DIR/glm_config.json" ]]; then
    cp "$STATE_DIR/glm_config.json" "$GLM_CONFIG" 2>/dev/null || true
  fi

  # Sync-out Claude State (Expert Pattern: Manual Copy due to bind mount issues)
  # We use a temporary container to copy files from the volume/directory if needed,
  # but since we bind mount, we expect persistence.
  # If bind mount fails (as seen), we can't easily "copy out" from a dead container unless we kept it running.
  # STRATEGY CHANGE: We will rely on bind mounts but ensure the directory exists and has correct permissions.
  # If bind mount is absolutely broken in this env, we need to use 'docker cp' before removing the container.
}

# --- 3. EXPERT EPHEMERAL CONTAINER EXECUTION ---

function run_ephemeral_container() {
  local command="$1"
  shift

  # Expert Docker flags pattern
  local DOCKER_FLAGS="-i"
  if [ -t 1 ] && [ -z "$1" ]; then
    DOCKER_FLAGS="-it"
  fi

  # Smart image selection for AI providers
  local ai_image="claude-code-tools"
  # We use the unified image for both modes now

  # Ensure variables are set
  if [[ -z "${TARGET_DIR}" || -z "${CONTAINER_WORKDIR}" || -z "${STATE_DIR}" ]]; then
    echo "❌ Ошибка: переменные не установлены. Вызовите prepare_configuration() сначала." >&2
    return 1
  fi

  # Expert container execution pattern from old-scripts/gemini.zsh
  # Use direct entrypoint to bypass entrypoint.sh for system commands
  if [[ "$command" == "/bin/sh" || "$command" == "sh" || "$command" == "bash" || "$command" == "/bin/bash" ]]; then
    # DEBUG: Show command and env vars
    # echo "DEBUG: Running docker with project_id=$project_id" >&2
    # echo "DEBUG: Env vars: ${env_vars[@]}" >&2

    docker run $DOCKER_FLAGS --name "claude-session-$(date +%s)" \
      --entrypoint "$command" \
      --network host \
      -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
      -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
      -v "${SSH_KNOWN_HOSTS}":/root/.ssh/known_hosts \
      -v "${SSH_CONFIG_CLEAN}":/root/.ssh/config \
      -v "${GIT_CONFIG}":/root/.gitconfig \
      -v "${GIT_CONFIG}":/root/.gitconfig \
      -v "${GH_CONFIG_DIR}":/root/.config/gh \
      -v "${CLAUDE_STATE_DIR}":/root/.claude-config \
      -w "${CONTAINER_WORKDIR}" \
      -v "${TARGET_DIR}":"${CONTAINER_BASE_DIR}" \
      -v "${STATE_DIR}":/root/.gemini \
      "$ai_image" "$@"
  else
    # Set AI_MODE environment variable for proper provider selection
    local -a env_vars
    # Fix for ETIMEDOUT: Force IPv4 for Node.js applications (Claude & Gemini)
    env_vars+=("-e" "NODE_OPTIONS=--dns-result-order=ipv4first")

    if [[ "$command" == "glm" ]]; then
    # GLM Mode via Z.AI logic
      # ... (logic injected previously)
      local zai_key="${ZAI_API_KEY:-}"
      if [[ -z "$zai_key" && -f "$DOCKER_AI_CONFIG_HOME/global_state/secrets/zai_key" ]]; then
         zai_key=$(cat "$DOCKER_AI_CONFIG_HOME/global_state/secrets/zai_key")
      fi

      if [[ -z "$zai_key" ]]; then
         echo "❌ Ошибка: ZAI_API_KEY не найден." >&2
         echo "   Установите переменную окружения ZAI_API_KEY или сохраните ключ в secrets." >&2
         return 1
      fi

       local glm_settings_file="$GLM_STATE_DIR/settings.json"

       # Generate comprehensive settings.json based on Z.AI requirements
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
       # Duplicate as config.json just in case
       cp "$glm_settings_file" "$GLM_STATE_DIR/config.json"

        # FORCE AI_MODE=claude so entrypoint.sh launches claude binary
        env_vars+=("-e" "AI_MODE=claude")

        # INJECT ENV VARS FOR ROBUSTNESS (Double Tap)
        # Even if config file is ignored, these env vars will force the SDK to use Z.AI
        env_vars+=("-e" "ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic")
        env_vars+=("-e" "ANTHROPIC_API_KEY=$zai_key")

        local container_name="glm-session-$(date +%s)"
        local container_hostname="glm-dev-env"

        # EXACT CLONE OF CLAUDE MOUNT LOGIC
        # Mounting to /root/.claude-config because that's what works for Claude
        local active_state_dir="${GLM_STATE_DIR}"

        docker run $DOCKER_FLAGS --name "$container_name" \
          --hostname "$container_hostname" \
          --network host \
          "${env_vars[@]}" \
          -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
          -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
          -v "${SSH_KNOWN_HOSTS}":/root/.ssh/known_hosts \
          -v "${SSH_CONFIG_CLEAN}":/root/.ssh/config \
          -v "${GIT_CONFIG}":/root/.gitconfig \
          -v "${GH_CONFIG_DIR}":/root/.config/gh \
          -v "${active_state_dir}":/root/.claude-config \
          -w "${CONTAINER_WORKDIR}" \
          -v "${TARGET_DIR}":"${CONTAINER_BASE_DIR}" \
          -v "${STATE_DIR}":/root/.gemini \
          "$ai_image" "$@"

        local exit_code=$?

        echo "💾 Сохранение сессии GLM..." >&2
      mkdir -p "$GLM_STATE_DIR"
      chmod 755 "$GLM_STATE_DIR" 2>/dev/null || true
      if docker cp "$container_name":/root/.claude-config/. "$GLM_STATE_DIR/" >/dev/null 2>&1; then
         echo "✅ Сессия GLM успешно сохранена в $GLM_STATE_DIR" >&2
      else
         echo "⚠️ Ошибка сохранения сессии GLM." >&2
      fi

      docker rm -f "$container_name" >/dev/null 2>&1
      return $exit_code

    elif [[ "$command" == "claude" ]]; then
      env_vars+=("-e" "AI_MODE=claude")
      # ... rest of claude logic

      # Pass Claude API key if available
      if [[ -n "$CLAUDE_API_KEY" ]]; then
        env_vars+=("-e" "CLAUDE_API_KEY=$CLAUDE_API_KEY")
      fi
    elif [[ "$command" == "gemini" ]]; then
      env_vars=()
    fi

    # Set GOOGLE_CLOUD_PROJECT
    local project_id="${GOOGLE_CLOUD_PROJECT:-claude-code-docker-tools}"
    if [[ -n "$project_id" ]]; then
      env_vars+=("-e" "GOOGLE_CLOUD_PROJECT=$project_id")
    fi

    local container_name="claude-session-$(date +%s)"
    local container_hostname="claude-dev-env"

    docker run $DOCKER_FLAGS --name "$container_name" \
      --hostname "$container_hostname" \
      --network host \
      "${env_vars[@]}" \
      -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
      -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
      -v "${SSH_KNOWN_HOSTS}":/root/.ssh/known_hosts \
      -v "${SSH_CONFIG_CLEAN}":/root/.ssh/config \
      -v "${GIT_CONFIG}":/root/.gitconfig \
      -v "${GH_CONFIG_DIR}":/root/.config/gh \
      -v "${CLAUDE_STATE_DIR}":/root/.claude-config \
      -w "${CONTAINER_WORKDIR}" \
      -v "${TARGET_DIR}":"${CONTAINER_BASE_DIR}" \
      -v "${STATE_DIR}":/root/.gemini \
      --entrypoint "/bin/sh" \
      "$ai_image" -c "claude $@; echo '👋 Claude завершен. Запуск отладочного шелла...'; exec /bin/bash"

    local exit_code=$?

    # Expert Sync-Out: Manually copy config back to host
    # This bypasses bind mount issues by explicitly copying files
    if [[ "$command" == "claude" ]]; then
      echo "💾 Сохранение сессии Claude..." >&2
      mkdir -p "$CLAUDE_STATE_DIR"
      # Ensure destination directory has write permissions
      chmod 755 "$CLAUDE_STATE_DIR" 2>/dev/null || true

      # Copy content of .claude-config to host state dir
      # Note: using /. to copy contents, not directory itself
      if docker cp "$container_name":/root/.claude-config/. "$CLAUDE_STATE_DIR/" >/dev/null 2>&1; then
         echo "✅ Сессия успешно сохранена в $CLAUDE_STATE_DIR" >&2
      else
         echo "⚠️ Ошибка сохранения сессии. Проверьте права доступа." >&2
         # Try to copy individual files if bulk copy fails
         docker cp "$container_name":/root/.claude-config/.credentials.json "$CLAUDE_STATE_DIR/" >/dev/null 2>&1
      fi
    fi

    # Cleanup container
    # DEBUG MODE: Disabled. Production behavior restored.
    # For debugging, comment out the next line:
    # docker rm -f "$container_name" >/dev/null 2>&1
    echo "🐞 DEBUG: Контейнер сохранен для отладки: $container_name" >&2
    echo "   Для входа: docker exec -it $container_name /bin/bash" >&2
    echo "   Конфиги: /root/.claude-config" >&2
    echo "   Env: env | grep ANTHROPIC" >&2
    echo "   Для удаления: docker rm -f $container_name" >&2

    return $exit_code
  fi
}

# --- 4. EXPERT AI WRAPPER FUNCTIONS ---

function gemini() {
  ensure_docker_running
  ensure_ssh_loaded
  prepare_configuration

  local is_interactive=false
  if [ -t 1 ] && [ -z "$1" ]; then
    is_interactive=true
  fi

  # Check updates only in interactive mode
  if [[ "$is_interactive" == "true" ]]; then
    check_updates "interactive"
  fi

  run_ephemeral_container gemini "$@"
  local exit_code=$?

  cleanup_configuration

  if [[ "$is_interactive" == "true" && -n "$GIT_ROOT" ]]; then
    echo -e "\n👋 Сеанс Gemini завершен." >&2
  fi

  return $exit_code
}

function glm() {
  ensure_docker_running
  ensure_ssh_loaded
  prepare_configuration

  local is_interactive=false
  if [ -t 1 ] && [ -z "$1" ]; then
    is_interactive=true
  fi

  run_ephemeral_container glm "$@"
  local exit_code=$?

  cleanup_configuration

  if [[ "$is_interactive" == "true" && -n "$GIT_ROOT" ]]; then
    echo -e "\n👋 Сеанс GLM завершен." >&2
  fi

  return $exit_code
}

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
  prepare_configuration

  local is_interactive=false
  if [ -t 1 ] && [ -z "$1" ]; then
    is_interactive=true
  fi

  run_ephemeral_container claude "$@"
  local exit_code=$?

  cleanup_configuration

  if [[ "$is_interactive" == "true" && -n "$GIT_ROOT" ]]; then
    echo -e "\n👋 Сеанс Claude завершен." >&2
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
  prepare_configuration

  echo "🔧 Выполнение команды в AI окружении: $*" >&2

  # Special handling for shell commands - use /bin/sh
  if [[ "$1" == "/bin/sh" || "$1" == "sh" || "$1" == "bash" ]]; then
    run_ephemeral_container "$@"
    local exit_code=$?
  else
    # Default: execute as shell command
    run_ephemeral_container /bin/sh -c "$*"
    local exit_code=$?
  fi

  cleanup_configuration
  return $exit_code
}

function ai-mode() {
  local mode="${1:-}"

  case "$mode" in
    "gemini"|"g")
      echo "🧠 Переключаюсь в Gemini режим" >&2
      echo "Используйте: gemini [команда]" >&2
      ;;
    "claude"|"c")
      echo "🤖 Переключаюсь в Claude режим" >&2
      echo "Используйте: claude [команда]" >&2
      ;;
    "help"|"-h"|"--help"|"")
      echo "🤖 AI Assistant (Ephemeral Expert Architecture)"
      echo "Usage: ai-mode <gemini|claude> | gemini [args] | claude [args]"
      echo ""
      echo "Commands:"
      echo "  gemini     🚀 Gemini Code Assistant"
      echo "  claude     🤖 Claude Code Assistant"
      echo "  glm        🇨🇳 GLM-4.6 (Z.AI) Assistant"
      echo "    --native Указание флага запускает локальную версию"
      echo ""
      echo "  aic        📝 Gemini AI Commit"
      echo "  cic        📝 Claude AI Commit"
      echo "  gexec      ⚙️ Execute system command in container"
      echo ""
      ;;
    *)
      echo "❌ Неизвестный режим: $mode" >&2
      echo "Используйте: ai-mode [gemini|claude|help]" >&2
      return 1
      ;;
  esac
}

# --- 7. LEGACY SUPPORT (DEPRECATED) ---

function ai-session-manager() {
  echo "⚠️  ВНИМАНИЕ: ai-session-manager УСТАРЕЛ" >&2
  echo "✅ Используйте простые команды:" >&2
  echo "   • gemini     - для Gemini AI" >&2
  echo "   • claude     - для Claude AI" >&2
  echo "   • aic/cic    - для AI коммитов" >&2
  echo "   • gexec      - для команд в AI окружении" >&2
  echo "" >&2
  echo "Подробнее: ai-mode help" >&2
  return 1
}

# --- 8. INITIALIZATION ---

# Auto-completion
if [[ -n "$BASH_VERSION" ]]; then
  complete -W "gemini claude glm aic cic gexec ai-mode" ai-assistant 2>/dev/null || true
elif [[ -n "$ZSH_VERSION" ]]; then
  compdef _ai_assistant_completion gemini claude glm aic cic gexec ai-mode 2>/dev/null || true
fi

# Ensure we're in proper directory
# cd "$AI_TOOLS_HOME" 2>/dev/null || true

# Welcome message
if [[ "$1" != "--quiet" ]]; then
  echo "🚀 AI Assistant (Экспертная эфемерная архитектура)" >&2
  echo "💡 Используйте 'ai-mode help' для справки" >&2
fi
