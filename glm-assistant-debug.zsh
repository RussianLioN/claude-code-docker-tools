#!/bin/zsh

# GLM Assistant zsh - Claude Code with z.ai GLM-4.6 Integration
# Diagnostic version with configuration verification

# --- SAFETY CHECKS FIRST ---
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
GLM_TOOLS_HOME="/Users/s060874gmail.com/coding/projects/claude-code-docker-tools"
export GLM_CONFIG_HOME="${GLM_TOOLS_HOME}/config"
export GLM_CONTAINER_NAME="glm-zai-claude"
export GLM_CONFIG_FILE="$GLM_CONFIG_HOME/glm_config.json"
export CLAUDE_CONFIG_FILE="$GLM_CONFIG_HOME/claude_config.json"

# Auto-detect Trae IDE sandbox mode
if [[ ! -w "$(dirname "$GLM_CONFIG_HOME")" ]]; then
  export TRAE_SANDBOX_MODE=1
  echo "🔒 Обнаружен Trae IDE sandbox режим" >&2
fi

# --- SYSTEM CHECKS ---

function ensure_glm_config_exists() {
  if [[ ! -f "$GLM_CONFIG_FILE" ]]; then
    echo "❌ Ошибка: Конфигурация GLM не найдена: $GLM_CONFIG_FILE" >&2
    return 1
  fi
}

function ensure_docker_running() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Ошибка: Docker не найден в PATH" >&2
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

# --- CONFIGURATION VERIFICATION ---

function verify_claude_config() {
  echo "🔍 Проверка конфигурации Claude Code..." >&2
  
  if [[ ! -f "$CLAUDE_CONFIG_FILE" ]]; then
    echo "❌ Файл конфигурации Claude не найден: $CLAUDE_CONFIG_FILE" >&2
    return 1
  fi
  
  echo "✅ Файл конфигурации найден" >&2
  
  # Проверяем JSON синтаксис
  if command -v jq >/dev/null 2>&1; then
    if ! jq . "$CLAUDE_CONFIG_FILE" >/dev/null 2>&1; then
      echo "❌ Неверный JSON синтаксис в конфигурации" >&2
      return 1
    fi
    echo "✅ JSON синтаксис корректен" >&2
    
    # Показываем ключевые параметры
    echo "📋 Ключевые параметры:" >&2
    echo "  API Key: $(jq -r '.apiKey' "$CLAUDE_CONFIG_FILE" | head -c 20)..." >&2
    echo "  Base URL: $(jq -r '.baseUrl' "$CLAUDE_CONFIG_FILE")" >&2
    echo "  Model: $(jq -r '.model' "$CLAUDE_CONFIG_FILE")" >&2
  else
    echo "⚠️  jq не доступен, пропускаю проверку JSON" >&2
  fi
  
  return 0
}

# --- GLM FUNCTIONS ---

function glm() {
  echo "🚀 Запуск Claude Code с GLM-4.6..." >&2
  
  # System checks
  ensure_glm_config_exists || return 1
  ensure_docker_running || return 1
  ensure_glm_container_exists || return 1
  verify_claude_config || return 1
  
  # Extract configuration
  local auth_token="5190eb846b5b4d74b84ecda6c9947762.cNNOPku5biYnw8yD"
  local base_url="https://api.z.ai/api/anthropic"
  
  if command -v jq >/dev/null 2>&1; then
    auth_token=$(jq -r '.apiKey' "$CLAUDE_CONFIG_FILE" 2>/dev/null || echo "$auth_token")
    base_url=$(jq -r '.baseUrl' "$CLAUDE_CONFIG_FILE" 2>/dev/null || echo "$base_url")
  fi
  
  local current_dir="$(pwd)"
  
  echo "📁 Рабочая директория: $current_dir" >&2
  echo "🔧 GLM API: $base_url" >&2
  echo "" >&2
  
  # Запускаем контейнер с диагностикой
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
      echo '🔍 Диагностика в контейнере:';
      echo '  Текущая директория: \$(pwd)';
      echo '  Файл настроек Claude:';
      if [[ -f '/home/aiuser/.config/claude/settings.json' ]]; then
        echo '    ✅ Файл существует';
        echo '    📋 Содержимое (первые 5 строк):';
        head -5 '/home/aiuser/.config/claude/settings.json' | sed 's/^/      /';
      else
        echo '    ❌ Файл НЕ существует';
      fi;
      echo '';
      echo '  Переменные окружения:';
      env | grep ANTHROPIC | sed 's/^/    /';
      echo '';
      echo '🤖 Claude Code с GLM-4.6 готов к работе!';
      echo '📁 Рабочая директория: /workspace';
      echo '🔧 GLM API: \$ANTHROPIC_BASE_URL';
      echo '';
      echo '💡 ПРИМЕЧАНИЕ: Первый запуск Claude Code ВСЕГДА показывает мастер настройки!';
      echo '   Это нормальное поведение. После настройки он будет использовать GLM API.';
      echo '';
      echo 'Доступные команды:';
      echo '  claude                    - запустить Claude Code';
      echo '  ls -la                    - посмотреть файлы проекта';
      echo '  pwd                       - текущая директория';
      echo '  cat ~/.config/claude/settings.json  - проверить настройки';
      echo '  exit                      - выход из контейнера';
      echo '';
      echo '💡 Все изменения сохраняются в вашей папке!';
      echo '';
      exec bash;
    "
}

function glm-debug() {
  echo "🔍 Расширенная диагностика GLM..." >&2
  echo "" >&2
  
  # Проверяем все компоненты
  ensure_glm_config_exists || echo "❌ GLM конфигурация" >&2
  ensure_docker_running || echo "❌ Docker" >&2  
  ensure_glm_container_exists || echo "❌ Контейнер" >&2
  verify_claude_config || echo "❌ Claude конфигурация" >&2
  
  echo "" >&2
  echo "📋 Полная информация о системе:" >&2
  echo "  GLM Tools Home: $GLM_TOOLS_HOME" >&2
  echo "  GLM Config: $GLM_CONFIG_FILE" >&2
  echo "  Claude Config: $CLAUDE_CONFIG_FILE" >&2
  echo "  Container: $GLM_CONTAINER_NAME" >&2
  echo "  Current Dir: $(pwd)" >&2
  echo "  Docker Info: $(docker --version 2>/dev/null || echo 'N/A')" >&2
}

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
  glm-debug     - расширенная диагностика
  glm-status    - проверить статус системы
  glm-help      - показать эту справку

ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ:
  glm                    # запуск из текущей директории
  glm-debug              # диагностика перед запуском
  cd /project && glm     # запуск из другой директории
  
ВАЖНОЕ ЗАМЕЧАНИЕ:
  Первый запуск Claude Code ВСЕГДА показывает мастер настройки.
  Это нормальное поведение. После настройки он будет использовать GLM API.
  
КОНФИГУРАЦИЯ:
  Config: ~/coding/projects/claude-code-docker-tools/config/glm_config.json
  Claude Config: ~/coding/projects/claude-code-docker-tools/config/claude_config.json
  Container: glm-zai-claude
  
EOF
}

# --- AUTO-COMPLETION ---
if command -v compdef >/dev/null 2>&1; then
  _glm_completion() {
    local commands=('status' 'help' 'debug')
    _describe 'glm commands' commands
  }
  compdef _glm_completion glm
fi

# --- MARK AS LOADED ---
export GLM_ASSISTANT_LOADED=1
echo "🚀 GLM Assistant (Claude Code + z.ai GLM-4.6) загружен" >&2
echo "💡 Используйте 'glm-debug' для диагностики перед запуском" >&2