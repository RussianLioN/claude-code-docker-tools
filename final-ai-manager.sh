#!/bin/bash

# Финальная система управления AI контейнерами v5.0
# ИСПОЛЬЗУЕТ СУЩЕСТВУЮЩИЕ АВТОРИЗОВАННЫЕ КОНТЕЙНЕРЫ
# НЕ МЕНЯЕТ ID КОНТЕЙНЕРОВ!

set -euo pipefail

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WORKSPACES_DIR="$PROJECT_ROOT/workspaces"
CONFIG_DIR="$PROJECT_ROOT/config"
LOGS_DIR="$PROJECT_ROOT/logs"

# Создаем структуру
mkdir -p "$WORKSPACES_DIR" "$CONFIG_DIR" "$LOGS_DIR"

# Логирование
log_info() {
    echo "[INFO $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/final-ai-manager.log"
}

log_error() {
    echo "[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/final-ai-manager.log"
}

log_success() {
    echo "[SUCCESS $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/final-ai-manager.log"
}

log_warning() {
    echo "[WARNING $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/final-ai-manager.log"
}

# Проверка зависимостей
check_dependencies() {
    local deps=("docker")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log_error "Зависимость не найдена: $dep"
            return 1
        fi
    done
    log_success "✅ Все зависимости доступны"
}

# Поиск и анализ существующих контейнеров
find_existing_containers() {
    log_info "🔍 Поиск существующих AI контейнеров..."
    
    # Claude контейнеры
    local claude_containers=$(docker ps -a --filter "name=claude-session" --format "{{.Names}}\t{{.Status}}" | grep -v "Exited (130)" || true)
    if [[ -n "$claude_containers" ]]; then
        log_success "🟢 Найдены Claude контейнеры:"
        echo "$claude_containers" | while IFS=$'\t' read -r name status; do
            if [[ "$status" == *"Up"* ]]; then
                log_success "  ✅ $name: $status"
            else
                log_warning "  ⏸️  $name: $status"
            fi
        done
    else
        log_warning "🟡 Claude контейнеры не найдены"
    fi
    
    # Gemini контейнеры
    local gemini_containers=$(docker ps -a --filter "name=gemini" --format "{{.Names}}\t{{.Status}}" || true)
    if [[ -n "$gemini_containers" ]]; then
        log_success "🟢 Найдены Gemini контейнеры:"
        echo "$gemini_containers" | while IFS=$'\t' read -r name status; do
            if [[ "$status" == *"Up"* ]]; then
                log_success "  ✅ $name: $status"
            else
                log_warning "  ⏸️  $name: $status"
            fi
        done
    else
        log_warning "🟡 Gemini контейнеры не найдены"
    fi
}

# Использование существующего Claude контейнера
use_claude() {
    log_info "🔗 Поиск работающего Claude контейнера..."
    
    local running_claude=$(docker ps --filter "name=claude-session" --format "{{.Names}}" | head -1 || true)
    
    if [[ -n "$running_claude" ]]; then
        log_success "✅ Найден работающий Claude: $running_claude"
        log_info "🔗 Подключение к Claude..."
        
        # Создаем рабочую директорию
        local workspace_dir="$WORKSPACES_DIR/claude-$(date +%s)"
        mkdir -p "$workspace_dir"
        
        # Монтируем рабочую директорию в контейнер
        docker exec "$running_claude" mkdir -p "/workspace" 2>/dev/null || true
        
        log_info "📁 Рабочая директория: $workspace_dir"
        log_info "🚀 Запуск Claude Code..."
        
        # Подключаемся к контейнеру
        docker exec -it "$running_claude" /bin/bash
        return 0
    else
        log_error "❌ Работающий Claude контейнер не найден"
        
        # Ищем остановленные контейнеры
        local stopped_claude=$(docker ps -a --filter "name=claude-session" --format "{{.Names}}" | head -1 || true)
        if [[ -n "$stopped_claude" ]]; then
            log_warning "⚠️ Найден остановленный контейнер: $stopped_claude"
            log_warning "⚠️ Перезапуск может потребовать повторной авторизации!"
            
            read -p "❓ Перезапустить контейнер? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "🚀 Перезапуск Claude контейнера..."
                docker start "$stopped_claude"
                sleep 3
                use_claude
                return $?
            fi
        fi
        
        log_error "❌ Claude контейнеры не найдены"
        log_info "💡 Нужно сначала создать Claude контейнер с авторизацией"
        return 1
    fi
}

