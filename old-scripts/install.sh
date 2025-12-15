#!/bin/bash
set -e

# Цвета для вывода
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}🛠  Установка окружения Gemini Docker...${NC}"

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

# 2. Умная проверка версии (Smart Version Check)
echo "🔍 Проверка последней версии @google/gemini-cli..."
# Получаем версию из NPM (таймаут 3с)
LATEST_VER=$(curl -m 3 -s https://registry.npmjs.org/@google/gemini-cli/latest | grep -o '"version":"[^"]*"' | cut -d'"' -f4)

if [ -z "$LATEST_VER" ]; then
    echo "⚠️  Не удалось получить версию из NPM. Используем 'latest'."
    LATEST_VER="latest"
else
    echo -e "✅ Целевая версия: ${GREEN}${LATEST_VER}${NC}"
fi

# 3. Сборка
echo "📦 Сборка Docker образа..."
docker build --build-arg GEMINI_VERSION=$LATEST_VER -t gemini-cli .

# 4. Конфиги
CONFIG_DIR="$HOME/.docker-gemini-config"
mkdir -p "$CONFIG_DIR/global_state"
mkdir -p "$CONFIG_DIR/gh_config"

if [ ! -f "$CONFIG_DIR/settings.json" ]; then
    # Создаем дефолтный конфиг, если нет файла шаблона и нет конфига
    if [ -f "settings.json" ]; then
        cp settings.json "$CONFIG_DIR/"
    else
        echo '{"model": "gemini-2.5-pro", "security": {"auth": {"selectedType": "oauth-personal"}}}' > "$CONFIG_DIR/settings.json"
    fi
    echo "✅ Конфиг settings.json создан."
fi

# 5. Интеграция в Zsh
ZSH_FILE="$HOME/.zshrc"
SCRIPT_PATH="$(pwd)/gemini.zsh"
SOURCE_CMD="source \"$SCRIPT_PATH\""

if ! grep -Fq "$SCRIPT_PATH" "$ZSH_FILE"; then
    echo "" >> "$ZSH_FILE"
    echo "# Gemini Docker Tooling" >> "$ZSH_FILE"
    echo "$SOURCE_CMD" >> "$ZSH_FILE"
    echo "✅ Скрипт подключен к .zshrc"
else
    echo "ℹ️  Скрипт уже есть в .zshrc"
fi

echo ""
echo -e "${GREEN}🎉 Установка завершена успешно!${NC}"
echo "👉 Выполните: source ~/.zshrc"
