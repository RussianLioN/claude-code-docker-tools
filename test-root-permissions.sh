#!/bin/bash

# Тестовый скрипт для проверки прав доступа в контейнере от root
set -euo pipefail

GLM_IMAGE="glm-zai-claude:latest"
PROJECT_DIR="$(pwd)"

echo "🧪 Тестирую права доступа в контейнере от root..."

docker run --rm \
    -v "$PROJECT_DIR:/workspace" \
    -v "$HOME/.claude:/root/.claude:rw" \
    -w /workspace \
    "$GLM_IMAGE" \
    /bin/bash -c "
        echo '📊 Информация о пользователе:'
        whoami
        id
        echo ''
        
        echo '📁 Проверка домашней директории:'
        ls -la /root/
        echo ''
        
        echo '📂 Проверка .claude директории:'
        if [[ -d /root/.claude ]]; then
            ls -la /root/.claude/
            echo ''
            echo '✅ .claude директория существует'
            
            echo '🔍 Проверка прав на запись:'
            if touch /root/.claude/test_write_$$; then
                echo '✅ Запись в .claude работает'
                rm -f /root/.claude/test_write_$$
            else
                echo '❌ Ошибка записи в .claude'
            fi
            
            echo '🔍 Проверка создания поддиректории:'
            if mkdir /root/.claude/test_dir_$$ 2>/dev/null; then
                echo '✅ Создание поддиректорий работает'
                rmdir /root/.claude/test_dir_$$
            else
                echo '❌ Ошибка создания поддиректорий'
            fi
            
            echo '🔍 Проверка создания session-env директории:'
            if mkdir -p /root/.claude/session-env/test_$$ 2>/dev/null; then
                echo '✅ Создание session-env работает'
                rmdir /root/.claude/session-env/test_$$
            else
                echo '❌ Ошибка создания session-env'
            fi
            
            echo '🔍 Проверка создания projects директории:'
            if mkdir -p /root/.claude/projects/test_$$ 2>/dev/null; then
                echo '✅ Создание projects работает'
                rmdir /root/.claude/projects/test_$$
            else
                echo '❌ Ошибка создания projects'
            fi
        else
            echo '❌ .claude директория не существует'
        fi
        
        echo ''
        echo '📂 Проверка workspace:'
        ls -la /workspace/
    "

echo "🏁 Тест завершен"