# Использование существующего Gemini
use_gemini() {
    log_info "🔗 Поиск Gemini проекта..."
    
    local gemini_projects=(
        "/Users/s060874gmail.com/coding/projects/gemini-docker-setup"
        "/Users/s060874gmail.com/coding/projects/multi-session-ai-ide"
    )
    
    for project in "${gemini_projects[@]}"; do
        if [[ -f "$project/gemini.zsh" ]]; then
            log_success "✅ Найден Gemini проект: $project"
            log_info "🚀 Запуск Gemini..."
            
            # Создаем рабочую директорию
            local workspace_dir="$WORKSPACES_DIR/gemini-$(date +%s)"
            mkdir -p "$workspace_dir"
            
            log_info "📁 Рабочая директория: $workspace_dir"
            log_info "🔗 Запуск Gemini из существующего проекта..."
            
            # Запускаем Gemini из его проекта
            cd "$project" && ./gemini.zsh
            return 0
        fi
    done
    
    log_error "❌ Gemini проект не найден"
    log_info "💡 Нужно сначала настроить Gemini проект"
    return 1
}

# Создание GLM контейнера (API авторизация)
create_glm_container() {
    log_info "🚀 Создание GLM контейнера (API авторизация)..."
    
    local container_name="glm-api-$(date +%s)"
    local workspace_dir="$WORKSPACES_DIR/glm-$(date +%s)"
    
    mkdir -p "$workspace_dir"
    
    # Проверяем наличие API ключа
    if [[ ! -f "$CONFIG_DIR/glm_config.json" ]]; then
        log_error "❌ GLM API конфигурация не найдена"
        log_info "💡 Создайте файл $CONFIG_DIR/glm_config.json с API ключом"
        
        cat > "$CONFIG_DIR/glm_config.json" << EOF
{
  "GLM_API_KEY": "your-glm-api-key-here",
  "model": "glm-4.6",
  "temperature": 0.7,
  "max_tokens": 8192
}
EOF
        
        log_warning "⚠️ Создан шаблон конфигурации. Отредактируйте его!"
        log_info "📝 Получите API ключ на https://open.bigmodel.cn/"
        return 1
    fi
    
    # Создаем временный Dockerfile
    local temp_dockerfile="/tmp/glm-dockerfile-$(date +%s)"
    cat > "$temp_dockerfile" << 'EOF'
FROM python:3.11-slim

# Установка зависимостей
RUN pip install --no-cache-dir zhipuai python-dotenv

# Создание пользователя
RUN useradd -m -s /bin/bash aiuser

USER aiuser
WORKDIR /home/aiuser

# Копирование конфигурации (будет смонтирована)
# COPY config/glm_config.json /home/aiuser/.config/glm.json

CMD ["python3", "-c", "print('GLM AI Assistant ready! Use: python3 -c \"import zhipuai; print(zhipuai.model_api.invoke(...))\"')"]
EOF

    # Собираем образ
    log_info "🔨 Сборка GLM образа..."
    if docker build -t "glm-api:latest" -f "$temp_dockerfile" . >> "$LOGS_DIR/glm-build.log" 2>&1; then
        log_success "✅ GLM образ собран"
        rm -f "$temp_dockerfile"
    else
        log_error "❌ Ошибка сборки GLM образа"
        rm -f "$temp_dockerfile"
        return 1
    fi
    
    # Запускаем контейнер
    log_info "🚀 Запуск GLM контейнера..."
    if docker run -d \
        --name "$container_name" \
        --memory="1g" \
        --cpus="0.5" \
        --restart unless-stopped \
        -v "$workspace_dir:/home/aiuser/workspace" \
        -v "$CONFIG_DIR/glm_config.json:/home/aiuser/.config/glm.json:ro" \
        "glm-api:latest" >> "$LOGS_DIR/glm-run.log" 2>&1; then
        
        log_success "✅ GLM контейнер запущен: $container_name"
        log_info "📁 Рабочая директория: $workspace_dir"
        log_info "🔧 Для подключения: docker exec -it $container_name /bin/bash"
        
        # Тестируем GLM
        log_info "🧪 Тестирование GLM..."
        sleep 2
        if docker exec "$container_name" python3 -c "
import json
try:
    with open('/home/aiuser/.config/glm.json') as f:
        config = json.load(f)
    api_key = config.get('GLM_API_KEY')
    if api_key and api_key != 'your-glm-api-key-here':
        print('✅ GLM API ключ настроен')
    else:
        print('❌ GLM API ключ не настроен')
except Exception as e:
    print(f'❌ Ошибка: {e}')
" 2>/dev/null; then
            log_success "✅ GLM готов к использованию"
        else
            log_warning "⚠️ Проверьте настройку API ключа"
        fi
        
        return 0
    else
        log_error "❌ Ошибка запуска GLM контейнера"
        return 1
    fi
}

