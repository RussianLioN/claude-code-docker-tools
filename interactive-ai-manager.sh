#!/bin/bash

set -euo pipefail

# Константы
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_DIR="$SCRIPT_DIR/config"
readonly WORKSPACES_DIR="$SCRIPT_DIR/workspaces"
readonly LOGS_DIR="$SCRIPT_DIR/logs"
readonly CLAUDE_CONFIG_FILE="$CONFIG_DIR/claude_config.json"
readonly GEMINI_CONFIG_FILE="$CONFIG_DIR/gemini_config.json"
readonly GLM_CONFIG_FILE="$CONFIG_DIR/glm_config.json"

# Создаем необходимые директории
mkdir -p "$CONFIG_DIR" "$WORKSPACES_DIR" "$LOGS_DIR"

# Логирование
log_info() {
    echo "ℹ️  $1"
}

log_success() {
    echo "✅ $1"
}

log_warning() {
    echo "⚠️  $1"
}

log_error() {
    echo "❌ $1"
}

# Проверка зависимостей
check_dependencies() {
    log_info "🔍 Проверка зависимостей..."
    local missing_deps=()
    
    for cmd in docker jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "❌ Отсутствуют зависимости: ${missing_deps[*]}"
        log_error "Установите их и повторите попытку"
        exit 1
    fi
    
    log_success "✅ Все зависимости доступны"
}

# Функция ожидания пользовательского ввода
wait_for_user_input() {
    local prompt="$1"
    local var_name="$2"
    local default_value="${3:-}"
    
    echo ""
    echo "🔸 $prompt"
    echo "🔸 Введите ответ и нажмите Enter:"
    if [[ -n "$default_value" ]]; then
        echo "🔸 По умолчанию: $default_value"
    fi
    echo -n "> "
    
    read -r user_input
    
    if [[ -z "$user_input" && -n "$default_value" ]]; then
        user_input="$default_value"
    fi
    
    # Сохраняем в переменную с указанным именем
    printf -v "$var_name" '%s' "$user_input"
    echo "✅ Введено: $user_input"
}

# Функция подтверждения действия
confirm_action() {
    local prompt="$1"
    local default="${2:-Y}"
    
    echo ""
    echo "❓ $prompt"
    echo "🔸 Введите 'y' или 'Y' для подтверждения (по умолчанию: $default):"
    echo -n "> "
    
    read -r confirmation
    
    if [[ -z "$confirmation" ]]; then
        confirmation="$default"
    fi
    
    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        echo "✅ Подтверждено"
        return 0
    else
        echo "❌ Отменено"
        return 1
    fi
}

# Проверить и запустить существующий контейнер
check_and_start_container() {
    local container_pattern="$1"
    local container_name="$2"
    
    # Ищем существующий контейнер
    local existing_container=$(docker ps -a --filter "name=$container_pattern" --format "{{.Names}}" | head -1 || echo "")
    
    if [[ -n "$existing_container" ]]; then
        local status=$(docker inspect --format='{{.State.Status}}' "$existing_container" 2>/dev/null || echo "unknown")
        
        if [[ "$status" == "running" ]]; then
            log_success "✅ Найден работающий $container_name контейнер: $existing_container"
            echo "🔧 Для входа используйте: docker exec -it $existing_container bash"
            return 0
        else
            log_warning "⚠️ Найден остановленный $container_name контейнер: $existing_container"
            if confirm_action "Запустить существующий контейнер?"; then
                if docker start "$existing_container" >/dev/null 2>&1; then
                    log_success "✅ Контейнер запущен: $existing_container"
                    echo "🔧 Для входа используйте: docker exec -it $existing_container bash"
                    return 0
                else
                    log_warning "⚠️ Не удалось запустить существующий контейнер"
                    return 1
                fi
            fi
        fi
    fi
    
    return 1
}

