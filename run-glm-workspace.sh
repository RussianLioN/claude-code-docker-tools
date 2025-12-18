#!/bin/bash

# Запуск полноценного GLM контейнера для работы с Anthropic API
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
WORKSPACE_DIR="$SCRIPT_DIR/workspaces"

GLM_CONFIG="$CONFIG_DIR/glm_config.json"

# Проверка конфигурации
if [[ ! -f "$GLM_CONFIG" ]]; then
    echo "❌ Конфигурация GLM не найдена: $GLM_CONFIG"
    echo "Сначала выполните: ./interactive-ai-manager.sh glm"
    exit 1
fi

# Создание рабочей директории
mkdir -p "$WORKSPACE_DIR/glm-workspace"

# Чтение конфигурации
AUTH_TOKEN=$(jq -r '.ANTHROPIC_AUTH_TOKEN' "$GLM_CONFIG")
BASE_URL=$(jq -r '.ANTHROPIC_BASE_URL' "$GLM_CONFIG")
MODEL=$(jq -r '.ANTHROPIC_MODEL' "$GLM_CONFIG")

echo "🚀 Запуск полноценного GLM контейнера..."
echo "📋 Параметры:"
echo "   - API: $BASE_URL"
echo "   - Model: $MODEL"
echo "   - Workspace: $WORKSPACE_DIR/glm-workspace"

# Создание временной директории для сборки
TEMP_BUILD_DIR=$(mktemp -d)

# Создание Python скрипта для взаимодействия
TEMP_INTERACT=$(mktemp)
cat > "$TEMP_INTERACT" << 'EOF'
#!/usr/bin/env python3
import json
import requests
import sys
import os

def load_config():
    config_path = os.environ.get('GLM_CONFIG_PATH', '/home/aiuser/.config/glm_config.json')
    with open(config_path, 'r') as f:
        return json.load(f)

def send_message(message, model="glm-4.6"):
    config = load_config()
    
    headers = {
        "Authorization": f"Bearer {config['ANTHROPIC_AUTH_TOKEN']}",
        "Content-Type": "application/json",
        "anthropic-version": "2023-06-01"
    }
    
    data = {
        "model": model,
        "max_tokens": 4000,
        "messages": [
            {"role": "user", "content": message}
        ]
    }
    
    try:
        response = requests.post(
            f"{config['ANTHROPIC_BASE_URL']}/v1/messages",
            headers=headers,
            json=data,
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            return result['content'][0]['text']
        else:
            return f"❌ Ошибка API: {response.status_code} - {response.text}"
            
    except Exception as e:
        return f"❌ Ошибка соединения: {str(e)}"

def interactive_mode():
    print("🤖 GLM Interactive Mode")
    print("Введите 'exit' для выхода")
    print("=" * 50)
    
    while True:
        try:
            user_input = input("\n👤 Вы: ").strip()
            
            if user_input.lower() in ['exit', 'quit', 'выход']:
                print("👋 До свидания!")
                break
                
            if not user_input:
                continue
                
            print("🤖 Думаю...")
            response = send_message(user_input)
            print(f"\n🤖 GLM: {response}")
            
        except KeyboardInterrupt:
            print("\n👋 До свидания!")
            break
        except Exception as e:
            print(f"❌ Ошибка: {str(e)}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        message = " ".join(sys.argv[1:])
        print(send_message(message))
    else:
        interactive_mode()
EOF

chmod +x "$TEMP_INTERACT"

# Создание Dockerfile во временной директории
cat > "$TEMP_BUILD_DIR/Dockerfile" << 'EOF'
FROM python:3.11-slim

# Установка зависимостей
RUN pip install --no-cache-dir requests && \
    apt-get update && apt-get install -y curl git vim bash && \
    useradd -m -s /bin/bash aiuser

# Настройка пользователя
USER aiuser
WORKDIR /home/aiuser

# Создание директорий
RUN mkdir -p /home/aiuser/.config /home/aiuser/workspace

# Копирование конфигурации
COPY --chown=aiuser:aiuser glm_config.json /home/aiuser/.config/
COPY --chown=aiuser:aiuser interact.py /home/aiuser/
RUN chmod +x /home/aiuser/interact.py

# Настройка окружения
ENV GLM_CONFIG_PATH=/home/aiuser/.config/glm_config.json

CMD ["bash"]
EOF

# Копирование файлов во временную директорию
cp "$GLM_CONFIG" "$TEMP_BUILD_DIR/glm_config.json"
cp "$TEMP_INTERACT" "$TEMP_BUILD_DIR/interact.py"

# Сборка образа
echo "📦 Сборка GLM образа..."
docker build -t glm-zai "$TEMP_BUILD_DIR"

# Запуск контейнера
echo "🚀 Запуск GLM контейнера..."
docker run -it --rm \
    --name glm-zai-session \
    -v "$WORKSPACE_DIR/glm-workspace:/home/aiuser/workspace" \
    -e GLM_CONFIG_PATH=/home/aiuser/.config/glm_config.json \
    glm-zai

# Очистка
rm -rf "$TEMP_BUILD_DIR"
rm -f "$TEMP_INTERACT"

echo "✅ Работа с GLM контейнером завершена"