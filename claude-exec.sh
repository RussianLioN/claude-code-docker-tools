#!/bin/bash

# Простой запуск Claude Code через docker exec в существующем контейнере
set -euo pipefail

CONTAINER_NAME="glm-fix-session"
PROJECT_DIR="$(pwd)"

# Проверка, что контейнер запущен
if ! docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}" | grep -q "$CONTAINER_NAME"; then
    echo "❌ Контейнер $CONTAINER_NAME не запущен"
    echo "🚀 Запускаю контейнер..."
    
    docker run -d --name "$CONTAINER_NAME" \
        -v "$PROJECT_DIR:/workspace" \
        -v "$HOME/.claude:/home/aiuser/.claude:rw" \
        -w /workspace \
        glm-zai-claude:latest \
        tail -f /dev/null
    
    echo "⏳ Ожидаю запуск контейнера..."
    sleep 3
    
    # Исправление прав
    docker exec "$CONTAINER_NAME" chown -R aiuser:aiuser /home/aiuser/.claude
    docker exec "$CONTAINER_NAME" chmod -R 755 /home/aiuser/.claude
fi

echo "🤖 Запускаю Claude Code с GLM-4.6..."
echo "📁 Рабочая директория: /workspace"
echo "🔧 Конфигурация: z.ai API"
echo ""

# Запуск Claude Code с правильными переменными окружения
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