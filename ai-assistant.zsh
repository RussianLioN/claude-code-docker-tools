#!/bin/zsh

AI_TOOLS_HOME=${0:a:h}
SESSION_MANAGER_SCRIPT="${AI_TOOLS_HOME}/scripts/ai-session-manager.sh"

# --- 1. SYSTEM CHECKS ---

function ensure_docker_running() {
  if ! docker info > /dev/null 2>&1; then
    echo "🐳 Docker не запущен. Запускаю..." >&2
    open -a Docker
    while ! docker info > /dev/null 2>&1; do sleep 1; done
    echo "✅ Docker готов!" >&2
  fi
}

function ensure_ssh_loaded() {
  # Проверяем, есть ли ключи в агенте
  if ! ssh-add -l > /dev/null 2>&1; then
    # Если пусто - пробуем восстановить из Keychain
    ssh-add --apple-load-keychain > /dev/null 2>&1
    
    # Если все еще пусто
    if ! ssh-add -l > /dev/null 2>&1; then
       echo "⚠️  Внимание: SSH-агент пуст. Git внутри контейнера может не работать." >&2
    fi
  fi
}

function check_ai_update() {
  # Проверяем пинг (быстрый тест)
  if ping -c 1 -W 100 8.8.8.8 &> /dev/null; then
    local CURRENT_VER=$(docker run --rm --entrypoint gemini claude-code-tools --version 2>/dev/null)
    local LATEST_VER=$(curl -m 3 -s https://registry.npmjs.org/@google/gemini-cli/latest | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    
    if [[ -n "$LATEST_VER" && "$CURRENT_VER" != "$LATEST_VER" ]]; then
      echo "✨ \033[1;35mДоступно обновление Gemini CLI:\033[0m $CURRENT_VER -> $LATEST_VER" >&2
      echo "📦 Пересборка образа..." >&2
      docker build --build-arg GEMINI_VERSION=$LATEST_VER -t claude-code-tools "$AI_TOOLS_HOME" >&2
      echo "✅ Готово." >&2
    fi
  fi
}

function check_claude_update() {
  if ping -c 1 -W 100 8.8.8.8 &> /dev/null; then
    echo "🔍 Проверка обновлений Claude Code..." >&2
    # Здесь можно добавить проверку Claude CLI версии
  fi
}

# --- 2. MAIN WRAPPER ---

# --- 3. CLAUDE MODE ---

function claude() {
  local session_name=""
  local use_session=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session|-s)
        use_session=true
        session_name="${2:-}"
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done

  if [[ "$use_session" == "true" ]]; then
    if [[ -z "$session_name" ]]; then
      echo "❌ Имя сессии требуется при использовании --session"
      return 1
    fi

    # Start session if not running
    local session_status=$(ai-session status 2>/dev/null | grep "Running Instances" | awk '{print $3}')
    if [[ -z "$session_status" ]] || [[ "$session_status" == "0" ]]; then
      echo "🚀 Запуск сессии '$session_name' для Claude..."
      ai-session start "$session_name"
    fi

    echo "🔗 Claude работает в сессии: $session_name"
  fi

  # Original claude function logic
  ensure_docker_running
  ensure_ssh_loaded

  local GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  local TARGET_DIR
  local STATE_DIR
  local CLAUDE_CONFIG="$HOME/.docker-ai-config/claude_config.json"
  local GH_CONFIG_DIR="$HOME/.docker-ai-config/gh_config"
  local SSH_KNOWN_HOSTS="$HOME/.ssh/known_hosts"
  local GIT_CONFIG="$HOME/.gitconfig"
  local SSH_CONFIG_SRC="$HOME/.ssh/config"

  local IS_INTERACTIVE=false
  local DOCKER_FLAGS="-i"

  if [ -t 1 ] && [ -z "$1" ]; then
    DOCKER_FLAGS="-it"
    IS_INTERACTIVE=true
  fi

  if [[ "$IS_INTERACTIVE" == "true" ]]; then
    check_claude_update
  fi

  if [[ -n "$GIT_ROOT" ]]; then
    TARGET_DIR="$GIT_ROOT"
    STATE_DIR="$GIT_ROOT/.ai-state"
  else
    TARGET_DIR="$(pwd)"
    STATE_DIR="$HOME/.docker-ai-config/global_state"
  fi

  local PROJECT_NAME=$(basename "$TARGET_DIR")
  local CONTAINER_WORKDIR="/app/$PROJECT_NAME"

  mkdir -p "$STATE_DIR"
  mkdir -p "$GH_CONFIG_DIR"
  touch "$SSH_KNOWN_HOSTS"

  # SSH Sanitization
  local SSH_CONFIG_CLEAN="$STATE_DIR/ssh_config_clean"
  if [[ -f "$SSH_CONFIG_SRC" ]]; then
    grep -vE "UseKeychain|AddKeysToAgent|IdentityFile|IdentitiesOnly" "$SSH_CONFIG_SRC" > "$SSH_CONFIG_CLEAN"
  else
    touch "$SSH_CONFIG_CLEAN"
  fi

  # Claude конфигурация
  if [[ -f "$CLAUDE_CONFIG" ]]; then cp "$CLAUDE_CONFIG" "$STATE_DIR/claude_config.json"; fi

  # Add session info to container
  local SESSION_ENV=""
  if [[ "$use_session" == "true" ]]; then
    SESSION_ENV="-e AI_SESSION_NAME=$session_name"
  fi

  docker run $DOCKER_FLAGS --rm \
    --network host \
    $SESSION_ENV \
    -e AI_MODE=claude \
    -e CLAUDE_API_KEY="${CLAUDE_API_KEY:-}" \
    -e CLAUDE_MODEL="${CLAUDE_MODEL:-claude-3-5-sonnet-20241022}" \
    -e CLAUDE_MAX_TOKENS="${CLAUDE_MAX_TOKENS:-4096}" \
    -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
    -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
    -v "${SSH_KNOWN_HOSTS}":/root/.ssh/known_hosts \
    -v "${SSH_CONFIG_CLEAN}":/root/.ssh/config \
    -v "${GIT_CONFIG}":/root/.gitconfig \
    -v "${GH_CONFIG_DIR}":/root/.config/gh \
    -w "${CONTAINER_WORKDIR}" \
    -v "${TARGET_DIR}":"${CONTAINER_WORKDIR}" \
    -v "${STATE_DIR}":/root/.ai \
    claude-code-tools "$@"

  if [[ "$IS_INTERACTIVE" == "true" && -n "$GIT_ROOT" ]]; then
    echo -e "\n👋 Сеанс Claude завершен."
    cic  # Claude AI Commit
  fi
}

