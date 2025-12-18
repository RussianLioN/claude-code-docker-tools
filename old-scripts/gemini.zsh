#!/bin/zsh

GEMINI_TOOLS_HOME=${0:a:h}

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

function check_gemini_update() {
  # Проверяем пинг (быстрый тест)
  if ping -c 1 -W 100 8.8.8.8 &> /dev/null; then
    local CURRENT_VER=$(docker run --rm --entrypoint gemini gemini-cli --version 2>/dev/null)
    local LATEST_VER=$(curl -m 3 -s https://registry.npmjs.org/@google/gemini-cli/latest | grep -o '"version":"[^"]*"' | cut -d'"' -f4)

    if [[ -n "$LATEST_VER" && "$CURRENT_VER" != "$LATEST_VER" ]]; then
      echo "✨ \033[1;35mДоступно обновление Gemini CLI:\033[0m $CURRENT_VER -> $LATEST_VER" >&2
      echo "📦 Пересборка образа..." >&2
      docker build --build-arg GEMINI_VERSION=$LATEST_VER -t gemini-cli "$GEMINI_TOOLS_HOME" >&2
      echo "✅ Готово." >&2
    fi
  fi
}

# --- 2. MAIN WRAPPER ---

function gemini() {
  ensure_docker_running
  ensure_ssh_loaded

  local GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  local TARGET_DIR
  local STATE_DIR
  local GLOBAL_AUTH="$HOME/.docker-gemini-config/google_accounts.json"
  local GLOBAL_SETTINGS="$HOME/.docker-gemini-config/settings.json"
  local GH_CONFIG_DIR="$HOME/.docker-gemini-config/gh_config"
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
    check_gemini_update
  fi

  if [[ -n "$GIT_ROOT" ]]; then
    TARGET_DIR="$GIT_ROOT"
    STATE_DIR="$GIT_ROOT/.gemini-state"
  else
    TARGET_DIR="$(pwd)"
    STATE_DIR="$HOME/.docker-gemini-config/global_state"
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

  docker run $DOCKER_FLAGS --rm \
    --network host \
    -e GOOGLE_CLOUD_PROJECT=gemini-cli-auth-478707 \
    -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
    -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
    -v "${SSH_KNOWN_HOSTS}":/root/.ssh/known_hosts \
    -v "${SSH_CONFIG_CLEAN}":/root/.ssh/config \
    -v "${GIT_CONFIG}":/root/.gitconfig \
    -v "${GH_CONFIG_DIR}":/root/.config/gh \
    -w "${CONTAINER_WORKDIR}" \
    -v "${TARGET_DIR}":"${CONTAINER_WORKDIR}" \
    -v "${STATE_DIR}":/root/.gemini \
    gemini-cli "$@"

  if [[ -f "$STATE_DIR/google_accounts.json" ]]; then cp "$STATE_DIR/google_accounts.json" "$GLOBAL_AUTH"; fi
  if [[ -f "$STATE_DIR/settings.json" ]]; then cp "$STATE_DIR/settings.json" "$GLOBAL_SETTINGS"; fi

  if [[ "$IS_INTERACTIVE" == "true" && -n "$GIT_ROOT" ]]; then
    echo -e "\n👋 Сеанс завершен."
    aic
  fi
}

# --- 3. GEXEC ---

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
  local GH_CONFIG_DIR="$HOME/.docker-gemini-config/gh_config"
  local SSH_CONFIG_SRC="$HOME/.ssh/config"
  local TMP_DIR="$HOME/.docker-gemini-config/tmp_exec"
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
    gemini-cli "$@"
}

# --- 4. AIC ---

function aic() {
  ensure_docker_running
  ensure_ssh_loaded

  local GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$GIT_ROOT" ]]; then echo "❌ Не git-репозиторий"; return 1; fi

  cd "$GIT_ROOT"

  if ! grep -q ".gemini-state" .gitignore 2>/dev/null; then
    echo "🛡  Безопасность: Добавляю .gemini-state в .gitignore..."
    echo "" >> .gitignore
    echo "# Gemini AI Context" >> .gitignore
    echo ".gemini-state/" >> .gitignore
  fi

  git add .

  if ! git diff --staged --quiet; then
    # Проверяем значимость изменений (более 5 символов)
    local CHANGES_SIZE=$(git diff --staged --stat | tail -1 | grep -o '[0-9]\+' | head -1)
    if [[ -n "$CHANGES_SIZE" && "$CHANGES_SIZE" -lt 5 ]]; then
      echo "⚠️ Слишком малые изменения ($CHANGES_SIZE символов), пропускаем анализ..."
      return
    fi

    local LOG_CONTENT=$(git log -n 10 --pretty=format:"%h | %an | %s")
    local DIFF_CONTENT=$(git diff --staged | head -c 100000)

    echo "🤖 Анализирую изменения..." >&2

    local PROMPT="Act as a Senior DevOps Engineer.

    CONTEXT PART 1 (Project History):
    $LOG_CONTENT

    CONTEXT PART 2 (Current Changes):
    $DIFF_CONTENT

    TASK:
    Write a semantic Conventional Commit message for the changes in PART 2.
    Match the style of PART 1.
    Output ONLY the raw commit message string. No markdown, no quotes."

    # ИСПРАВЛЕНИЕ: Вызываем gemini напрямую через Docker с правильной аутентификацией
    local STATE_DIR="$GIT_ROOT/.gemini-state"
    local GLOBAL_AUTH="$HOME/.docker-gemini-config/google_accounts.json"
    local GLOBAL_SETTINGS="$HOME/.docker-gemini-config/settings.json"
    local CONTAINER_WORKDIR="/app/$(basename "$GIT_ROOT")"

    mkdir -p "$STATE_DIR"

    if [[ -f "$GLOBAL_AUTH" ]]; then cp "$GLOBAL_AUTH" "$STATE_DIR/google_accounts.json"; fi
    if [[ -f "$GLOBAL_SETTINGS" ]]; then cp "$GLOBAL_SETTINGS" "$STATE_DIR/settings.json"; fi

    local MSG=$(docker run -i --rm \
      --network host \
      -e GOOGLE_CLOUD_PROJECT=gemini-cli-auth-478707 \
      -w "${CONTAINER_WORKDIR}" \
      -v "${GIT_ROOT}":"${CONTAINER_WORKDIR}" \
      -v "${STATE_DIR}":/root/.gemini \
      gemini-cli "$PROMPT" | sed 's/```//g' | sed 's/"//g' | tr -d '\r')

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
