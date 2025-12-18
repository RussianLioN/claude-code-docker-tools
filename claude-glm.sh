#!/bin/bash

# Claude Code с GLM интеграцией - финальная версия
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$PROJECT_DIR/config"

echo "🚀 Запуск Claude Code с GLM..."
echo "📁 Проект: $PROJECT_DIR"
echo "🔧 Использую образ: glm-zai-claude"

# Проверка конфигурации
if [[ ! -f "$CONFIG_DIR/glm_config.json" ]]; then
    echo "❌ Конфигурация GLM не найдена: $CONFIG_DIR/glm_config.json"
    echo "Сначала выполните: cd $PROJECT_DIR && ./interactive-ai-manager.sh glm"
    exit 1
fi

# Извлечение параметров
AUTH_TOKEN=$(jq -r '.ANTHROPIC_AUTH_TOKEN' "$CONFIG_DIR/glm_config.json")
BASE_URL=$(jq -r '.ANTHROPIC_BASE_URL' "$CONFIG_DIR/glm_config.json")
MODEL=$(jq -r '.ANTHROPIC_MODEL' "$CONFIG_DIR/glm_config.json")

echo "🔄 Запуск контейнера с GLM-4.6..."
echo "🔗 API Endpoint: $BASE_URL"
echo "🤖 Модель: $MODEL"

docker run --rm -it \
    --name "claude-glm-session-$(date +%s)" \
    -v "$PROJECT_DIR:/workspace" \
    -e ANTHROPIC_API_KEY="$AUTH_TOKEN" \
    -e ANTHROPIC_BASE_URL="$BASE_URL" \
    -e ANTHROPIC_MODEL="$MODEL" \
    -e ANTHROPIC_DEFAULT_MODEL="$MODEL" \
    -e ANTHROPIC_DEFAULT_SONNET_MODEL="$MODEL" \
    -e ANTHROPIC_DEFAULT_OPUS_MODEL="$MODEL" \
    -e ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.5-air" \
    -e WORKSPACE_DIR="/workspace" \
    -w /workspace \
    glm-zai-claude \
    bash -c "
        echo '';
        echo '🤖 Claude Code с GLM-4.6 готов к работе!';
        echo '📁 Рабочая директория: /workspace';
        echo '🔗 GLM API: $BASE_URL';
        echo '🤖 Модель: $MODEL';
        echo '';
        echo '✅ Проверка соединения с GLM...';
        echo 'Какой моделью ты являешься?' | claude -p;
        echo '';
        echo '🎯 Доступные команды:';
        echo '  claude                    - запустить Claude Code интерактивно';
        echo '  claude -p \"текст\"        - задать вопрос в non-interactive режиме';
        echo '  ls -la                    - посмотреть файлы проекта';
        echo '  pwd                       - текущая директория';
        echo '  exit                      - выход из контейнера';
        echo '';
        echo '💡 Все изменения сохраняются в вашей папке проекта!';
        echo '';
        exec bash;
    "