# --- 4. GEXEC ---

function gexec() {
  ensure_docker_running
  ensure_ssh_loaded

  local GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  local TARGET_DIR
  if [[ -n "$GIT_ROOT" ]]; then TARGET_DIR="$GIT_ROOT"; else TARGET_DIR="$(pwd)"; fi
  
  local PROJECT_NAME=$(basename "$TARGET_DIR")
  local CONTAINER_WORKDIR="/app/$PROJECT_NAME"
  
  local SSH_KNOWN_HOSTS="$HOME/.ssh/known_hosts"
  local GIT_CONFIG="$HOME/.gitconfig"
  local GH_CONFIG_DIR="$HOME/.docker-ai-config/gh_config"
  local SSH_CONFIG_SRC="$HOME/.ssh/config"
  local TMP_DIR="$HOME/.docker-ai-config/tmp_exec"
  mkdir -p "$TMP_DIR"
  local SSH_CONFIG_CLEAN="$TMP_DIR/ssh_config_clean"
  
  if [[ -f "$SSH_CONFIG_SRC" ]]; then
    grep -vE "UseKeychain|AddKeysToAgent|IdentityFile|IdentitiesOnly" "$SSH_CONFIG_SRC" > "$SSH_CONFIG_CLEAN"
  else
    touch "$SSH_CONFIG_CLEAN"
  fi

  docker run -it --rm \
    --entrypoint "" \
    --network host \
    -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
    -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
    -v "${SSH_KNOWN_HOSTS}":/root/.ssh/known_hosts \
    -v "${SSH_CONFIG_CLEAN}":/root/.ssh/config \
    -v "${GIT_CONFIG}":/root/.gitconfig \
    -v "${GH_CONFIG_DIR}":/root/.config/gh \
    -w "${CONTAINER_WORKDIR}" \
    -v "${TARGET_DIR}":"${CONTAINER_WORKDIR}" \
    claude-code-tools "$@"
}

# --- 5. AIC (Gemini AI Commit) ---

