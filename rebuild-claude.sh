#!/bin/bash

# Правильная пересборка GLM контейнера с Claude Code
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Правильная пересборка GLM контейнера с Claude Code..."

# Создание временного Dockerfile для пересборки
TEMP_BUILD_DIR=$(mktemp -d)

# Создание правильного Dockerfile с установкой Claude Code
cat > "$TEMP_BUILD_DIR/Dockerfile" << 'EOF'
FROM glm-zai

USER root

# Установка Node.js и Claude Code
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get update && apt-get install -y nodejs && \
    npm install -g @anthropic-ai/claude-code && \
    npm install -g @anthropic-ai/claude-cli && \
    find /usr/local/lib/node_modules/@anthropic-ai -name "claude" -type f -executable -exec cp {} /usr/local/bin/claude \; 2>/dev/null || true && \
    chmod +x /usr/local/bin/claude || true && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Возврат к aiuser
USER aiuser

# Настройка конфигурации Claude
RUN mkdir -p /home/aiuser/.config/claude

CMD ["bash"]
EOF

echo "🔄 Пересборка образа с --no-cache..."
docker build --no-cache -t glm-zai-claude "$TEMP_BUILD_DIR"

# Очистка
rm -rf "$TEMP_BUILD_DIR"

echo "✅ Обновлен образ: glm-zai-claude"
echo "🧪 Проверка установки Claude Code..."
docker run --rm glm-zai-claude bash -c "which claude && claude --version" || echo "⚠️ Claude Code требует дополнительной настройки"

echo "🚀 Используйте: ./claude-glm.sh"