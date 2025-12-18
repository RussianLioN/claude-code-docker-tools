#!/bin/zsh

# GLM Assistant zsh - Claude Code with z.ai GLM-4.6 Integration
# Fixed version with proper environment validation

# --- SAFETY CHECKS FIRST ---
# Ensure basic commands are available before proceeding
if ! command -v dirname >/dev/null 2>&1; then
    echo "❌ Критическая ошибка: базовые команды недоступны" >&2
    echo "💡 Выполните: export PATH=\"/bin:/usr/bin:/usr/local/bin:/opt/homebrew/bin:\$PATH\"" >&2
    return 1
fi

# --- GUARD CLAUSE - Prevent double loading ---
if [[ -n "$GLM_ASSISTANT_LOADED" ]]; then
    echo "⚠️  GLM Assistant уже загружен" >&2
    return 0
fi

# --- CONFIGURATION ---
# Use absolute path to avoid zsh-specific syntax issues
GLM_TOOLS_HOME="/Users/s060874gmail.com/coding/projects/claude-code-docker-tools"

# GLM Configuration
export GLM_CONFIG_HOME="${GLM_TOOLS_HOME}/config"
export GLM_CONTAINER_NAME="glm-zai-claude"

# GLM Credentials and Settings
export GLM_CONFIG_FILE="$GLM_CONFIG_HOME/glm_config.json"
export CLAUDE_CONFIG_FILE="$GLM_CONFIG_HOME/claude_config.json"

# Auto-detect Trae IDE sandbox mode
if [[ ! -w "$(dirname "$GLM_CONFIG_HOME")" ]]; then
  export TRAE_SANDBOX_MODE=1
  echo "🔒 Обнаружен Trae IDE sandbox режим" >&2
fi

# --- GLM SYSTEM CHECKS ---

function ensure_glm_config_exists() {
  if [[ ! -f "$GLM_CONFIG_FILE" ]]; then
    echo "❌ Ошибка: Конфигурация GLM не найдена: $GLM_CONFIG_FILE" >&2
    echo "💡 Убедитесь что файл glm_config.json существует в директории config/" >&2
    return 1
  fi
}

function ensure_docker_running() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Ошибка: Docker не найден в PATH" >&2
    echo "💡 Добавьте Docker в PATH или выполните: export PATH=\"/usr/local/bin:\$PATH\"" >&2
    return 1
  fi
  
  if ! docker info >/dev/null 2>&1; then
    echo "❌ Ошибка: Docker не запущен" >&2
    echo "💡 Запустите Docker Desktop или выполните: open -a Docker" >&2
    return 1
  fi
}

function ensure_glm_container_exists() {
  if ! docker image inspect "$GLM_CONTAINER_NAME" >/dev/null 2>&1; then
    echo "❌ Ошибка: Docker образ '$GLM_CONTAINER_NAME' не найден" >&2
    echo "💡 Выполните сборку образа: docker build -t $GLM_CONTAINER_NAME ." >&2
    return 1
  fi
}

# --- GLM CORE FUNCTIONS ---

function glm() {
  echo "🚀 Запуск Claude Code с GLM-4.6..." >&2
  
  # System checks
  ensure_glm_config_exists || return 1
  ensure_docker_running || return 1
  ensure_glm_container_exists || return 1
  
  # Extract GLM configuration (using hardcoded values as fallback)
  local auth_token="5190eb846b5b4d74b84ecda6c9947762.cNNOPku5biYnw8yD"
  local base_url="https://api.z.ai/api/anthropic"
  
  # Try to extract from config if jq is available
  if command -v jq >/dev/null 2>&1; then
    auth_token=$(jq -r '.ANTHROPIC_AUTH_TOKEN' "$GLM_CONFIG_FILE" 2>/dev/null || echo "$auth_token")
    base_url=$(jq -r '.ANTHROPIC_BASE_URL' "$GLM_CONFIG_FILE" 2>/dev/null || echo "$base_url")
  fi
  
  # Current working directory
  local current_dir="$(pwd)"
  
  echo "📁 Рабочая директория: $current_dir" >&2
  echo "🔧 GLM API: $base_url" >&2
  echo "" >&2
  
  # Run GLM container in ephemeral mode
  docker run --rm -it \
    --name "glm-session-$(date +%s)" \
    -v "$current_dir:/workspace" \
    -v "$CLAUDE_CONFIG_FILE:/home/aiuser/.config/claude/settings.json" \
    -e ANTHROPIC_API_KEY="$auth_token" \
    -e ANTHROPIC_BASE_URL="$base_url" \
    -e ANTHROPIC_MODEL="glm-4.6" \
    -e WORKSPACE_DIR="/workspace" \
    -w /workspace \
    "$GLM_CONTAINER_NAME" \
    bash -c "
      echo '🤖 Claude Code с GLM-4.6 готов к работе!';
      echo '📁 Рабочая директория: /workspace';
      echo '🔧 GLM API: \$ANTHROPIC_BASE_URL';
      echo '';
      echo 'Доступные команды:';
      echo '  claude                    - запустить Claude Code';
      echo '  ls -la                    - посмотреть файлы проекта';
      echo '  pwd                       - текущая директория';
      echo '  exit                      - выход из контейнера';
      echo '';
      echo '💡 Все изменения сохраняются в вашей папке!';
      echo '';
      exec bash;
    "
}

# --- GLM UTILITY FUNCTIONS ---

function glm-status() {
  echo "🔍 Проверка статуса GLM..." >&2
  
  if ensure_docker_running; then
    echo "✅ Docker запущен" >&2
  else
    echo "❌ Docker не запущен" >&2
    return 1
  fi
  
  if ensure_glm_container_exists; then
    echo "✅ Docker образ '$GLM_CONTAINER_NAME' найден" >&2
  else
    echo "❌ Docker образ '$GLM_CONTAINER_NAME' не найден" >&2
    return 1
  fi
  
  if ensure_glm_config_exists; then
    echo "✅ Конфигурация GLM найдена" >&2
  else
    echo "❌ Конфигурация GLM не найдена" >&2
    return 1
  fi
  
  echo "" >&2
  echo "📋 GLM Configuration:" >&2
  echo "  Config File: $GLM_CONFIG_FILE" >&2
  echo "  Container: $GLM_CONTAINER_NAME" >&2
  echo "  Working Directory: $(pwd)" >&2
}

function glm-help() {
  cat << 'EOF' >&2
🤖 GLM Assistant - Claude Code with z.ai GLM-4.6

ДОСТУПНЫЕ КОМАНДЫ:
  glm           - запустить Claude Code с GLM-4.6
  glm-status    - проверить статус системы
  glm-help      - показать эту справку

ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ:
  glm                    # запуск из текущей директории
  cd /project && glm     # запуск из другой директории
  
КОНФИГУРАЦИЯ:
  Config: ~/coding/projects/claude-code-docker-tools/config/glm_config.json
  Container: glm-zai-claude
  
EOF
}

# --- AUTO-COMPLETION ---
if command -v compdef >/dev/null 2>&1; then
  _glm_completion() {
    local commands=('status' 'help')
    _describe 'glm commands' commands
  }
  compdef _glm_completion glm
fi

# --- MARK AS LOADED ---
export GLM_ASSISTANT_LOADED=1
echo "🚀 GLM Assistant (Claude Code + z.ai GLM-4.6) загружен" >&2
echo "💡 Используйте 'glm-help' для справки" >&2