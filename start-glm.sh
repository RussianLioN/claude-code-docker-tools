#!/bin/bash

# Простой запуск GLM контейнера в интерактивном режиме
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$SCRIPT_DIR/workspaces"

echo "🚀 Запуск GLM контейнера в интерактивном режиме..."

# Проверка существования образа
if ! docker image inspect glm-zai &> /dev/null; then
    echo "❌ Образ glm-zai не найден. Сначала выполните: ./run-glm-workspace.sh"
    exit 1
fi

# Создание рабочей директории
mkdir -p "$WORKSPACE_DIR/glm-workspace"

# Запуск контейнера
docker run -it --rm \
    --name glm-zai-interactive \
    -v "$WORKSPACE_DIR/glm-workspace:/home/aiuser/workspace" \
    -e GLM_CONFIG_PATH=/home/aiuser/.config/glm_config.json \
    glm-zai \
    python3 /home/aiuser/interact.py

echo "✅ Работа с GLM контейнером завершена"