function aic() {
  ensure_docker_running
  ensure_ssh_loaded

  local GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$GIT_ROOT" ]]; then echo "❌ Не git-репозиторий"; return 1; fi
  
  cd "$GIT_ROOT"
  
  if ! grep -q ".ai-state" .gitignore 2>/dev/null; then
    echo "🛡  Безопасность: Добавляю .ai-state в .gitignore..."
    echo "" >> .gitignore
    echo "# AI Assistant State" >> .gitignore
    echo ".ai-state/" >> .gitignore
  fi
  
  git add .
  
  if ! git diff --staged --quiet; then
    local LOG_CONTENT=$(git log -n 10 --pretty=format:"%h | %an | %s")
    local DIFF_CONTENT=$(git diff --staged | head -c 100000)
    
    echo "🤖 Gemini анализирует изменения..." >&2
    
    local PROMPT="Act as a Senior DevOps Engineer.
    
    CONTEXT PART 1 (Project History):
    $LOG_CONTENT
    
    CONTEXT PART 2 (Current Changes):
    $DIFF_CONTENT
    
    TASK:
    Write a semantic Conventional Commit message for the changes in PART 2.
    Match the style of PART 1.
    Output ONLY the raw commit message string. No markdown, no quotes."
    
    local MSG=$(gemini "$PROMPT" | sed 's/```//g' | sed 's/"//g' | tr -d '\r')
    MSG=$(echo "$MSG" | sed -e 's/^[[:space:]]*//')

    echo -e "\n📝 \033[1;32mПредложенный коммит:\033[0m"
    echo "---------------------------------------------------"
    echo "$MSG"
    echo "---------------------------------------------------"
    
    echo "🚀 Действия: [Enter]=Push, [c]=Commit, [n]=Cancel"
    echo -n "Ваш выбор: "
    read ACTION
    ACTION=${ACTION:-y}

    if [[ "$ACTION" == "y" || "$ACTION" == "Y" ]]; then
      git commit -m "$MSG"
      echo "☁️ Auto-Push..."
      
      local REMOTE_URL=$(git config --get remote.origin.url)
      if [[ "$REMOTE_URL" == https* ]]; then
         echo "⚠️  HTTPS Remote detected. Auth may fail inside Docker." >&2
      fi
      
      gexec git push
    elif [[ "$ACTION" == "c" || "$ACTION" == "C" ]]; then
      git commit -m "$MSG"
      echo "✅ Saved locally."
    else
      echo "❌ Cancelled."
    fi
    return
  fi

  local UNPUSHED_COUNT=$(git log @{u}..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$UNPUSHED_COUNT" -gt 0 ]]; then
    echo -e "\n⚡️ \033[1;33mОбнаружено $UNPUSHED_COUNT неотправленных коммитов.\033[0m"
    git log @{u}..HEAD --oneline --color | head -n 5
    echo -n "🚀 Выполнить git push сейчас? [Y/n]: "
    read PUSH_CONFIRM
    PUSH_CONFIRM=${PUSH_CONFIRM:-y}
    if [[ "$PUSH_CONFIRM" == "y" || "$PUSH_CONFIRM" == "Y" ]]; then echo "☁️ Pushing..."; gexec git push; else echo "🏠 Оставлено локально."; fi
  fi
}

# --- 6. CIC (Claude AI Commit) ---

function cic() {
  ensure_docker_running
  ensure_ssh_loaded

  local GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$GIT_ROOT" ]]; then echo "❌ Не git-репозиторий"; return 1; fi
  
  cd "$GIT_ROOT"
  
  if ! grep -q ".ai-state" .gitignore 2>/dev/null; then
    echo "🛡  Безопасность: Добавляю .ai-state в .gitignore..."
    echo "" >> .gitignore
    echo "# AI Assistant State" >> .gitignore
    echo ".ai-state/" >> .gitignore
  fi
  
  git add .
  
  if ! git diff --staged --quiet; then
    local LOG_CONTENT=$(git log -n 10 --pretty=format:"%h | %an | %s")
    local DIFF_CONTENT=$(git diff --staged | head -c 100000)
    
    echo "🤖 Claude анализирует изменения..." >&2
    
    local PROMPT="Act as a Senior Software Engineer specializing in modern development practices.
    
    CONTEXT PART 1 (Project History):
    $LOG_CONTENT
    
    CONTEXT PART 2 (Current Changes):
    $DIFF_CONTENT
    
    TASK:
    Write a clear, descriptive commit message following conventional commit format.
    Focus on what changed and why, using the style from PART 1.
    Output ONLY the raw commit message. No markdown formatting, no quotes."
    
    local MSG=$(claude "$PROMPT" | sed 's/```//g' | sed 's/"//g' | tr -d '\r')
    MSG=$(echo "$MSG" | sed -e 's/^[[:space:]]*//')

    echo -e "\n📝 \033[1;34mПредложенный коммит (Claude):\033[0m"
    echo "---------------------------------------------------"
    echo "$MSG"
    echo "---------------------------------------------------"
    
    echo "🚀 Действия: [Enter]=Push, [c]=Commit, [n]=Cancel"
    echo -n "Ваш выбор: "
    read ACTION
    ACTION=${ACTION:-y}

    if [[ "$ACTION" == "y" || "$ACTION" == "Y" ]]; then
      git commit -m "$MSG"
      echo "☁️ Auto-Push..."
      
      local REMOTE_URL=$(git config --get remote.origin.url)
      if [[ "$REMOTE_URL" == https* ]]; then
         echo "⚠️  HTTPS Remote detected. Auth may fail inside Docker." >&2
      fi
      
      gexec git push
    elif [[ "$ACTION" == "c" || "$ACTION" == "C" ]]; then
      git commit -m "$MSG"
      echo "✅ Saved locally."
    else
      echo "❌ Cancelled."
    fi
    return
  fi

  local UNPUSHED_COUNT=$(git log @{u}..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$UNPUSHED_COUNT" -gt 0 ]]; then
    echo -e "\n⚡️ \033[1;33mОбнаружено $UNPUSHED_COUNT неотправленных коммитов.\033[0m"
    git log @{u}..HEAD --oneline --color | head -n 5
    echo -n "🚀 Выполнить git push сейчас? [Y/n]: "
    read PUSH_CONFIRM
    PUSH_CONFIRM=${PUSH_CONFIRM:-y}
    if [[ "$PUSH_CONFIRM" == "y" || "$PUSH_CONFIRM" == "Y" ]]; then echo "☁️ Pushing..."; gexec git push; else echo "🏠 Оставлено локально."; fi
  fi
}

# --- 7. AI MODE SWITCHER ---

function ai-mode() {
  case "$1" in
    gemini|g)
      echo "🧠 Переключение в Gemini режим"
      export AI_CURRENT_MODE="gemini"
      ;;
    claude|c)
      echo "🤖 Переключение в Claude режим"
      export AI_CURRENT_MODE="claude"
      ;;
    "")
      echo "Текущий режим: ${AI_CURRENT_MODE:-gemini}"
      echo "Доступные режимы: gemini, claude"
      ;;
    *)
      echo "Неизвестный режим: $1"
      echo "Доступные: gemini, claude"
      ;;
  esac
}