# Интерактивная настройка Claude
interactive_claude() {
    log_info "🚀 Настройка Claude..."
    
    # Проверяем наличие API ключа
    local api_key_set=false
    
    if [[ -f "$CLAUDE_CONFIG_FILE" ]]; then
        local api_key=$(grep -o '"ANTHROPIC_API_KEY":[[:space:]]*"[^"]*"' "$CLAUDE_CONFIG_FILE" | cut -d'"' -f4 || echo "")
        
        if [[ -n "$api_key" && "$api_key" != "your-api-key-here" ]]; then
            api_key_set=true
            log_success "✅ Claude API ключ уже настроен"
        else
            log_warning "⚠️ Claude API ключ не настроен"
        fi
    else
        log_warning "⚠️ Файл конфигурации Claude не найден"
    fi
    
    if [[ "$api_key_set" == false ]]; then
        echo ""
        echo "🔸 Для настройки Claude требуется API ключ от Anthropic:"
        echo "🔸 1. Перейдите на https://console.anthropic.com/"
        echo "🔸 2. Войдите или зарегистрируйтесь"
        echo "🔸 3. Получите API ключ"
        echo ""
        
        wait_for_user_input "Введите ваш Claude API ключ" claude_api_key
        
        # Создаем конфигурационный файл
        cat > "$CLAUDE_CONFIG_FILE" << EOF
{
  "ANTHROPIC_API_KEY": "$claude_api_key",
  "model": "claude-3-5-sonnet-20241022",
  "temperature": 0.7,
  "max_tokens": 8192
}
EOF
        
        log_success "✅ Claude API ключ сохранен в $CLAUDE_CONFIG_FILE"
    fi
    
    # Проверяем существующий контейнер
    if check_and_start_container "claude-session" "claude"; then
        return 0
    fi
    
    # Создаем новый контейнер
    if confirm_action "Создать новый Claude контейнер?"; then
        echo "🔨 Создание Claude контейнера..."
        
        # Проверяем наличие образа
        if ! docker image inspect claude-interactive:latest >/dev/null 2>&1; then
            echo "📦 Сборка Claude образа..."
            
            if ! docker build -t claude-interactive:latest - << 'DOCKERFILE'
FROM node:18-alpine

RUN npm install -g @anthropic-ai/claude-3-dev && \
    adduser -D -s /bin/sh node

USER node
WORKDIR /home/node

CMD ["node", "-e", "console.log('Claude container ready')"]
DOCKERFILE
            then
                log_error "❌ Ошибка сборки Claude образа"
                return 1
            fi
            
            log_success "✅ Claude образ собран"
        fi
        
        # Создаем контейнер
        local container_name="claude-session-$(date +%s)"
        local workspace_dir="$WORKSPACES_DIR/claude"
        mkdir -p "$workspace_dir"
        
        echo "🚀 Запуск Claude контейнера..."
        if docker run -d \
            --name "$container_name" \
            --memory="1g" \
            --cpus="0.5" \
            -v "$CLAUDE_CONFIG_FILE:/home/node/.config/claude.json:ro" \
            -v "$workspace_dir:/home/node/workspace" \
            claude-interactive:latest; then
            
            log_success "✅ Claude контейнер создан: $container_name"
            echo "📁 Рабочая директория: $workspace_dir"
            echo ""
            echo "🔧 Для входа в контейнер используйте:"
            echo "docker exec -it $container_name bash"
        else
            log_error "❌ Ошибка запуска Claude контейнера"
        fi
    fi
}

