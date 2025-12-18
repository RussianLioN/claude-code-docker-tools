#!/bin/bash

# Claude Code + GLM Container Runner с правильными правами доступа
set -euo pipefail

# Конфигурация
GLM_IMAGE="glm-zai-claude:latest"
PROJECT_DIR="$(pwd)"
TIMESTAMP=$(date +%s)
CONTAINER_NAME="glm-session-${TIMESTAMP}"
GLM_TOOLS_HOME="/Users/s060874gmail.com/coding/projects/claude-code-docker-tools"

# Проверка Docker
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker не запущен. Запускаю Docker Desktop..."
    open -a Docker
    echo "⏳ Ожидаю запуска Docker..."
    sleep 10
fi

# Проверка образа
if ! docker image inspect "$GLM_IMAGE" >/dev/null 2>&1; then
    echo "❌ Образ $GLM_IMAGE не найден"
    echo "💡 Сначала соберите образ: cd $GLM_TOOLS_HOME && docker build -t $GLM_IMAGE ."
    exit 1
fi

# Создание бэкапа ~/.claude
BACKUP_DIR="$HOME/.claude.backup.$(date +%Y%m%d_%H%M%S)"
if [[ -d "$HOME/.claude" ]]; then
    echo "🔄 Создаю бэкап ~/.claude в $BACKUP_DIR"
    cp -r "$HOME/.claude" "$BACKUP_DIR"
fi

# Остановка старых контейнеров
echo "🧹 Останавливаю старые GLM контейнеры..."
docker ps -q --filter "name=glm-session" | xargs -r docker stop

echo "🚀 Запускаю Claude Code с GLM в контейнере $CONTAINER_NAME..."

# Запуск контейнера с правильными правами и volume mapping
docker run -it --rm \
    --name "$CONTAINER_NAME" \
    --user "$(id -u):$(id -g)" \
    -v "$PROJECT_DIR:/workspace" \
    -v "$HOME/.claude:/home/aiuser/.claude:rw" \
    -v "$GLM_TOOLS_HOME/config:/app/config:ro" \
    -e ANTHROPIC_API_KEY="5190eb846b5b4d74b84ecda6c9947762.cNNOPku5biYnw8yD" \
    -e ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic" \
    -e ANTHROPIC_MODEL="glm-4.6" \
    -e ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.5-air" \
    -e ANTHROPIC_DEFAULT_OPUS_MODEL="glm-4.6" \
    -e ANTHROPIC_DEFAULT_SONNET_MODEL="glm-4.6" \
    -w /workspace \
    "$GLM_IMAGE" \
    /bin/bash -c "
        # Установка правильных прав
        if [[ -d /home/aiuser/.claude ]]; then
            find /home/aiuser/.claude -type d -exec chmod 755 {} \;
            find /home/aiuser/.claude -type f -exec chmod 644 {} \;
        fi
        
        # Копирование конфигурации если отсутствует
        if [[ ! -f /home/aiuser/.claude/settings.json ]] && [[ -f /app/config/claude_config.json ]]; then
            cp /app/config/claude_config.json /home/aiuser/.claude/settings.json
        fi
        
        # Запуск Claude Code
        echo '🤖 Запускаю Claude Code с GLM-4.6...'
        echo '📁 Рабочая директория: /workspace'
        echo '🔧 Конфигурация: z.ai API'
        echo ''
        exec claude
    "

echo "✅ Контейнер $CONTAINER_NAME остановлен"