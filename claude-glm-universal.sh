#!/bin/bash

# Универсальный запуск Claude Code с GLM из любой директории
set -e

# Поиск директории с проектом (ищем по наличию config/glm_config.json)
find_project_dir() {
    local current_dir="$(pwd)"
    local project_dir=""
    
    # Ищем вверх по дереву директорий
    while [[ "$current_dir" != "/" ]]; do
        if [[ -f "$current_dir/config/glm_config.json" ]] && [[ -f "$current_dir/claude-glm.sh" ]]; then
            project_dir="$current_dir"
            break
        fi
        current_dir="$(dirname "$current_dir")"
    done
    
    # Если не нашли, пробуем стандартные пути
    if [[ -z "$project_dir" ]]; then
        if [[ -f "$HOME/coding/projects/claude-code-docker-tools/config/glm_config.json" ]]; then
            project_dir="$HOME/coding/projects/claude-code-docker-tools"
        fi
    fi
    
    echo "$project_dir"
}

PROJECT_DIR=$(find_project_dir)

if [[ -z "$PROJECT_DIR" ]]; then
    echo "❌ Проект claude-code-docker-tools не найден"
    echo "Убедитесь что вы в директории проекта или запустите из поддиректории"
    exit 1
fi

CONFIG_DIR="$PROJECT_DIR/config"

# Проверка конфигурации
if [[ ! -f "$CONFIG_DIR/glm_config.json" ]]; then
    echo "❌ Конфигурация GLM не найдена: $CONFIG_DIR/glm_config.json"
    exit 1
fi

# Проверка существования образа
if ! docker image inspect glm-zai-claude &> /dev/null; then
    echo "❌ Образ glm-zai-claude не найден."
    echo "Сначала выполните: cd $PROJECT_DIR && ./install-claude.sh"
    exit 1
fi

echo "🚀 Запуск Claude Code с GLM..."
echo "📁 Проект: $PROJECT_DIR"
echo "🔧 Использую образ: glm-zai-claude"

# Определяем текущую рабочую директорию относительно контейнера
CURRENT_DIR="$(pwd)"
if [[ "$CURRENT_DIR" == "$PROJECT_DIR"* ]]; then
    # Мы внутри проекта - используем относительный путь
    REL_PATH="${CURRENT_DIR#$PROJECT_DIR}"
    if [[ -z "$REL_PATH" ]]; then
        WORKSPACE_PATH="/workspace"
    else
        WORKSPACE_PATH="/workspace$REL_PATH"
    fi
else
    # Мы вне проекта - используем корень проекта
    WORKSPACE_PATH="/workspace"
fi

# Запуск контейнера с Claude Code
echo "🔄 Запуск контейнера..."
echo "📂 Рабочая директория в контейнере: $WORKSPACE_PATH"

docker run --rm -it \
    --name claude-glm-session \
    -v "$PROJECT_DIR:/workspace" \
    -v "$CONFIG_DIR/glm_config.json:/home/aiuser/.config/glm_config.json" \
    -e ANTHROPIC_AUTH_TOKEN="$(jq -r '.ANTHROPIC_AUTH_TOKEN' "$CONFIG_DIR/glm_config.json")" \
    -e ANTHROPIC_BASE_URL="$(jq -r '.ANTHROPIC_BASE_URL' "$CONFIG_DIR/glm_config.json")" \
    -e ANTHROPIC_MODEL="glm-4.6" \
    -w "$WORKSPACE_PATH" \
    glm-zai-claude \
    bash -c "
        echo '🤖 Claude Code с GLM готов к работе!'
        echo '📁 Рабочая директория: $WORKSPACE_PATH'
        echo '🔧 GLM API: $(jq -r '.ANTHROPIC_BASE_URL' "$CONFIG_DIR/glm_config.json")'
        echo ''
        echo 'Доступные команды:'
        echo '  claude                    - запустить Claude Code'
        echo '  ls -la                    - посмотреть файлы проекта'
        echo '  pwd                       - текущая директория'
        echo '  exit                      - выход из контейнера'
        echo ''
        echo '💡 Все изменения сохраняются в вашей папке проекта!'
        echo ''
        exec bash
    "

echo "✅ Работа с Claude Code завершена"