#!/bin/bash

# Система управления AI контейнерами с сохранением авторизации v3.0
# КЛЮЧЕВОЕ ПРАВИЛО: Не менять ID существующих авторизованных контейнеров!

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

log_warning() {
    echo "[WARNING $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/ai-assistant.log"
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

# Анализ существующих контейнеров
analyze_existing_containers() {
    log_info "🔍 Анализ существующих AI контейнеров..."
    
    # Поиск работающих Claude контейнеров
    local claude_containers=$(docker ps -a --filter "name=claude-session" --format "{{.Names}}\t{{.Status}}" | grep -v "Exited (130)" || true)
    if [[ -n "$claude_containers" ]]; then
        log_info "🟢 Найдены работающие Claude контейнеры:"
        echo "$claude_containers" | while IFS=$'\t' read -r name status; do
            log_info "  - $name: $status"
        done
    else
        log_warning "🟡 Работающие Claude контейнеры не найдены"
    fi
    
    # Поиск Gemini контейнеров в системе
    local gemini_containers=$(docker ps -a --filter "name=gemini" --format "{{.Names}}\t{{.Status}}" || true)
    if [[ -n "$gemini_containers" ]]; then
        log_info "🟢 Найдены Gemini контейнеры:"
        echo "$gemini_containers" | while IFS=$'\t' read -r name status; do
            log_info "  - $name: $status"
        done
    else
        log_warning "🟡 Gemini контейнеры не найдены"
    fi
    
    # Проверка авторизационных данных
    if [[ -f "$HOME/.docker-ai-config/claude_config.json" ]]; then
        log_info "✅ Найдены Claude OAuth данные"
    else
        log_warning "⚠️ Claude OAuth данные не найдены"
    fi
    
    if [[ -f "$HOME/.gemini-state" ]]; then
        log_info "✅ Найдены Gemini state данные"
    else
        log_warning "⚠️ Gemini state данные не найдены"
    fi
}

# Использование существующего авторизованного Claude контейнера
use_existing_claude() {
    log_info "🔗 Поиск работающего Claude контейнера..."
    
    # Ищем запущенный Claude контейнер
    local running_claude=$(docker ps --filter "name=claude-session" --format "{{.Names}}" | head -1 || true)
    
    if [[ -n "$running_claude" ]]; then
        log_success "✅ Найден работающий Claude контейнер: $running_claude"
        log_info "🔗 Подключение к существующему контейнеру..."
        
        # Создаем символическую ссылку на сессию
        local session_id="claude-existing-$(date +%s)"
        mkdir -p "$SESSIONS_DIR/$session_id"
        
        cat > "$SESSIONS_DIR/$session_id/session.json" << EOF
{
    "session_id": "$session_id",
    "ai_type": "claude",
    "container_name": "$running_claude",
    "image_name": "claude-code-tools",
    "created_at": "$(date -Iseconds)",
    "status": "running",
    "type": "existing",
    "note": "Используется существующий авторизованный контейнер"
}
EOF
        
        log_info "✅ Сессия создана: $session_id"
        log_info "🔧 Для подключения: $0 connect $session_id"
        
        # Подключаем к контейнеру
        docker exec -it "$running_claude" /bin/bash
        return 0
    else
        log_error "❌ Работающий Claude контейнер не найден"
        log_info "💡 Сначала запустите Claude: ./ai-assistant.zsh"
        return 1
    fi
}

# Создание новой Claude сессии (с авторизацией пользователя)
create_new_claude_session() {
    log_warning "⚠️ ВНИМАНИЕ: Будет создан НОВЫЙ Claude контейнер"
    log_warning "⚠️ Это потребует повторной авторизации на сайте Anthropic"
    log_info "📋 Инструкция по авторизации:"
    log_info "   1. Перейдите на https://console.anthropic.com/"
    log_info "   2. Войдите в свою учетную запись"
    log_info "   3. Следуйте инструкциям для подключения Claude Code"
    
    read -p "❓ Продолжить созданием нового контейнера? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "❌ Отмена создания нового контейнера"
        return 1
    fi
    
    # Используем существующий скрипт для создания Claude
    log_info "🚀 Запуск создания нового Claude контейнера..."
    "$PROJECT_ROOT/ai-assistant.zsh"
}

# Использование существующего Gemini (если найден)
use_existing_gemini() {
    log_info "🔗 Поиск Gemini конфигурации..."
    
    # Проверяем старые проекты
    local gemini_projects=(
        "/Users/s060874gmail.com/coding/projects/gemini-docker-setup"
        "/Users/s060874gmail.com/coding/projects/multi-session-ai-ide"
    )
    
    for project in "${gemini_projects[@]}"; do
        if [[ -f "$project/gemini.zsh" ]]; then
            log_success "✅ Найден Gemini проект: $project"
            log_info "🔗 Запуск Gemini из существующего проекта..."
            
            # Создаем символическую ссылку на сессию
            local session_id="gemini-existing-$(date +%s)"
            mkdir -p "$SESSIONS_DIR/$session_id"
            
            cat > "$SESSIONS_DIR/$session_id/session.json" << EOF
{
    "session_id": "$session_id",
    "ai_type": "gemini",
    "container_name": "gemini-existing",
    "image_name": "gemini-cli",
    "created_at": "$(date -Iseconds)",
    "status": "running",
    "type": "existing",
    "project_path": "$project",
    "note": "Используется существующий Gemini проект"
}
EOF
            
            log_info "✅ Сессия создана: $session_id"
            log_info "🔧 Для подключения: $0 connect $session_id"
            
            # Запускаем Gemini из существующего проекта
            cd "$project" && ./gemini.zsh
            return 0
        fi
    done
    
    log_error "❌ Работающий Gemini проект не найден"
    log_info "💡 Нужно сначала настроить Gemini в одном из проектов"
    return 1
}

# Создание GLM контейнера (использует API, не требует авторизации на сайте)
create_glm_session() {
    log_info "🚀 Создание GLM сессии (использует API ключ)..."
    
    local session_id="glm-$(date +%s)"
    local session_dir="$SESSIONS_DIR/$session_id"
    local container_name="glm-$session_id"
    
    mkdir -p "$session_dir/config"
    
    # Проверяем наличие API ключа
    if [[ -f "$CONFIG_DIR/glm_config.json" ]]; then
        cp "$CONFIG_DIR/glm_config.json" "$session_dir/config/"
        log_info "✅ GLM API конфигурация скопирована"
    else
        log_error "❌ GLM API ключ не найден в $CONFIG_DIR/glm_config.json"
        log_info "💡 Создайте файл с API ключом от zhipuai.ai"
        return 1
    fi
    
    # Создаем Dockerfile для GLM
    cat > "$session_dir/Dockerfile" << 'EOF'
FROM python:3.11-slim

# Установка зависимостей
RUN pip install --no-cache-dir zhipuai python-dotenv

# Создание пользователя
RUN useradd -m -s /bin/bash aiuser

USER aiuser
WORKDIR /home/aiuser

# Копирование конфигурации
COPY --chown=aiuser:aiuser config/glm_config.json /home/aiuser/.config/glm.json

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "import zhipuai; print('GLM healthy')" || exit 1

CMD ["python3", "-c", "print('GLM AI Assistant ready!')"]
EOF

    # Сборка и запуск
    log_info "🔨 Сборка GLM образа..."
    if docker build -t "glm-session:$session_id" "$session_dir" >> "$LOGS_DIR/glm-build-$session_id.log" 2>&1; then
        log_success "✅ GLM образ собран"
    else
        log_error "❌ Ошибка сборки GLM образа"
        return 1
    fi
    
    log_info "🚀 Запуск GLM контейнера..."
    if docker run -d \
        --name "$container_name" \
        --memory="1g" \
        --cpus="0.5" \
        --restart unless-stopped \
        "glm-session:$session_id" >> "$LOGS_DIR/glm-run-$session_id.log" 2>&1; then
        
        log_success "✅ GLM контейнер запущен: $container_name"
        
        cat > "$session_dir/session.json" << EOF
{
    "session_id": "$session_id",
    "ai_type": "glm",
    "container_name": "$container_name",
    "image_name": "glm-session:$session_id",
    "created_at": "$(date -Iseconds)",
    "status": "running",
    "type": "new",
    "note": "GLM использует API ключ, авторизация на сайте не требуется"
}
EOF
        
        log_info "✅ GLM сессия создана: $session_id"
        echo "$session_id"
        return 0
    else
        log_error "❌ Ошибка запуска GLM контейнера"
        return 1
    fi
}

# Подключение к сессии
connect_to_session() {
    local session_id="$1"
    local session_file="$SESSIONS_DIR/$session_id/session.json"
    
    if [[ ! -f "$session_file" ]]; then
        log_error "❌ Сессия не найдена: $session_id"
        return 1
    fi
    
    local ai_type=$(jq -r '.ai_type' "$session_file")
    local session_type=$(jq -r '.type' "$session_file")
    
    log_info "🔗 Подключение к сессии $session_id ($ai_type, $session_type)"
    
    case "$ai_type" in
        "claude")
            if [[ "$session_type" == "existing" ]]; then
                local container_name=$(jq -r '.container_name' "$session_file")
                docker exec -it "$container_name" /bin/bash
            else
                log_error "❌ Подключение к новым Claude сессиям требует доработки"
                return 1
            fi
            ;;
        "gemini")
            if [[ "$session_type" == "existing" ]]; then
                local project_path=$(jq -r '.project_path' "$session_file")
                cd "$project_path" && ./gemini.zsh
            else
                log_error "❌ Подключение к новым Gemini сессиям требует доработки"
                return 1
            fi
            ;;
        "glm")
            local container_name=$(jq -r '.container_name' "$session_file")
            docker exec -it "$container_name" /bin/bash
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
    
    printf "%-25s %-10s %-15s %-20s %-10s\n" "SESSION_ID" "AI_TYPE" "TYPE" "CREATED" "STATUS"
    printf "%-25s %-10s %-15s %-20s %-10s\n" "-------------------------" "----------" "---------------" "--------------------" "----------"
    
    for session_dir in "$SESSIONS_DIR"/*; do
        if [[ -d "$session_dir" && -f "$session_dir/session.json" ]]; then
            local session_id=$(basename "$session_dir")
            local session_file="$session_dir/session.json"
            
            local ai_type=$(jq -r '.ai_type' "$session_file" 2>/dev/null || echo "unknown")
            local session_type=$(jq -r '.type' "$session_file" 2>/dev/null || echo "unknown")
            local created_at=$(jq -r '.created_at' "$session_file" 2>/dev/null || echo "unknown")
            
            local created_short=$(date -d "$created_at" '+%m/%d %H:%M' 2>/dev/null || echo "unknown")
            
            printf "%-25s %-10s %-15s %-20s %-10s\n" "$session_id" "$ai_type" "$session_type" "$created_short" "active"
        fi
    done
}

# Показать справку
show_help() {
    cat << EOF
Система управления AI контейнерами с сохранением авторизации v3.0

КЛЮЧЕВОЕ ПРАВИЛО: Не менять ID существующих авторизованных контейнеров!

Использование:
  $0 analyze                    # Анализ существующих контейнеров
  $0 use-claude                 # Использовать существующий Claude
  $0 new-claude                 # Создать новый Claude (требует авторизации)
  $0 use-gemini                 # Использовать существующий Gemini
  $0 create-glm                 # Создать GLM сессию (API ключ)
  $0 connect <session_id>       # Подключиться к сессии
  $0 status                     # Показать статус сессий
  $0 --help                     # Показать эту справку

Авторизация:
- Claude: Требуется авторизация на console.anthropic.com
- Gemini: Использует существующие проекты
- GLM: Использует API ключ (без авторизации на сайте)

EOF
}

# Основной обработчик команд
case "${1:-}" in
    "analyze")
        check_dependencies
        analyze_existing_containers
        ;;
    "use-claude")
        check_dependencies
        use_existing_claude
        ;;
    "new-claude")
        check_dependencies
        create_new_claude_session
        ;;
    "use-gemini")
        check_dependencies
        use_existing_gemini
        ;;
    "create-glm")
        check_dependencies
        create_glm_session
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
    "--help"|"-h"|"help"|"")
        show_help
        ;;
    *)
        log_error "❌ Неизвестная команда: $1"
        show_help
        exit 1
        ;;
esac