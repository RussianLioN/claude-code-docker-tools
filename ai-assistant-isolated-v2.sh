#!/bin/bash

# Улучшенная система изолированных AI контейнеров v2.0
# Использует существующие авторизационные данные, неинтерактивный режим

set -euo pipefail

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SESSIONS_DIR="$PROJECT_ROOT/sessions"
CONFIG_DIR="$PROJECT_ROOT/config"
LOGS_DIR="$PROJECT_ROOT/logs"

# Создаем необходимые директории
mkdir -p "$SESSIONS_DIR" "$CONFIG_DIR" "$LOGS_DIR"

# Логирование
log_info() {
    echo "[INFO $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/ai-assistant.log"
}

log_error() {
    echo "[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/ai-assistant.log"
}

log_success() {
    echo "[SUCCESS $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/ai-assistant.log"
}

# Проверка зависимостей
check_dependencies() {
    local deps=("docker" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log_error "Зависимость не найдена: $dep"
            return 1
        fi
    done
    log_info "✅ Все зависимости доступны"
}

# Генерация UUID4
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        python3 -c "import uuid; print(str(uuid.uuid4()))"
    fi
}

# Копирование авторизационных данных
copy_auth_data() {
    local ai_type="$1"
    local session_id="$2"
    local target_config="$SESSIONS_DIR/$session_id/config"
    
    mkdir -p "$target_config"
    
    case "$ai_type" in
        "claude")
            if [[ -f "$HOME/.docker-ai-config/claude_config.json" ]]; then
                cp "$HOME/.docker-ai-config/claude_config.json" "$target_config/"
                log_info "✅ Claude OAuth данные скопированы"
                return 0
            else
                log_error "❌ Claude OAuth данные не найдены"
                return 1
            fi
            ;;
        "gemini")
            if [[ -f "$HOME/.docker-ai-config/gemini_config.json" ]]; then
                cp "$HOME/.docker-ai-config/gemini_config.json" "$target_config/"
                log_info "✅ Gemini конфигурация скопирована"
                return 0
            else
                log_error "❌ Gemini конфигурация не найдена"
                return 1
            fi
            ;;
        "glm")
            if [[ -f "$HOME/.docker-ai-config/glm_config.json" ]]; then
                cp "$HOME/.docker-ai-config/glm_config.json" "$target_config/"
                log_info "✅ GLM конфигурация скопирована"
                return 0
            else
                log_error "❌ GLM конфигурация не найдена"
                return 1
            fi
            ;;
    esac
}

