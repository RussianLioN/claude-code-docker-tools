#!/bin/bash

# Тестовый запуск GLM контейнера с одним сообщением
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$SCRIPT_DIR/workspaces"

MESSAGE="${1:-Привет! Как дела?}"

echo "🚀 Тестовый запуск GLM контейнера..."
echo "📝 Сообщение: $MESSAGE"

# Проверка существования образа
if ! docker image inspect glm-zai &> /dev/null; then
    echo "❌ Образ glm-zai не найден. Сначала выполните: ./run-glm-workspace.sh"
    exit 1
fi

# Создание рабочей директории
mkdir -p "$WORKSPACE_DIR/glm-workspace"

# Запуск контейнера с одним сообщением
docker run --rm \
    --name glm-zai-test \
    -v "$WORKSPACE_DIR/glm-workspace:/home/aiuser/workspace" \
    -e GLM_CONFIG_PATH=/home/aiuser/.config/glm_config.json \
    glm-zai \
    python3 /home/aiuser/interact.py "$MESSAGE"

echo "✅ Тест завершен"