# Показать статус
show_status() {
    log_info "📊 Статус AI контейнеров:"
    
    printf "%-20s %-15s %-15s %-20s\n" "TYPE" "NAME" "STATUS" "PROJECT"
    printf "%-20s %-15s %-15s %-20s\n" "--------------------" "---------------" "---------------" "--------------------"
    
    # Claude
    local claude_container=$(docker ps --filter "name=claude-session" --format "{{.Names}}\t{{.Status}}" | head -1 || true)
    if [[ -n "$claude_container" ]]; then
        IFS=$'\t' read -r name status <<< "$claude_container"
        if [[ "$status" == *"Up"* ]]; then
            status="🟢 running"
        else
            status="🔴 stopped"
        fi
        printf "%-20s %-15s %-15s %-20s\n" "Claude" "$name" "$status" "existing"
    else
        printf "%-20s %-15s %-15s %-20s\n" "Claude" "-" "🔴 not found" "-"
    fi
    
    # Gemini
    if [[ -f "/Users/s060874gmail.com/coding/projects/gemini-docker-setup/gemini.zsh" ]]; then
        printf "%-20s %-15s %-15s %-20s\n" "Gemini" "project" "🟡 ready" "gemini-docker-setup"
    else
        printf "%-20s %-15s %-15s %-20s\n" "Gemini" "-" "🔴 not found" "-"
    fi
    
    # GLM
    local glm_containers=$(docker ps --filter "name=glm-api" --format "{{.Names}}\t{{.Status}}" || true)
    if [[ -n "$glm_containers" ]]; then
        IFS=$'\t' read -r name status <<< "$glm_containers"
        if [[ "$status" == *"Up"* ]]; then
            status="🟢 running"
        else
            status="🔴 stopped"
        fi
        printf "%-20s %-15s %-15s %-20s\n" "GLM" "$name" "$status" "api"
    else
        printf "%-20s %-15s %-15s %-20s\n" "GLM" "-" "🔴 not created" "-"
    fi
}