# --- 8. SESSION MANAGEMENT ---

function ai-session() {
  if [[ ! -f "$SESSION_MANAGER_SCRIPT" ]]; then
    echo "❌ Session Manager not found: $SESSION_MANAGER_SCRIPT"
    return 1
  fi

  "$SESSION_MANAGER_SCRIPT" "$@"
}

function ai-start() {
  local session_name="${1:-}"
  if [[ -z "$session_name" ]]; then
    echo "Использование: ai-start <имя-сессии>"
    return 1
  fi

  ai-session start "$session_name"
}

function ai-stop() {
  local session_name="${1:-}"
  if [[ -z "$session_name" ]]; then
    echo "Использование: ai-stop <имя-сессии>"
    return 1
  fi

  ai-session stop "$session_name"
}

function ai-list() {
  ai-session list
}

function ai-status() {
  ai-session status
}

function ai-restart() {
  local session_name="${1:-}"
  if [[ -z "$session_name" ]]; then
    echo "Использование: ai-restart <имя-сессии>"
    return 1
  fi

  ai-session restart "$session_name"
}

function ai-cleanup() {
  ai-session cleanup
}

# Enhanced gemini/claude functions with session support
function gemini() {
  local session_name=""
  local use_session=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session|-s)
        use_session=true
        session_name="${2:-}"
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done

  if [[ "$use_session" == true ]]; then
    if [[ -z "$session_name" ]]; then
      echo "❌ Имя сессии требуется при использовании --session"
      return 1
    fi

    # Start session if not running
    local session_status=$(ai-session status 2>/dev/null | grep "Running Instances" | awk '{print $3}')
    if [[ -z "$session_status" ]] || [[ "$session_status" == "0" ]]; then
      echo "🚀 Запуск сессии '$session_name' для Gemini..."
      ai-session start "$session_name"
    fi

    echo "🔗 Gemini работает в сессии: $session_name"
  fi

  # Original gemini function logic
  ensure_docker_running
  ensure_ssh_loaded

  local GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  local TARGET_DIR
  local STATE_DIR
  local GLOBAL_AUTH="$HOME/.docker-ai-config/google_accounts.json"
  local GLOBAL_SETTINGS="$HOME/.docker-ai-config/settings.json"
  local CLAUDE_CONFIG="$HOME/.docker-ai-config/claude_config.json"
  local GH_CONFIG_DIR="$HOME/.docker-ai-config/gh_config"
  local SSH_KNOWN_HOSTS="$HOME/.ssh/known_hosts"
  local GIT_CONFIG="$HOME/.gitconfig"
  local SSH_CONFIG_SRC="$HOME/.ssh/config"

  local IS_INTERACTIVE=false
  local DOCKER_FLAGS="-i"

  if [ -t 1 ] && [ -z "$1" ]; then
    DOCKER_FLAGS="-it"
    IS_INTERACTIVE=true
  fi

  # ИСПРАВЛЕНИЕ: Проверка обновлений ТОЛЬКО в интерактивном режиме
  if [[ "$IS_INTERACTIVE" == "true" ]]; then
    check_ai_update
  fi

  if [[ -n "$GIT_ROOT" ]]; then
    TARGET_DIR="$GIT_ROOT"
    STATE_DIR="$GIT_ROOT/.ai-state"
  else
    TARGET_DIR="$(pwd)"
    STATE_DIR="$HOME/.docker-ai-config/global_state"
  fi

  local PROJECT_NAME=$(basename "$TARGET_DIR")
  local CONTAINER_WORKDIR="/app/$PROJECT_NAME"

  mkdir -p "$STATE_DIR"
  mkdir -p "$GH_CONFIG_DIR"
  touch "$SSH_KNOWN_HOSTS"

  # SSH Sanitization
  local SSH_CONFIG_CLEAN="$STATE_DIR/ssh_config_clean"
  if [[ -f "$SSH_CONFIG_SRC" ]]; then
    grep -vE "UseKeychain|AddKeysToAgent|IdentityFile|IdentitiesOnly" "$SSH_CONFIG_SRC" > "$SSH_CONFIG_CLEAN"
  else
    touch "$SSH_CONFIG_CLEAN"
  fi

  if [[ -f "$GLOBAL_AUTH" ]]; then cp "$GLOBAL_AUTH" "$STATE_DIR/google_accounts.json"; fi
  if [[ -f "$GLOBAL_SETTINGS" ]]; then cp "$GLOBAL_SETTINGS" "$STATE_DIR/settings.json"; fi

  # Add session info to container
  local SESSION_ENV=""
  if [[ "$use_session" == true ]]; then
    SESSION_ENV="-e AI_SESSION_NAME=$session_name"
  fi

  docker run $DOCKER_FLAGS --rm \
    --network host \
    $SESSION_ENV \
    -e GOOGLE_CLOUD_PROJECT=gemini-cli-auth-478707 \
    -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
    -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
    -v "${SSH_KNOWN_HOSTS}":/root/.ssh/known_hosts \
    -v "${SSH_CONFIG_CLEAN}":/root/.ssh/config \
    -v "${GIT_CONFIG}":/root/.gitconfig \
    -v "${GH_CONFIG_DIR}":/root/.config/gh \
    -w "${CONTAINER_WORKDIR}" \
    -v "${TARGET_DIR}":"${CONTAINER_WORKDIR}" \
    -v "${STATE_DIR}":/root/.ai \
    claude-code-tools "$@"

  if [[ -f "$STATE_DIR/google_accounts.json" ]]; then cp "$STATE_DIR/google_accounts.json" "$GLOBAL_AUTH"; fi
  if [[ -f "$STATE_DIR/settings.json" ]]; then cp "$STATE_DIR/settings.json" "$GLOBAL_SETTINGS"; fi

  if [[ "$IS_INTERACTIVE" == "true" && -n "$GIT_ROOT" ]]; then
    echo -e "\n👋 Сеанс Gemini завершен."
    aic
  fi
}
