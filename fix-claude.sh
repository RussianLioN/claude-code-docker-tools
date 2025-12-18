#!/bin/bash

# Исправление установки Claude Code в GLM контейнер
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Исправление установки Claude Code в GLM контейнер..."

# Пересборка образа с исправленным Claude Code
echo "🔄 Пересборка образа с исправленным Claude Code..."
TEMP_BUILD_DIR=$(mktemp -d)

# Создание нового Dockerfile с исправленной установкой
cat > "$TEMP_BUILD_DIR/Dockerfile" << 'EOF'
FROM glm-zai

USER root

# Установка Node.js и Claude Code
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get update && apt-get install -y nodejs && \
    npm install -g @anthropic-ai/claude-code && \
    find /usr/local/lib/node_modules/@anthropic-ai/claude-code -name "claude" -type f -executable -exec cp {} /usr/local/bin/claude \; && \
    chmod +x /usr/local/bin/claude && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Возврат к aiuser
USER aiuser

# Настройка конфигурации Claude
RUN mkdir -p /home/aiuser/.config/claude

CMD ["bash"]
EOF

# Сборка обновленного образа
docker build -t glm-zai-claude "$TEMP_BUILD_DIR"

# Очистка
rm -rf "$TEMP_BUILD_DIR"

echo "✅ Создан исправленный образ: glm-zai-claude"
echo "🚀 Используйте: ./claude-glm.sh"