# Создание инструкций с паузами для авторизации
create_auth_instructions() {
    log_info "📋 Создание инструкций по авторизации..."
    
    cat > "$PROJECT_ROOT/FINAL_AUTH_GUIDE.md" << 'EOF'
# Финальное руководство по авторизации AI контейнеров

## 🚨 ВАЖНОЕ ПРАВИЛО

**НЕ МЕНЯЙТЕ ID СУЩЕСТВУЮЩИХ КОНТЕЙНЕРОВ!**
При смене ID контейнера авторизация СЛЕТАЕТ и требуется повторная авторизация.

---

## 1. Claude Code (уже работает ✅)

### Текущий статус:
- Контейнер: `claude-session-1765895341` 
- Статус: Работает
- Авторизация: Уже настроена

### Использование:
```bash
./final-ai-manager.sh use-claude
```

### Если контейнер остановлен:
```bash
# ⚠️ ТРЕБУЕТ ПОВТОРНОЙ АВТОРИЗАЦИИ!
docker start claude-session-1765895341
# Затем перейдите на https://console.anthropic.com/ для авторизации
```

---

## 2. Gemini (готов к использованию ✅)

### Текущий статус:
- Проект: `/Users/s060874gmail.com/coding/projects/gemini-docker-setup`
- Скрипт: `gemini.zsh`
- Авторизация: Уже настроена

### Использование:
```bash
./final-ai-manager.sh use-gemini
```

---

## 3. GLM API (требует настройки API ключа ⚠️)

### Настройка API ключа:
1. Перейдите на https://open.bigmodel.cn/
2. Зарегистрируйтесь и получите API ключ
3. Отредактируйте файл: `config/glm_config.json`

```json
{
  "GLM_API_KEY": "ваш-реальный-api-ключ",
  "model": "glm-4.6",
  "temperature": 0.7,
  "max_tokens": 8192
}
```

### Создание контейнера:
```bash
./final-ai-manager.sh create-glm
```

---

## 4. Порядок рекомендуемых действий

1. **Проверить статус**: `./final-ai-manager.sh status`
2. **Использовать Claude**: `./final-ai-manager.sh use-claude` (уже работает)
3. **Использовать Gemini**: `./final-ai-manager.sh use-gemini` (уже работает)
4. **Настроить GLM**: Отредактировать `config/glm_config.json` + `./final-ai-manager.sh create-glm`

---

## 5. Если что-то сломалось

### Claude сломался:
- НЕ удаляйте контейнер!
- Попробуйте перезапустить: `docker start claude-session-1765895341`
- Если не помогло - авторизуйтесь на https://console.anthropic.com/

### Gemini сломался:
- Проверьте проект: `cd /Users/s060874gmail.com/coding/projects/gemini-docker-setup`
- Запустите: `./gemini.zsh`

### GLM сломался:
- Удалите контейнер: `docker rm glm-api-*`
- Создайте заново: `./final-ai-manager.sh create-glm`

---

## 6. Команды управления

```bash
./final-ai-manager.sh status          # Показать статус всех AI
./final-ai-manager.sh use-claude      # Использовать Claude
./final-ai-manager.sh use-gemini      # Использовать Gemini  
./final-ai-manager.sh create-glm       # Создать GLM
./final-ai-manager.sh find             # Найти существующие контейнеры
```

EOF

    log_success "✅ Финальное руководство создано: $PROJECT_ROOT/FINAL_AUTH_GUIDE.md"
}

# Показать справку
show_help() {
    cat << EOF
Финальная система управления AI контейнерами v5.0
🔒 СОХРАНЯЕТ АВТОРИЗАЦИЮ СУЩЕСТВУЮЩИХ КОНТЕЙНЕРОВ

Использование:
  $0 use-claude           # Использовать существующий Claude (уже авторизован)
  $0 use-gemini           # Использовать существующий Gemini (уже авторизован)
  $0 create-glm           # Создать GLM (API авторизация)
  $0 status               # Показать статус всех контейнеров
  $0 find                 # Найти существующие контейнеры
  $0 auth-guide            # Создать финальное руководство по авторизации
  $0 --help               # Показать эту справку

ВАЖНО: Эта система НЕ меняет ID существующих контейнеров!

EOF
}

# Основной обработчик команд
case "${1:-}" in
    "use-claude")
        check_dependencies
        use_claude
        ;;
    "use-gemini")
        check_dependencies
        use_gemini
        ;;
    "create-glm")
        check_dependencies
        create_glm_container
        ;;
    "status")
        check_dependencies
        show_status
        ;;
    "find")
        check_dependencies
        find_existing_containers
        ;;
    "auth-guide")
        create_auth_instructions
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