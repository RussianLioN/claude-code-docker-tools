#!/bin/bash

# Упрощенный скрипт создания GLM контейнера с z.ai

set -e

CONFIG_DIR="$(dirname "$0")/config"
WORKSPACES_DIR="$(dirname "$0")/workspaces"

# Создаем директории
mkdir -p "$CONFIG_DIR" "$WORKSPACES_DIR"

# Проверяем наличие API ключа
GLM_CONFIG="$CONFIG_DIR/glm_config.json"

if [[ ! -f "$GLM_CONFIG" ]]; then
    echo "❌ Файл конфигурации не найден: $GLM_CONFIG"
    exit 1
fi

echo "🚀 Создание GLM контейнера с z.ai..."

# Создаем рабочий Dockerfile
cat > /tmp/glm-zai-dockerfile << 'EOF'
FROM python:3.11-slim

RUN pip install --no-cache-dir requests && \
    useradd -m -s /bin/bash aiuser

USER aiuser
WORKDIR /home/aiuser

# Создаем скрипт проверки API
COPY check_api.py .
RUN chmod +x check_api.py

CMD ["python3", "check_api.py"]
EOF

# Создаем скрипт проверки API
cat > /tmp/check_api.py << 'PYEOF'
import requests
import json
import os

def check_glm_api():
    config_path = "/home/aiuser/.config/glm.json"
    
    if not os.path.exists(config_path):
        print("❌ Конфигурационный файл не найден")
        return False
    
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
        
        api_key = config.get('GLM_API_KEY')
        base_url = config.get('GLM_BASE_URL', 'https://api.z.ai')
        
        if not api_key:
            print("❌ API ключ не найден в конфигурации")
            return False
        
        # Проверяем доступность API
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        
        response = requests.get(f"{base_url}/models", headers=headers, timeout=10)
        
        if response.status_code == 200:
            print("✅ GLM API доступен")
            return True
        else:
            print(f"❌ Ошибка API: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Ошибка проверки API: {e}")
        return False

if __name__ == "__main__":
    check_glm_api()
PYEOF

# Собираем образ
echo "📦 Сборка образа..."
if docker build -t glm-zai:latest -f /tmp/glm-zai-dockerfile .; then
    echo "✅ Образ собран успешно"
    
    # Создаем контейнер
    container_name="glm-zai-$(date +%s)"
    workspace_dir="$WORKSPACES_DIR/glm-$(date +%s)"
    mkdir -p "$workspace_dir"
    
    echo "🚀 Запуск контейнера..."
    if docker run -d \
        --name "$container_name" \
        --memory="512m" \
        --cpus="0.5" \
        -v "$GLM_CONFIG:/home/aiuser/.config/glm.json:ro" \
        -v "$workspace_dir:/home/aiuser/workspace" \
        glm-zai:latest; then
        
        echo "✅ GLM контейнер создан: $container_name"
        echo "📁 Рабочая директория: $workspace_dir"
        
        # Проверяем статус
        sleep 2
        echo ""
        echo "🔍 Статус контейнера:"
        docker ps --filter "name=$container_name"
        
        echo ""
        echo "🔍 Логи контейнера:"
        docker logs "$container_name"
        
    else
        echo "❌ Ошибка запуска контейнера"
        exit 1
    fi
    
else
    echo "❌ Ошибка сборки образа"
    exit 1
fi

# Очистка
rm -f /tmp/glm-zai-dockerfile /tmp/check_api.py

echo "🎉 Готово!"