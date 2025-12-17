#!/bin/bash

# Интерактивная система управления AI контейнерами v6.0
# С паузами для явного ввода пользователя

set -euo pipefail

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WORKSPACES_DIR="$PROJECT_ROOT/workspaces"
CONFIG_DIR="$PROJECT_ROOT/config"
LOGS_DIR="$PROJECT_ROOT/logs"
USER_INPUT_FILE="$PROJECT_ROOT/.user_input.tmp"

# Создаем структуру
mkdir -p "$WORKSPACES_DIR" "$CONFIG_DIR" "$LOGS_DIR"

# Логирование
log_info() {
    echo "[INFO $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/interactive-ai-manager.log"
}

log_error() {
    echo "[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/interactive-ai-manager.log"
}

log_success() {
    echo "[SUCCESS $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/interactive-ai-manager.log"
}

log_warning() {
    echo "[WARNING $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/interactive-ai-manager.log"
}

# Функция ожидания ввода пользователя
wait_for_user_input() {
    local prompt="$1"
    local var_name="$2"
    local default_value="${3:-}"
    
    echo ""
    echo "🔸 $prompt"
    if [[ -n "$default_value" ]]; then
        echo "🔸 По умолчанию: $default_value"
    fi
    echo "🔸 Введите ответ и нажмите Enter:"
    echo -n "> "
    
    # Читаем ввод пользователя
    read user_input
    
    if [[ -z "$user_input" && -n "$default_value" ]]; then
        user_input="$default_value"
    fi
    
    # Сохраняем в переменную
    printf -v "$var_name" '%s' "$user_input"
    
    echo "✅ Введено: $user_input"
    echo ""
}