# Интерактивная настройка Gemini
interactive_gemini() {
    log_info "🚀 Настройка Gemini..."
    
    # Проверяем наличие API ключа
    local api_key_set=false
    
    if [[ -f "$GEMINI_CONFIG_FILE" ]]; then
        local api_key=$(grep -o '"GEMINI_API_KEY":[[:space:]]*"[^"]*"' "$GEMINI_CONFIG_FILE" | cut -d'"' -f4 || echo "")
        
        if [[ -n "$api_key" && "$api_key" != "your-gemini-api-key-here" ]]; then
            api_key_set=true
            log_success "✅ Gemini API ключ уже настроен"
        else
            log_warning "⚠️ Gemini API ключ не настроен"
        fi
    else
        log_warning "⚠️ Файл конфигурации Gemini не найден"
    fi
    
    if [[ "$api_key_set" == false ]]; then
        echo ""
        echo "🔸 Для настройки Gemini требуется API ключ от Google:"
        echo "🔸 1. Перейдите на https://makersuite.google.com/app/apikey"
        echo "🔸 2. Войдите в свой Google аккаунт"
        echo "🔸 3. Создайте новый API ключ"
        echo ""
        
        wait_for_user_input "Введите ваш Gemini API ключ" gemini_api_key
        
        # Создаем конфигурационный файл
        cat > "$GEMINI_CONFIG_FILE" << EOF
{
  "GEMINI_API_KEY": "$gemini_api_key",
  "model": "gemini-1.5-pro",
  "temperature": 0.7,
  "max_tokens": 8192
}
EOF
        
        log_success "✅ Gemini API ключ сохранен в $GEMINI_CONFIG_FILE"
    fi
    
    # Проверяем существующий проект
    local existing_project=$(find "$WORKSPACES_DIR" -name "gemini-*" -type d | head -1 || echo "")
    
    if [[ -n "$existing_project" ]]; then
        log_success "✅ Найден существующий Gemini проект: $(basename "$existing_project")"
        echo "📁 Директория проекта: $existing_project"
        echo "🔧 Для работы с проектом перейдите в директорию и запустите:"
        echo "cd $existing_project"
        echo "npm run dev"
        return 0
    fi
    
    # Создаем новый проект
    if confirm_action "Создать новый Gemini проект?"; then
        echo "🔨 Создание Gemini проекта..."
        
        local project_name="gemini-$(date +%s)"
        local project_dir="$WORKSPACES_DIR/$project_name"
        
        if mkdir -p "$project_dir"; then
            # Создаем package.json
            cat > "$project_dir/package.json" << EOF
{
  "name": "$project_name",
  "version": "1.0.0",
  "description": "Gemini AI Project",
  "main": "index.js",
  "scripts": {
    "dev": "node index.js",
    "start": "node index.js"
  },
  "dependencies": {
    "@google/generative-ai": "^0.1.3"
  }
}
EOF
            
            # Создаем index.js
            cat > "$project_dir/index.js" << 'EOF'
const { GoogleGenerativeAI } = require('@google/generative-ai');
const fs = require('fs');
const path = require('path');

// Загрузка конфигурации
const configPath = path.join(__dirname, '..', '..', 'config', 'gemini_config.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

// Инициализация Gemini
const genAI = new GoogleGenerativeAI(config.GEMINI_API_KEY);

async function runChat() {
    console.log('🤖 Gemini AI готов к работе!');
    console.log('📝 Введите ваше сообщение (или "exit" для выхода):');
    
    const model = genAI.getGenerativeModel({ model: config.model });
    
    process.stdin.setEncoding('utf8');
    process.stdin.on('readable', () => {
        const chunk = process.stdin.read();
        if (chunk !== null) {
            const input = chunk.trim();
            if (input.toLowerCase() === 'exit') {
                process.exit(0);
            }
            
            if (input) {
                model.generateContent(input)
                    .then(result => {
                        console.log('\n🤖 Gemini:', result.response.text());
                        console.log('\n📝 Введите следующее сообщение:');
                    })
                    .catch(error => {
                        console.error('❌ Ошибка:', error.message);
                    });
            }
        }
    });
}

runChat().catch(console.error);
EOF
            
            log_success "✅ Gemini проект создан: $project_name"
            echo "📁 Директория проекта: $project_dir"
            echo ""
            echo "🔧 Для запуска проекта:"
            echo "cd $project_dir"
            echo "npm install"
            echo "npm run dev"
        else
            log_error "❌ Ошибка создания директории проекта"
        fi
    fi
}

# Интерактивная настройка GLM
interactive_glm() {
    log_info "🚀 Настройка GLM с z.ai..."
    
    # Проверяем наличие API ключа
    local glm_config="$CONFIG_DIR/glm_config.json"
    local glm_settings="$CONFIG_DIR/glm_settings.json"
    local api_key_set=false
    
    if [[ -f "$glm_config" ]]; then
        local api_key=$(grep -o '"GLM_API_KEY":[[:space:]]*"[^"]*"' "$glm_config" | cut -d'"' -f4 || echo "")
        
        if [[ -n "$api_key" && "$api_key" != "your-glm-api-key-here" ]]; then
            api_key_set=true
            log_success "✅ GLM API ключ уже настроен для z.ai"
        else
            log_warning "⚠️ GLM API ключ не настроен"
        fi
    else
        log_warning "⚠️ Файл конфигурации GLM не найден"
    fi
    
    if [[ "$api_key_set" == false ]]; then
        echo ""
        echo "🔸 Для настройки GLM требуется API ключ от z.ai:"
        echo "🔸 1. Перейдите на https://z.ai/"
        echo "🔸 2. Зарегистрируйтесь и получите API ключ"
        echo "🔸 3. API ключ имеет формат: xxxxxxxx.xxxxxxxxxxxx"
        echo ""
        
        wait_for_user_input "Введите ваш GLM API ключ от z.ai" glm_api_key
        
        # Создаем конфигурационные файлы
        cat > "$glm_config" << EOF
{
  "GLM_API_KEY": "$glm_api_key",
  "GLM_BASE_URL": "https://api.z.ai",
  "model": "glm-4.6",
  "temperature": 0.7,
  "max_tokens": 8192
}
EOF
        
        # Создаем settings файл для Claude-совместимости
        cat > "$glm_settings" << EOF
{
  "ANTHROPIC_AUTH_TOKEN": "$glm_api_key",
  "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
  "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
  "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.6",
  "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.6",
  "ANTHROPIC_MODEL": "glm-4.6",
  "alwaysThinkingEnabled": true,
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "$glm_api_key",
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.6",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.6",
    "ANTHROPIC_MODEL": "glm-4.6",
    "alwaysThinkingEnabled": "true"
  },
  "includeCoAuthoredBy": false
}
EOF
        
        log_success "✅ GLM API ключ сохранен в $glm_config"
        log_success "✅ Settings файл создан: $glm_settings"
    fi
    
    # Проверяем существующий контейнер
    if check_and_start_container "glm-zai" "glm"; then
        return 0
    fi
    
    # Создаем новый контейнер
    if confirm_action "Создать новый GLM контейнер с z.ai?"; then
        echo "🔨 Создание GLM контейнера..."
        
        # Проверяем наличие образа
        if ! docker image inspect glm-zai:latest >/dev/null 2>&1; then
            echo "📦 Сборка GLM образа для z.ai..."
            
            # Создаем временный Dockerfile
            local temp_dockerfile=$(mktemp)
            cat > "$temp_dockerfile" << 'DOCKERFILE'
FROM python:3.11-slim

RUN pip install --no-cache-dir requests && \
    useradd -m -s /bin/bash aiuser

USER aiuser
WORKDIR /home/aiuser

COPY check_api.py .

CMD ["python3", "check_api.py"]
DOCKERFILE
            
            # Создаем скрипт проверки API
            cat > check_api.py << 'PYEOF'
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
        base_url = config.get('GLM_BASE_URL', 'https://api.z.ai/api/coding/paas/v4')
        
        if not api_key:
            print("❌ API ключ не найден в конфигурации")
            return False
        
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        
        # Используем правильный эндпоинт для z.ai API
        response = requests.post(f"{base_url}/chat/completions", 
            headers=headers, 
            json={
                "model": "glm-4.6",
                "messages": [{"role": "user", "content": "Hello"}],
                "max_tokens": 10
            }, 
            timeout=10)
        
        if response.status_code == 200:
            print("✅ GLM API доступен")
            return True
        else:
            print(f"❌ Ошибка API: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Ошибка проверки API: {e}")
        return False

check_glm_api()
PYEOF
            
            if ! docker build -t glm-zai:latest -f "$temp_dockerfile" . 2>"$LOGS_DIR/glm-build.log"; then
                log_error "❌ Ошибка сборки GLM образа"
                echo "Подробности в логе: $LOGS_DIR/glm-build.log"
                rm -f "$temp_dockerfile" check_api.py
                return 1
            fi
            
            log_success "✅ GLM образ собран"
            rm -f "$temp_dockerfile" check_api.py
        fi
        
        # Создаем контейнер
        local container_name="glm-zai-$(date +%s)"
        local workspace_dir="$WORKSPACES_DIR/glm"
        mkdir -p "$workspace_dir"
        
        echo "🚀 Запуск GLM контейнера..."
        if docker run -d \
            --name "$container_name" \
            --memory="1g" \
            --cpus="0.5" \
            -v "$glm_config:/home/aiuser/.config/glm.json:ro" \
            -v "$glm_settings:/home/aiuser/.config/claude_desktop_config.json:ro" \
            -v "$workspace_dir:/home/aiuser/workspace" \
            glm-zai:latest; then
            
            log_success "✅ GLM контейнер создан: $container_name"
            echo "📁 Рабочая директория: $workspace_dir"
            echo ""
            echo "🔧 Для входа в контейнер используйте:"
            echo "docker exec -it $container_name bash"
        else
            log_error "❌ Ошибка запуска GLM контейнера"
        fi
    fi
}

