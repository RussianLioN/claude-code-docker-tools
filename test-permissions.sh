#!/bin/bash

# Тестовый скрипт для проверки прав доступа в контейнере
set -euo pipefail

GLM_IMAGE="glm-zai-claude:latest"
PROJECT_DIR="$(pwd)"

echo "🧪 Тестирую права доступа в контейнере..."

docker run --rm \
    -v "$PROJECT_DIR:/workspace" \
    -v "$HOME/.claude:/home/aiuser/.claude:rw" \
    -w /workspace \
    "$GLM_IMAGE" \
    /bin/bash -c "
        echo '📊 Информация о пользователе:'
        whoami
        id
        echo ''
        
        echo '📁 Проверка домашней директории:'
        ls -la /home/aiuser/
        echo ''
        
        echo '📂 Проверка .claude директории:'
        if [[ -d /home/aiuser/.claude ]]; then
            ls -la /home/aiuser/.claude/
            echo ''
            echo '✅ .claude директория существует'
            
            echo '🔍 Проверка прав на запись:'
            if touch /home/aiuser/.claude/test_write_$$; then
                echo '✅ Запись в .claude работает'
                rm -f /home/aiuser/.claude/test_write_$$
            else
                echo '❌ Ошибка записи в .claude'
            fi
            
            echo '🔍 Проверка создания поддиректории:'
            if mkdir /home/aiuser/.claude/test_dir_$$ 2>/dev/null; then
                echo '✅ Создание поддиректорий работает'
                rmdir /home/aiuser/.claude/test_dir_$$
            else
                echo '❌ Ошибка создания поддиректорий'
            fi
        else
            echo '❌ .claude директория не существует'
        fi
        
        echo ''
        echo '📂 Проверка workspace:'
        ls -la /workspace/
    "

echo "🏁 Тест завершен"