# Создание изолированного Dockerfile для Claude
create_claude_dockerfile() {
    local session_id="$1"
    local dockerfile_dir="$SESSIONS_DIR/$session_id"
    
    cat > "$dockerfile_dir/Dockerfile" << 'EOF'
FROM mcr.microsoft.com/devcontainers/javascript-node:20

# Установка Claude Code
RUN npm install -g @anthropic-ai/claude-3-dev

# Создание пользователя с ограниченными правами
RUN groupadd -r aiuser && useradd -r -g aiuser -m -s /bin/bash aiuser && \
    mkdir -p /home/aiuser/.config && \
    chown -R aiuser:aiuser /home/aiuser

# Установка дополнительных утилит
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    && rm -rf /var/lib/apt/lists/*

USER aiuser
WORKDIR /home/aiuser

# Копирование конфигурации
COPY --chown=aiuser:aiuser config/claude_config.json /home/aiuser/.config/claude.json

# Настройка окружения
ENV PATH="/home/aiuser/.local/bin:$PATH"
ENV HOME="/home/aiuser"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "console.log('Claude container healthy')" || exit 1

# Команда по умолчанию (неинтерактивная)
CMD ["--help"]
EOF
}

# Создание изолированного Dockerfile для Gemini
create_gemini_dockerfile() {
    local session_id="$1"
    local dockerfile_dir="$SESSIONS_DIR/$session_id"
    
    cat > "$dockerfile_dir/Dockerfile" << 'EOF'
FROM python:3.11-slim

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Установка Python зависимостей
RUN pip install --no-cache-dir \
    google-generativeai \
    python-dotenv

# Создание пользователя
RUN groupadd -r aiuser && useradd -r -g aiuser -m -s /bin/bash aiuser

USER aiuser
WORKDIR /home/aiuser

# Копирование конфигурации
COPY --chown=aiuser:aiuser config/gemini_config.json /home/aiuser/.config/gemini.json

# Настройка окружения
ENV PYTHONPATH="/home/aiuser"
ENV HOME="/home/aiuser"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "import google.generativeai as genai; print('Gemini container healthy')" || exit 1

# Команда по умолчанию (неинтерактивная)
CMD ["python3", "-c", "print('Gemini AI Assistant ready. Use interactive mode to start.')"]
EOF
}

# Создание изолированного Dockerfile для GLM
create_glm_dockerfile() {
    local session_id="$1"
    local dockerfile_dir="$SESSIONS_DIR/$session_id"
    
    cat > "$dockerfile_dir/Dockerfile" << 'EOF'
FROM python:3.11-slim

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Установка Python зависимостей
RUN pip install --no-cache-dir \
    zhipuai \
    python-dotenv

# Создание пользователя
RUN groupadd -r aiuser && useradd -r -g aiuser -m -s /bin/bash aiuser

USER aiuser
WORKDIR /home/aiuser

# Копирование конфигурации
COPY --chown=aiuser:aiuser config/glm_config.json /home/aiuser/.config/glm.json

# Настройка окружения
ENV PYTHONPATH="/home/aiuser"
ENV HOME="/home/aiuser"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "import zhipuai; print('GLM container healthy')" || exit 1

# Команда по умолчанию (неинтерактивная)
CMD ["python3", "-c", "print('GLM AI Assistant ready. Use interactive mode to start.')"]
EOF
}

# Создание сессии AI
create_ai_session() {
    local ai_type="$1"
    local session_id=$(generate_uuid)
    local session_dir="$SESSIONS_DIR/$session_id"
    local container_name="ai-${ai_type}-$session_id"
    
    log_info "🚀 Создание сессии $ai_type: $session_id"
    
    # Создание директории сессии
    mkdir -p "$session_dir/config"
    
    # Копирование авторизационных данных
    if ! copy_auth_data "$ai_type" "$session_id"; then
        log_error "❌ Не удалось скопировать авторизационные данные для $ai_type"
        return 1
    fi
    
    # Создание Dockerfile
    case "$ai_type" in
        "claude")
            create_claude_dockerfile "$session_id"
            ;;
        "gemini")
            create_gemini_dockerfile "$session_id"
            ;;
        "glm")
            create_glm_dockerfile "$session_id"
            ;;
        *)
            log_error "❌ Неизвестный тип AI: $ai_type"
            return 1
            ;;
    esac
    
    # Сборка образа
    log_info "🔨 Сборка образа для $ai_type..."
    if docker build -t "ai-$ai_type:$session_id" "$session_dir" >> "$LOGS_DIR/${ai_type}-build-$session_id.log" 2>&1; then
        log_success "✅ Образ $ai_type успешно собран"
    else
        log_error "❌ Ошибка сборки образа $ai_type"
        return 1
    fi
    
    # Запуск контейнера в фоновом режиме
    log_info "🚀 Запуск контейнера $ai_type..."
    local run_cmd="docker run -d \
        --name $container_name \
        --memory=2g \
        --cpus=1.0 \
        --network=bridge \
        --restart unless-stopped \
        --user aiuser \
        -v $session_dir/workspace:/home/aiuser/workspace \
        -v $session_dir/config:/home/aiuser/.config:ro \
        ai-$ai_type:$session_id"
    
    if eval "$run_cmd" >> "$LOGS_DIR/${ai_type}-run-$session_id.log" 2>&1; then
        log_success "✅ Контейнер $ai_type запущен: $container_name"
        
        # Сохранение информации о сессии
        cat > "$session_dir/session.json" << EOF
{
    "session_id": "$session_id",
    "ai_type": "$ai_type",
    "container_name": "$container_name",
    "image_name": "ai-$ai_type:$session_id",
    "created_at": "$(date -Iseconds)",
    "status": "running",
    "workspace_dir": "$session_dir/workspace",
    "config_dir": "$session_dir/config"
}
EOF
        
        log_info "📁 Рабочая директория: $session_dir/workspace"
        log_info "🔧 Конфигурация: $session_dir/config"
        log_info "📋 Информация о сессии: $session_dir/session.json"
        
        echo "$session_id"
        return 0
    else
        log_error "❌ Ошибка запуска контейнера $ai_type"
        return 1
    fi
}

# Подключение к существующей сессии
connect_to_session() {
    local session_id="$1"
    local session_file="$SESSIONS_DIR/$session_id/session.json"
    
    if [[ ! -f "$session_file" ]]; then
        log_error "❌ Сессия не найдена: $session_id"
        return 1
    fi
    
    local container_name=$(jq -r '.container_name' "$session_file")
    local ai_type=$(jq -r '.ai_type' "$session_file")
    
    # Проверка статуса контейнера
    if ! docker ps --filter "name=$container_name" --format "{{.Names}}" | grep -q "$container_name"; then
        log_error "❌ Контейнер не запущен: $container_name"
        return 1
    fi
    
    log_info "🔗 Подключение к сессии $session_id ($ai_type)"
    
    case "$ai_type" in
        "claude")
            log_info "Запуск Claude Code в интерактивном режиме..."
            docker exec -it "$container_name" claude --help
            ;;
        "gemini")
            log_info "Запуск Gemini в интерактивном режиме..."
            docker exec -it "$container_name" python3 -c "
import google.generativeai as genai
import json
import os

# Загрузка конфигурации
with open('/home/aiuser/.config/gemini.json') as f:
    config = json.load(f)

# Настройка API
genai.configure(api_key=config.get('GEMINI_API_KEY'))

print('Gemini AI готов к работе!')
print('Доступные модели:')
for model in genai.list_models():
    if 'generateContent' in model.supported_generation_methods:
        print(f'  - {model.name}')
"
            ;;
        "glm")
            log_info "Запуск GLM в интерактивном режиме..."
            docker exec -it "$container_name" python3 -c "
import zhipuai
import json
import os

# Загрузка конфигурации
with open('/home/aiuser/.config/glm.json') as f:
    config = json.load(f)

# Настройка API
zhipuai.api_key = config.get('GLM_API_KEY')

print('GLM AI готов к работе!')
print('API ключ настроен успешно')
"
            ;;
    esac
}

# Показать статус сессий
show_sessions_status() {
    log_info "📊 Статус AI сессий:"
    
    if [[ ! -d "$SESSIONS_DIR" ]] || [[ -z "$(ls -A "$SESSIONS_DIR" 2>/dev/null)" ]]; then
        log_info "Нет активных сессий"
        return 0
    fi
    
    printf "%-20s %-15s %-15s %-20s %-10s\n" "SESSION_ID" "AI_TYPE" "CONTAINER" "CREATED" "STATUS"
    printf "%-20s %-15s %-15s %-20s %-10s\n" "--------------------" "---------------" "---------------" "--------------------" "----------"
    
    for session_dir in "$SESSIONS_DIR"/*; do
        if [[ -d "$session_dir" && -f "$session_dir/session.json" ]]; then
            local session_id=$(basename "$session_dir")
            local session_file="$session_dir/session.json"
            
            local ai_type=$(jq -r '.ai_type' "$session_file" 2>/dev/null || echo "unknown")
            local container_name=$(jq -r '.container_name' "$session_file" 2>/dev/null || echo "unknown")
            local created_at=$(jq -r '.created_at' "$session_file" 2>/dev/null || echo "unknown")
            
            # Проверка статуса контейнера
            local status="stopped"
            if docker ps --filter "name=$container_name" --format "{{.Names}}" | grep -q "$container_name" 2>/dev/null; then
                status="running"
            fi
            
            local created_short=$(date -d "$created_at" '+%m/%d %H:%M' 2>/dev/null || echo "unknown")
            
            printf "%-20s %-15s %-15s %-20s %-10s\n" "$session_id" "$ai_type" "$container_name" "$created_short" "$status"
        fi
    done
}

# Остановка сессии
stop_session() {
    local session_id="$1"
    local session_file="$SESSIONS_DIR/$session_id/session.json"
    
    if [[ ! -f "$session_file" ]]; then
        log_error "❌ Сессия не найдена: $session_id"
        return 1
    fi
    
    local container_name=$(jq -r '.container_name' "$session_file")
    local image_name=$(jq -r '.image_name' "$session_file")
    
    log_info "🛑 Остановка сессии: $session_id"
    
    # Остановка и удаление контейнера
    if docker ps --filter "name=$container_name" --format "{{.Names}}" | grep -q "$container_name" 2>/dev/null; then
        docker stop "$container_name" >> "$LOGS_DIR/stop-$session_id.log" 2>&1
        log_info "✅ Контейнер остановлен: $container_name"
    fi
    
    if docker ps -a --filter "name=$container_name" --format "{{.Names}}" | grep -q "$container_name" 2>/dev/null; then
        docker rm "$container_name" >> "$LOGS_DIR/rm-$session_id.log" 2>&1
        log_info "✅ Контейнер удален: $container_name"
    fi
    
    # Удаление образа
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "$image_name" 2>/dev/null; then
        docker rmi "$image_name" >> "$LOGS_DIR/rmi-$session_id.log" 2>&1
        log_info "✅ Образ удален: $image_name"
    fi
    
    # Обновление статуса
    jq '.status = "stopped"' "$session_file" > "$session_file.tmp" && mv "$session_file.tmp" "$session_file"
    
    log_success "✅ Сессия остановлена: $session_id"
}

# Удаление сессии
remove_session() {
    local session_id="$1"
    
    # Сначала останавливаем сессию
    stop_session "$session_id"
    
    # Удаление директории сессии
    if [[ -d "$SESSIONS_DIR/$session_id" ]]; then
        rm -rf "$SESSIONS_DIR/$session_id"
        log_success "✅ Сессия удалена: $session_id"
    fi
}

# Очистка всех сессий
cleanup_all_sessions() {
    log_info "🧹 Очистка всех сессий..."
    
    if [[ -d "$SESSIONS_DIR" ]]; then
        for session_dir in "$SESSIONS_DIR"/*; do
            if [[ -d "$session_dir" ]]; then
                local session_id=$(basename "$session_dir")
                remove_session "$session_id"
            fi
        done
    fi
    
    log_success "✅ Все сессии очищены"
}

# Показать справку
show_help() {
    cat << EOF
Улучшенная система изолированных AI контейнеров v2.0

Использование:
  $0 create <ai_type>     # Создать новую сессию (claude, gemini, glm)
  $0 connect <session_id> # Подключиться к существующей сессии
  $0 status              # Показать статус всех сессий
  $0 stop <session_id>   # Остановить сессию
  $0 remove <session_id> # Удалить сессию
  $0 cleanup             # Очистить все сессии
  $0 test                # Запустить неинтерактивное тестирование
  $0 --help              # Показать эту справку

Примеры:
  $0 create claude       # Создать Claude сессию
  $0 connect abc123      # Подключиться к сессии abc123
  $0 status              # Показать все сессии

Особенности:
- Использует существующие авторизационные данные
- Полная изоляция контейнеров
- Неинтерактивный запуск по умолчанию
- UUID4 идентификаторы сессий
- Автоматическое сохранение состояния

EOF
}

# Основной обработчик команд
case "${1:-}" in
    "create")
        if [[ -z "${2:-}" ]]; then
            log_error "❌ Укажите тип AI: claude, gemini, glm"
            exit 1
        fi
        check_dependencies
        create_ai_session "$2"
        ;;
    "connect")
        if [[ -z "${2:-}" ]]; then
            log_error "❌ Укажите ID сессии"
            exit 1
        fi
        connect_to_session "$2"
        ;;
    "status")
        show_sessions_status
        ;;
    "stop")
        if [[ -z "${2:-}" ]]; then
            log_error "❌ Укажите ID сессии"
            exit 1
        fi
        stop_session "$2"
        ;;
    "remove")
        if [[ -z "${2:-}" ]]; then
            log_error "❌ Укажите ID сессии"
            exit 1
        fi
        remove_session "$2"
        ;;
    "cleanup")
        cleanup_all_sessions
        ;;
    "test")
        check_dependencies
        "$PROJECT_ROOT/test-containers-noninteractive.sh"
        ;;
    "--help"|"-h"|"help"|"")
        show_help
        ;;
    *)
        log_error "❌ Неизвестная команда: $1"
        show_help
        exit 1
        ;;
esac