# Анализ существующих контейнеров
analyze_containers() {
    log_info "🔍 Анализ существующих AI контейнеров..."
    
    echo ""
    echo "=== ПОИСК CLAUDE КОНТЕЙНЕРОВ ==="
    
    local claude_containers=$(docker ps -a --filter "name=claude-session" --format "{{.Names}}\t{{.Status}}" 2>/dev/null || true)
    
    if [[ -n "$claude_containers" ]]; then
        echo "🟢 Найдены Claude контейнеры:"
        echo "$claude_containers" | while IFS=$'\t' read -r name status; do
            local created_time=$(docker inspect --format='{{.Created}}' "$name" 2>/dev/null || echo "Unknown")
            echo "  ✅ $name - $status (создан: $created_time)"
        done
    else
        echo "🔴 Claude контейнеры не найдены"
    fi
    
    echo ""
    echo "=== ПОИСК GEMINI ПРОЕКТОВ ==="
    
    local gemini_projects=$(find "$WORKSPACES_DIR" -name "gemini-*" -type d 2>/dev/null || true)
    
    if [[ -n "$gemini_projects" ]]; then
        echo "🟢 Найдены Gemini проекты:"
        echo "$gemini_projects" | while read -r project; do
            echo "  ✅ $(basename "$project") - $project"
        done
    else
        echo "🔴 Gemini проекты не найдены"
    fi
    
    echo ""
    echo "=== ПОИСК GLM КОНТЕЙНЕРОВ ==="
    
    local glm_containers=$(docker ps -a --filter "name=glm-zai" --format "{{.Names}}\t{{.Status}}" 2>/dev/null || true)
    
    if [[ -n "$glm_containers" ]]; then
        echo "🟢 Найдены GLM контейнеры:"
        echo "$glm_containers" | while IFS=$'\t' read -r name status; do
            local created_time=$(docker inspect --format='{{.Created}}' "$name" 2>/dev/null || echo "Unknown")
            echo "  ✅ $name - $status (создан: $created_time)"
        done
    else
        echo "🔴 GLM контейнеры не найдены"
    fi
}