# Функция ожидания подтверждения
wait_for_confirmation() {
    local prompt="$1"
    local default="${2:-N}"
    
    echo ""
    echo "❓ $prompt"
    echo "🔸 Введите 'y' или 'Y' для подтверждения (по умолчанию: $default):"
    echo -n "> "
    
    read confirmation
    
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

# Проверка зависимостей
check_dependencies() {
    log_info "🔍 Проверка зависимостей..."
    local deps=("docker")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "❌ Отсутствуют зависимости: ${missing_deps[*]}"
        log_info "💡 Установите их и повторите попытку"
        return 1
    fi
    
    log_success "✅ Все зависимости доступны"
    return 0
}

# Анализ существующих контейнеров
analyze_existing_containers() {
    log_info "🔍 Анализ существующих AI контейнеров..."
    
    echo ""
    echo "=== ПОИСК CLAUDE КОНТЕЙНЕРОВ ==="
    
    local claude_containers=$(docker ps -a --filter "name=claude-session" --format "{{.Names}}\t{{.Status}}\t{{.CreatedAt}}" 2>/dev/null || true)
    
    if [[ -n "$claude_containers" ]]; then
        echo "🟢 Найдены Claude контейнеры:"
        echo "$claude_containers" | while IFS=$'\t' read -r name status created; do
            if [[ "$status" == *"Up"* ]]; then
                echo "  ✅ $name - $status (создан: $created)"
            else
                echo "  ⏸️  $name - $status (создан: $created)"
            fi
        done
    else
        echo "🟡 Claude контейнеры не найдены"
    fi
    
    echo ""
    echo "=== ПОИСК GEMINI ПРОЕКТОВ ==="
    
    local gemini_projects=(
        "/Users/s060874gmail.com/coding/projects/gemini-docker-setup"
        "/Users/s060874gmail.com/coding/projects/multi-session-ai-ide"
    )
    
    local found_gemini=false
    for project in "${gemini_projects[@]}"; do
        if [[ -f "$project/gemini.zsh" ]]; then
            echo "🟢 Найден Gemini проект: $project"
            found_gemini=true
        fi
    done
    
    if [[ "$found_gemini" == false ]]; then
        echo "🟡 Gemini проекты не найдены"
    fi
    
    echo ""
    echo "=== ПОИСК GLM КОНТЕЙНЕРОВ ==="
    
    local glm_containers=$(docker ps -a --filter "name=glm-api" --format "{{.Names}}\t{{.Status}}" 2>/dev/null || true)
    
    if [[ -n "$glm_containers" ]]; then
        echo "🟢 Найдены GLM контейнеры:"
        echo "$glm_containers" | while IFS=$'\t' read -r name status; do
            if [[ "$status" == *"Up"* ]]; then
                echo "  ✅ $name - $status"
            else
                echo "  ⏸️  $name - $status"
            fi
        done
    else
        echo "🟡 GLM контейнеры не найдены"
    fi
    
    echo ""
}

# Интерактивное использование Claude
interactive_claude() {
    log_info "🔗 Поиск работающих Claude контейнеров..."
    
    local running_claude=$(docker ps --filter "name=claude-session" --format "{{.Names}}" 2>/dev/null | head -1 || true)
    
    if [[ -n "$running_claude" ]]; then
        log_success "✅ Найден работающий Claude: $running_claude"
        
        if wait_for_confirmation "Подключиться к Claude контейнеру $running_claude?" "Y"; then
            echo ""
            echo "🚀 Подключение к Claude..."
            echo "💡 Для выхода из контейнера используйте: exit"
            echo ""
            
            # Создаем рабочую директорию
            local workspace_dir="$WORKSPACES_DIR/claude-$(date +%s)"
            mkdir -p "$workspace_dir"
            
            echo "📁 Рабочая директория создана: $workspace_dir"
            echo ""
            
            # Подключаемся к контейнеру
            docker exec -it "$running_claude" /bin/bash
            
            echo ""
            log_info "🔚 Сессия Claude завершена"
        fi
    else
        log_warning "⚠️ Работающие Claude контейнеры не найдены"
        
        # Ищем остановленные
        local stopped_claude=$(docker ps -a --filter "name=claude-session" --format "{{.Names}}" 2>/dev/null | head -1 || true)
        
        if [[ -n "$stopped_claude" ]]; then
            log_warning "⚠️ Найден остановленный контейнер: $stopped_claude"
            
            if wait_for_confirmation "Перезапустить контейнер $stopped_claude? ⚠️ Это может потребовать повторной авторизации!" "N"; then
                echo ""
                echo "🔄 Перезапуск контейнера..."
                
                if docker start "$stopped_claude" 2>/dev/null; then
                    log_success "✅ Контейнер перезапущен"
                    sleep 3
                    
                    echo ""
                    echo "🔸 ВАЖНО: Если контейнер запрашивает авторизацию:"
                    echo "🔸 1. Перейдите на https://console.anthropic.com/"
                    echo "🔸 2. Войдите в свою учетную запись"
                    echo "🔸 3. Следуйте инструкциям Claude Code"
                    echo ""
                    
                    wait_for_user_input "Нажмите Enter после завершения авторизации" dummy_var
                    
                    # Повторная попытка подключения
                    interactive_claude
                else
                    log_error "❌ Не удалось перезапустить контейнер"
                fi
            fi
        else
            log_error "❌ Claude контейнеры не найдены"
            echo ""
            echo "💡 Для создания Claude контейнера требуется:"
            echo "   1. Подписка на https://console.anthropic.com/"
            echo "   2. Запуск скрипта создания контейнера"
            echo ""
        fi
    fi
}

# Интерактивное использование Gemini
interactive_gemini() {
    log_info "🔗 Поиск Gemini проектов..."
    
    local gemini_projects=(
        "/Users/s060874gmail.com/coding/projects/gemini-docker-setup"
        "/Users/s060874gmail.com/coding/projects/multi-session-ai-ide"
    )
    
    local available_projects=()
    
    for project in "${gemini_projects[@]}"; do
        if [[ -f "$project/gemini.zsh" ]]; then
            available_projects+=("$project")
        fi
    done
    
    if [[ ${#available_projects[@]} -gt 0 ]]; then
        echo "🟢 Найдены Gemini проекты:"
        for i in "${!available_projects[@]}"; do
            echo "  $((i+1)). ${available_projects[i]}"
        done
        
        echo ""
        wait_for_user_input "Выберите проект (1-${#available_projects[@]})" project_choice "1"
        
        local selected_project="${available_projects[$((project_choice-1))]}"
        
        if [[ -n "$selected_project" ]]; then
            log_success "✅ Выбран проект: $selected_project"
            
            if wait_for_confirmation "Запустить Gemini из выбранного проекта?" "Y"; then
                echo ""
                echo "🚀 Запуск Gemini..."
                echo "💡 Проект будет запущен в отдельной директории"
                echo ""
                
                # Создаем рабочую директорию
                local workspace_dir="$WORKSPACES_DIR/gemini-$(date +%s)"
                mkdir -p "$workspace_dir"
                
                echo "📁 Рабочая директория: $workspace_dir"
                echo ""
                
                # Запускаем Gemini из его проекта
                cd "$selected_project" && ./gemini.zsh
                
                echo ""
                log_info "🔚 Сессия Gemini завершена"
            fi
        fi
    else
        log_error "❌ Gemini проекты не найдены"
        echo ""
        echo "💡 Для настройки Gemini требуется:"
        echo "   1. API ключ с https://makersuite.google.com/app/apikey"
        echo "   2. Настройка проекта"
        echo ""
    fi
}

# Интерактивное создание GLM
interactive_glm() {
    log_info "🚀 Создание GLM контейнера с API авторизацией..."
    
    # Проверяем наличие API ключа
    local glm_config="$CONFIG_DIR/glm_config.json"
    local api_key_set=false
    
    if [[ -f "$glm_config" ]]; then
        local api_key=$(grep -o '"GLM_API_KEY":[[:space:]]*"[^"]*"' "$glm_config" | cut -d'"' -f4 || echo "")
        
        if [[ -n "$api_key" && "$api_key" != "your-glm-api-key-here" ]]; then
            api_key_set=true
            log_success "✅ GLM API ключ уже настроен"
        else
            log_warning "⚠️ GLM API ключ не настроен"
        fi
    else
        log_warning "⚠️ Файл конфигурации GLM не найден"
    fi
    
    if [[ "$api_key_set" == false ]]; then
        echo ""
        echo "🔸 Для настройки GLM требуется API ключ:"
        echo "🔸 1. Перейдите на https://open.bigmodel.cn/"
        echo "🔸 2. Зарегистрируйтесь и получите API ключ"
        echo ""
        
        wait_for_user_input "Введите ваш GLM API ключ" glm_api_key
        
        if [[ -n "$glm_api_key" && "$glm_api_key" != "your-glm-api-key-here" ]]; then
            # Создаем конфигурационный файл
            cat > "$glm_config" << EOF
{
  "GLM_API_KEY": "$glm_api_key",
  "model": "glm-4.6",
  "temperature": 0.7,
  "max_tokens": 8192
}
EOF
            log_success "✅ GLM API ключ сохранен в $glm_config"
            api_key_set=true
        else
            log_error "❌ Некорректный API ключ"
            return 1
        fi
    fi
    
    if [[ "$api_key_set" == true ]]; then
        if wait_for_confirmation "Создать GLM контейнер?" "Y"; then
            echo ""
            echo "🔨 Создание GLM контейнера..."
            
            local container_name="glm-api-$(date +%s)"
            local workspace_dir="$WORKSPACES_DIR/glm-$(date +%s)"
            mkdir -p "$workspace_dir"
            
            # Создаем временный Dockerfile
            local temp_dockerfile="/tmp/glm-dockerfile-$(date +%s)"
            cat > "$temp_dockerfile" << 'EOF'
FROM python:3.11-slim

RUN pip install --no-cache-dir zhipuai python-dotenv
RUN useradd -m -s /bin/bash aiuser

USER aiuser
WORKDIR /home/aiuser

CMD ["python3", "-c", "print('GLM AI Assistant ready!')"]
EOF

            # Собираем образ
            echo "📦 Сборка образа..."
            if docker build -t "glm-api:latest" -f "$temp_dockerfile" . >> "$LOGS_DIR/glm-build.log" 2>&1; then
                rm -f "$temp_dockerfile"
                log_success "✅ Образ собран"
                
                # Запускаем контейнер
                echo "🚀 Запуск контейнера..."
                if docker run -d \
                    --name "$container_name" \
                    --memory="1g" \
                    --cpus="0.5" \
                    --restart unless-stopped \
                    -v "$workspace_dir:/home/aiuser/workspace" \
                    -v "$glm_config:/home/aiuser/.config/glm.json:ro" \
                    "glm-api:latest" >> "$LOGS_DIR/glm-run.log" 2>&1; then
                    
                    log_success "✅ GLM контейнер создан: $container_name"
                    echo "📁 Рабочая директория: $workspace_dir"
                    
                    if wait_for_confirmation "Подключиться к GLM контейнеру?" "N"; then
                        echo ""
                        echo "🔗 Подключение к GLM..."
                        docker exec -it "$container_name" /bin/bash
                    fi
                else
                    log_error "❌ Ошибка запуска контейнера"
                fi
            else
                log_error "❌ Ошибка сборки образа"
                rm -f "$temp_dockerfile"
            fi
        fi
    fi
}

# Интерактивное меню
show_interactive_menu() {
    while true; do
        echo ""
        echo "=== ИНТЕРАКТИВНАЯ СИСТЕМА УПРАВЛЕНИЯ AI КОНТЕЙНЕРАМИ ==="
        echo ""
        echo "1. 🔍 Проанализировать существующие контейнеры"
        echo "2. 🤖 Использовать Claude Code"
        echo "3. 💎 Использовать Gemini"
        echo "4. 🐉 Создать/использовать GLM"
        echo "5. 📊 Показать статус всех контейнеров"
        echo "6. ❓ Помощь"
        echo "7. 🚪 Выход"
        echo ""
        
        wait_for_user_input "Выберите действие (1-7)" choice
        
        case "$choice" in
            "1")
                analyze_existing_containers
                ;;
            "2")
                interactive_claude
                ;;
            "3")
                interactive_gemini
                ;;
            "4")
                interactive_glm
                ;;
            "5")
                check_dependencies
                echo ""
                echo "=== СТАТУС КОНТЕЙНЕРОВ ==="
                analyze_existing_containers
                ;;
            "6")
                show_help
                ;;
            "7")
                echo "👋 До свидания!"
                exit 0
                ;;
            *)
                log_warning "⚠️ Некорректный выбор. Попробуйте снова."
                ;;
        esac
        
        echo ""
        if wait_for_confirmation "Продолжить работу?" "Y"; then
            continue
        else
            echo "👋 До свидания!"
            exit 0
        fi
    done
}

# Показать справку
show_help() {
    cat << EOF
Интерактивная система управления AI контейнерами v6.0

Особенности:
- 🔸 Интерактивные диалоги с пользователем
- 🔸 Паузы для явного ввода
- 🔸 Сохранение авторизации существующих контейнеров
- 🔸 Подробные инструкции и подсказки

Использование:
  $0                          # Запустить интерактивное меню
  $0 analyze                   # Проанализировать контейнеры
  $0 claude                    # Интерактивная работа с Claude
  $0 gemini                    # Интерактивная работа с Gemini
  $0 glm                       # Интерактивная работа с GLM
  $0 --help                    # Показать эту справку

EOF
}

# Основной обработчик команд
case "${1:-menu}" in
    "menu"|"")
        check_dependencies
        show_interactive_menu
        ;;
    "analyze")
        check_dependencies
        analyze_existing_containers
        ;;
    "claude")
        check_dependencies
        interactive_claude
        ;;
    "gemini")
        check_dependencies
        interactive_gemini
        ;;
    "glm")
        check_dependencies
        interactive_glm
        ;;
    "--help"|"-h"|"help")
        show_help
        ;;
    *)
        log_error "❌ Неизвестная команда: $1"
        show_help
        exit 1
        ;;
esac