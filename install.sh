#!/bin/bash
set -e

# Цвета для вывода
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🛠  Установка Dual AI Assistant Environment (Gemini + Claude)...${NC}"

# 1. Проверка Docker
function ensure_docker_running() {
  if ! command -v docker &> /dev/null; then
      echo "❌ Docker не найден! Установите Docker Desktop."
      exit 1
  fi
  if ! docker info > /dev/null 2>&1; then
    echo "🐳 Запускаю Docker Desktop..."
    open -a Docker
    # Ожидание
    while ! docker info > /dev/null 2>&1; do sleep 2; done
    echo "✅ Docker готов!"
  fi
}

ensure_docker_running

# 2. Умная проверка версии Gemini
echo -e "${BLUE}🔍 Проверка последней версии @google/gemini-cli...${NC}"
LATEST_GEMINI_VER=$(curl -m 3 -s https://registry.npmjs.org/@google/gemini-cli/latest | grep -o '"version":"[^"]*"' | cut -d'"' -f4)

if [ -z "$LATEST_GEMINI_VER" ]; then
    echo "⚠️  Не удалось получить версию Gemini из NPM. Используем 'latest'."
    LATEST_GEMINI_VER="latest"
else
    echo -e "✅ Целевая версия Gemini: ${GREEN}${LATEST_GEMINI_VER}${NC}"
fi

# 3. Проверка версии Claude (если доступно)
echo -e "${BLUE}🔍 Проверка Claude Code CLI...${NC}"
# Здесь можно добавить проверку Claude CLI версии
LATEST_CLAUDE_VER="latest"
echo -e "✅ Целевая версия Claude: ${GREEN}${LATEST_CLAUDE_VER}${NC}"

# 4. Сборка Docker образа
echo -e "${BLUE}📦 Сборка Docker образа с поддержкой Gemini + Claude...${NC}"
docker build \
    --build-arg GEMINI_VERSION=$LATEST_GEMINI_VER \
    --build-arg CLAUDE_VERSION=$LATEST_CLAUDE_VER \
    -t claude-code-tools .

# 5. Конфигурационные директории
CONFIG_DIR="$HOME/.docker-ai-config"
mkdir -p "$CONFIG_DIR/global_state"
mkdir -p "$CONFIG_DIR/gh_config"

# 6. Gemini конфигурация
if [ ! -f "$CONFIG_DIR/settings.json" ]; then
    if [ -f "settings.json" ]; then
        cp settings.json "$CONFIG_DIR/"
    else
        echo '{"model": "gemini-2.5-pro", "security": {"auth": {"selectedType": "oauth-personal"}}}' > "$CONFIG_DIR/settings.json"
    fi
    echo "✅ Gemini конфигурация создана."
fi

# 7. Claude конфигурация
if [ ! -f "$CONFIG_DIR/claude_config.json" ]; then
    if [ -f "claude-config.json" ]; then
        cp claude-config.json "$CONFIG_DIR/"
    else
        cat > "$CONFIG_DIR/claude_config.json" << EOF
{
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 4096,
  "temperature": 0.7,
  "system_prompt": "You are Claude Code, an expert AI assistant for software development."
}
EOF
    fi
    echo "✅ Claude конфигурация создана."
fi

# 8. Интеграция в Zsh
ZSH_FILE="$HOME/.zshrc"
SCRIPT_PATH="$(pwd)/ai-assistant.zsh"
SOURCE_CMD="source \"$SCRIPT_PATH\""

if ! grep -Fq "$SCRIPT_PATH" "$ZSH_FILE"; then
    echo "" >> "$ZSH_FILE"
    echo "# Claude Code + Gemini AI Assistant Tooling" >> "$ZSH_FILE"
    echo "$SOURCE_CMD" >> "$ZSH_FILE"
    echo "✅ Скрипт AI Assistant подключен к .zshrc"
else
    echo "ℹ️  Скрипт уже есть в .zshrc"
fi

# 9. Environment variables setup
ENV_FILE="$CONFIG_DIR/env"
if [ ! -f "$ENV_FILE" ]; then
    cat > "$ENV_FILE" << EOF
# Claude Code Environment Variables
# Uncomment and set your Claude API key
# export CLAUDE_API_KEY="your-claude-api-key-here"
export CLAUDE_MODEL="claude-3-5-sonnet-20241022"
export CLAUDE_MAX_TOKENS=4096

# Gemini Environment Variables
export GEMINI_MODEL="gemini-2.5-pro"

# AI Assistant Mode (gemini/claude)
export AI_CURRENT_MODE="gemini"
EOF
    echo "✅ Файл окружения создан: $ENV_FILE"
    echo -e "${YELLOW}⚠️  Не забудьте установить CLAUDE_API_KEY в $ENV_FILE${NC}"
fi

# 10. Создание symbolic links для удобства
if [ ! -L "$CONFIG_DIR/gemini.zsh" ]; then
    ln -sf "$SCRIPT_PATH" "$CONFIG_DIR/gemini.zsh"
    echo "✅ Symbolic link создан для обратной совместимости"
fi

echo ""
echo -e "${GREEN}🎉 Установка Dual AI Assistant завершена успешно!${NC}"
echo ""
echo -e "${BLUE}🚀 Доступные команды:${NC}"
echo "   • gemini    - Запуск Gemini CLI"
echo "   • claude    - Запуск Claude Code CLI"
echo "   • aic       - Gemini AI Commit"
echo "   • cic       - Claude AI Commit"
echo "   • gexec     - Выполнение команд в контейнере"
echo "   • ai-mode   - Переключение между AI режимами"
echo ""
echo -e "${YELLOW}📋 Следующие шаги:${NC}"
echo "   1. Выполните: source ~/.zshrc"
echo "   2. Установите Claude API ключ в ~/.docker-ai-config/env"
echo "   3. Попробуйте: gemini или claude"
echo ""
echo -e "${GREEN}✨ Приятной работы с AI Assistant!${NC}"