# Очистка ресурсов
cleanup_resources() {
    log_info "🧹 Очистка AI ресурсов..."
    
    echo ""
    echo "=== УДАЛЕНИЕ CLAUDE КОНТЕЙНЕРОВ ==="
    
    local claude_containers=$(docker ps -a --filter "name=claude-session" --format "{{.Names}}" 2>/dev/null || true)
    
    if [[ -n "$claude_containers" ]]; then
        echo "🟡 Найдены Claude контейнеры для удаления:"
        echo "$claude_containers"
        echo ""
        
        if confirm_action "Удалить все Claude контейнеры?"; then
            echo "$claude_containers" | xargs -r docker rm -f
            log_success "✅ Claude контейнеры удалены"
        fi
    else
        echo "🟢 Claude контейнеры не найдены"
    fi
    
    echo ""
    echo "=== УДАЛЕНИЕ GEMINI ПРОЕКТОВ ==="
    
    local gemini_projects=$(find "$WORKSPACES_DIR" -name "gemini-*" -type d 2>/dev/null || true)
    
    if [[ -n "$gemini_projects" ]]; then
        echo "🟡 Найдены Gemini проекты для удаления:"
        echo "$gemini_projects"
        echo ""
        
        if confirm_action "Удалить все Gemini проекты?"; then
            echo "$gemini_projects" | xargs -r rm -rf
            log_success "✅ Gemini проекты удалены"
        fi
    else
        echo "🟢 Gemini проекты не найдены"
    fi
    
    echo ""
    echo "=== УДАЛЕНИЕ GLM КОНТЕЙНЕРОВ ==="
    
    local glm_containers=$(docker ps -a --filter "name=glm-zai" --format "{{.Names}}" 2>/dev/null || true)
    
    if [[ -n "$glm_containers" ]]; then
        echo "🟡 Найдены GLM контейнеры для удаления:"
        echo "$glm_containers"
        echo ""
        
        if confirm_action "Удалить все GLM контейнеры?"; then
            echo "$glm_containers" | xargs -r docker rm -f
            log_success "✅ GLM контейнеры удалены"
        fi
    else
        echo "🟢 GLM контейнеры не найдены"
    fi
    
    # Очистка образов
    echo ""
    if confirm_action "Удалить неиспользуемые Docker образы?"; then
        docker image prune -f
        log_success "✅ Неиспользуемые образы удалены"
    fi
    
    echo ""
    log_success "✅ Очистка завершена"
}

