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
cat > /tmp/glm-simple-dockerfile << 'EOF'
FROM python:3.11-slim

RUN pip install --no-cache-dir requests && \
    useradd -m -s /bin/bash aiuser

USER aiuser
WORKDIR /home/aiuser

CMD ["python3", "-c", "print('GLM контейнер готов!')"]
EOF

# Собираем образ
echo "📦 Сборка образа..."
if docker build -t glm-zai:latest -f /tmp/glm-simple-dockerfile .; then
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
        -v "$workspace_dir:/home/aiuser/workspace" \
        -v "$GLM_CONFIG:/home/aiuser/.config/glm.json:ro" \
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
rm -f /tmp/glm-simple-dockerfile

echo "🎉 Готово!"