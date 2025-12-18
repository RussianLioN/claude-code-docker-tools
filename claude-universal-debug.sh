#!/bin/bash

# Универсальный запуск Claude Code из любой директории с отладкой
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

echo "📦 Запускаю новый контейнер с переменными окружения..."
docker run -d --name "$CONTAINER_NAME" \
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
    glm-zai-claude:latest \
    tail -f /dev/null

echo "⏳ Ожидаю запуск контейнера..."
sleep 3

# Исправление прав
echo "🔧 Настраиваю права доступа..."
docker exec "$CONTAINER_NAME" chown -R aiuser:aiuser /home/aiuser/.claude >/dev/null 2>&1 || true
docker exec "$CONTAINER_NAME" chmod -R 755 /home/aiuser/.claude >/dev/null 2>&1 || true

# Копирование правильной конфигурации z.ai
echo "📋 Копирую настройки z.ai API..."
if [[ -f "$GLM_TOOLS_HOME/config/claude_config.json" ]]; then
    docker cp "$GLM_TOOLS_HOME/config/claude_config.json" "$CONTAINER_NAME:/home/aiuser/.claude/settings.json"
    echo "✅ Настройки z.ai скопированы"
elif [[ -f "$HOME/.claude/settings.json" ]]; then
    docker cp "$HOME/.claude/settings.json" "$CONTAINER_NAME:/home/aiuser/.claude/settings.json"
    echo "⚠️  Использованы локальные настройки"
else
    echo "❌ Настройки не найдены!"
fi

echo ""
echo "🔍 Отладочная информация:"
echo "📁 Рабочая директория: /workspace (сопоставлена с $PROJECT_DIR)"
echo "🏠 Домашняя директория в контейнере: /home/aiuser"
echo "⚙️  Директория Claude: /home/aiuser/.claude"
echo ""

# Запуск отладочной сессии
docker exec -it "$CONTAINER_NAME" bash -c "
    cd /workspace
    echo '🔍 Проверка переменных окружения:'
    echo 'ANTHROPIC_API_KEY=' \$ANTHROPIC_API_KEY
    echo 'ANTHROPIC_BASE_URL=' \$ANTHROPIC_BASE_URL  
    echo 'ANTHROPIC_MODEL=' \$ANTHROPIC_MODEL
    echo ''
    echo '📂 Проверка конфигурационных файлов:'
    echo 'Содержимое ~/.claude:'
    ls -la ~/.claude/
    echo ''
    echo 'Содержимое settings.json (первые 10 строк):'
    head -10 ~/.claude/settings.json 2>/dev/null || echo '❌ settings.json не найден!'
    echo ''
    echo '🔍 Проверка прав доступа:'
    ls -la ~/.claude/settings.json 2>/dev/null || echo '❌ Нет доступа к settings.json!'
    echo ''
    echo '💡 Для запуска Claude Code введите: claude'
    echo '💡 Для выхода из контейнера: exit'
    echo ''
    exec bash
"

echo ""
echo "✅ Контейнер $CONTAINER_NAME продолжает работать в фоновом режиме"
echo "💡 Чтобы остановить: docker stop $CONTAINER_NAME"
echo "💡 Чтобы подключиться снова: docker exec -it $CONTAINER_NAME bash"