# Главное меню
show_menu() {
    echo ""
    echo "🤖 МЕНЕДЖЕР AI КОНТЕЙНЕРОВ v6.2"
    echo "==============================="
    echo "1. 🔧 Настроить Claude"
    echo "2. 🔧 Настроить Gemini"
    echo "3. 🔧 Настроить GLM (z.ai)"
    echo "4. 🔍 Анализ контейнеров"
    echo "5. 🧹 Очистка ресурсов"
    echo "6. 🚪 Выход"
    echo ""
}

# Основная функция
main() {
    # Проверяем зависимости
    check_dependencies
    
    # Обрабатываем аргументы командной строки
    if [[ $# -eq 1 ]]; then
        case "$1" in
            "claude")
                interactive_claude
                return 0
                ;;
            "gemini")
                interactive_gemini
                return 0
                ;;
            "glm")
                interactive_glm
                return 0
                ;;
            "analyze")
                analyze_containers
                return 0
                ;;
            "cleanup")
                cleanup_resources
                return 0
                ;;
            *)
                echo "Использование: $0 [claude|gemini|glm|analyze|cleanup]"
                return 1
                ;;
        esac
    fi
    
    # Интерактивный режим
    while true; do
        show_menu
        wait_for_user_input "Выберите опцию (1-6)" choice
        
        case "$choice" in
            "1")
                interactive_claude
                ;;
            "2")
                interactive_gemini
                ;;
            "3")
                interactive_glm
                ;;
            "4")
                analyze_containers
                ;;
            "5")
                cleanup_resources
                ;;
            "6")
                echo "👋 До свидания!"
                exit 0
                ;;
            *)
                log_warning "⚠️ Неверный выбор. Пожалуйста, выберите 1-6."
                ;;
        esac
        
        echo ""
        echo "Нажмите Enter для продолжения..."
        read -r
    done
}

# Запуск
main "$@"