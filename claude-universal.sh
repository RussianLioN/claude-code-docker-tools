#!/bin/bash

# Универсальный запуск Claude Code из любой директории
set -euo pipefail

CONTAINER_NAME="glm-universal-session"
PROJECT_DIR="$(pwd)"
GLM_TOOLS_HOME="/Users/s060874gmail.com/coding/projects/claude-code-docker-tools"

echo "🚀 Запуск Claude Code из директории: $PROJECT_DIR"

# Проверка Docker
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker не запущен. Запускаю Docker Desktop..."
    open -a Docker
    echo "⏳ Ожидаю запуска Docker..."
    sleep 10
fi

# Остановка старого контейнера
if docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}" | grep -q "$CONTAINER_NAME"; then
    echo "🧹 Останавливаю старый контейнер..."
    docker stop "$CONTAINER_NAME" >/dev/null
    docker rm "$CONTAINER_NAME" >/dev/null
fi

echo "📦 Запускаю новый контейнер..."
docker run -d --name "$CONTAINER_NAME" \
    -v "$PROJECT_DIR:/workspace" \
    -v "$HOME/.claude:/home/aiuser/.claude:rw" \
    -v "$GLM_TOOLS_HOME/config:/app/config:ro" \
    -w /workspace \
    glm-zai-claude:latest \
    tail -f /dev/null

echo "⏳ Ожидаю запуск контейнера..."
sleep 3

# Исправление прав
echo "🔧 Настраиваю права доступа..."
docker exec "$CONTAINER_NAME" chown -R aiuser:aiuser /home/aiuser/.claude >/dev/null 2>&1 || true
docker exec "$CONTAINER_NAME" chmod -R 755 /home/aiuser/.claude >/dev/null 2>&1 || true

# Копирование конфигурации если нужно
if docker exec "$CONTAINER_NAME" test ! -f /home/aiuser/.claude/settings.json; then
    if [[ -f "$HOME/.claude/settings.json" ]]; then
        echo "📋 Копирую настройки Claude..."
        docker cp "$HOME/.claude/settings.json" "$CONTAINER_NAME:/home/aiuser/.claude/settings.json"
    fi
fi

echo ""
echo "🤖 Запускаю Claude Code с GLM-4.6..."
echo "📁 Рабочая директория: /workspace (сопоставлена с $PROJECT_DIR)"
echo "🔧 Конфигурация: z.ai API"
echo ""

# Запуск Claude Code
docker exec -it "$CONTAINER_NAME" bash -c "
    cd /workspace
    export ANTHROPIC_API_KEY='5190eb846b5b4d74b84ecda6c9947762.cNNOPku5biYnw8yD'
    export ANTHROPIC_BASE_URL='https://api.z.ai/api/anthropic'
    export ANTHROPIC_MODEL='glm-4.6'
    export ANTHROPIC_DEFAULT_HAIKU_MODEL='glm-4.5-air'
    export ANTHROPIC_DEFAULT_OPUS_MODEL='glm-4.6'
    export ANTHROPIC_DEFAULT_SONNET_MODEL='glm-4.6'
    exec claude
"

echo ""
echo "✅ Контейнер $CONTAINER_NAME продолжает работать в фоновом режиме"
echo "💡 Чтобы остановить: docker stop $CONTAINER_NAME"