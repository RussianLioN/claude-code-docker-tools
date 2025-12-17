#!/bin/bash

# Новая система управления AI контейнерами v4.0
# Чистая структура с правильной авторизацией

set -euo pipefail

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONTAINERS_DIR="$PROJECT_ROOT/containers"
CONFIG_DIR="$PROJECT_ROOT/config"
LOGS_DIR="$PROJECT_ROOT/logs"

# Создаем структуру директорий
mkdir -p "$CONTAINERS_DIR"/{claude-glm,claude-auth,gemini-auth} "$CONFIG_DIR" "$LOGS_DIR"

# Логирование
log_info() {
    echo "[INFO $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/ai-manager.log"
}

log_error() {
    echo "[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/ai-manager.log"
}

log_success() {
    echo "[SUCCESS $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/ai-manager.log"
}

log_warning() {
    echo "[WARNING $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/ai-manager.log"
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
    log_success "✅ Все зависимости доступны"
}

# Создание Claude Code контейнера для GLM (API авторизация)
create_claude_glm_container() {
    log_info "🚀 Создание Claude Code контейнера для GLM..."
    
    local container_name="claude-glm"
    local workspace_dir="$PROJECT_ROOT/workspaces/claude-glm"
    
    # Создание рабочей директории
    mkdir -p "$workspace_dir" "$CONTAINERS_DIR/claude-glm"
    
    # Создаем Dockerfile для Claude + GLM
    cat > "$CONTAINERS_DIR/claude-glm/Dockerfile" << 'EOF'
FROM mcr.microsoft.com/devcontainers/javascript-node:20

# Установка Claude Code
RUN npm install -g @anthropic-ai/claude-3-dev

# Установка Python для GLM
RUN apt-get update && apt-get install -y python3 python3-pip && rm -rf /var/lib/apt/lists/*

# Установка GLM библиотеки
RUN pip3 install --no-cache-dir zhipuai

# Создание пользователя
RUN useradd -m -s /bin/bash aiuser && \
    mkdir -p /home/aiuser/.config && \
    chown -R aiuser:aiuser /home/aiuser

USER aiuser
WORKDIR /home/aiuser

# Настройка окружения
ENV PATH="/home/aiuser/.local/bin:$PATH"
ENV HOME="/home/aiuser"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "console.log('Claude GLM container healthy')" || exit 1

# Копирование конфигурации GLM
COPY --chown=aiuser:aiuser config/glm_config.json /home/aiuser/.config/glm.json

# Скрипт для запуска GLM в Claude
COPY --chown=aiuser:aiuser scripts/claude-glm-wrapper.sh /home/aiuser/claude-glm.sh
RUN chmod +x /home/aiuser/claude-glm.sh

CMD ["/home/aiuser/claude-glm.sh"]
EOF

    # Создаем конфигурацию GLM
    cat > "$CONFIG_DIR/glm_config.json" << EOF
{
  "GLM_API_KEY": "your-glm-api-key-here",
  "model": "glm-4.6",
  "temperature": 0.7,
  "max_tokens": 8192,
  "description": "GLM API конфигурация для Claude Code"
}
EOF

    # Создаем скрипт-обертку для Claude + GLM
    mkdir -p "$PROJECT_ROOT/scripts"
    cat > "$PROJECT_ROOT/scripts/claude-glm-wrapper.sh" << 'EOF'
#!/bin/bash

# Claude Code + GLM wrapper
echo "🤖 Claude Code с интеграцией GLM-4.6"
echo "📋 Доступные команды:"
echo "  claude              # Запуск Claude Code"
echo "  glm-test            # Тест GLM API"
echo "  help                # Показать эту справку"
echo ""

# Функция теста GLM API
glm-test() {
    if [[ ! -f "/home/aiuser/.config/glm.json" ]]; then
        echo "❌ Конфигурация GLM не найдена"
        return 1
    fi
    
    python3 -c "
import json
import zhipuai

try:
    with open('/home/aiuser/.config/glm.json') as f:
        config = json.load(f)
    
    api_key = config.get('GLM_API_KEY')
    if not api_key or api_key == 'your-glm-api-key-here':
        print('❌ GLM API ключ не настроен')
        print('💡 Отредактируйте /home/aiuser/.config/glm.json')
        return
    
    zhipuai.api_key = api_key
    response = zhipuai.model_api.invoke(
        model='glm-4.6',
        prompt=[{'role': 'user', 'content': 'Привет! Ответь кратко на русском.'}]
    )
    
    if response['code'] == 200:
        print('✅ GLM API работает корректно')
        print(f'📝 Ответ: {response[\"data\"][\"choices\"][0][\"content\"]}')
    else:
        print(f'❌ Ошибка GLM API: {response}')
        
except Exception as e:
    print(f'❌ Ошибка при тестировании GLM: {e}')
"
}

# Функция помощи
help() {
    echo "🤖 Claude Code + GLM Интеграция"
    echo ""
    echo "Основные команды:"
    echo "  claude              - Запуск Claude Code"
    echo "  glm-test            - Тестировать GLM API подключение"
    echo "  help                - Эта справка"
    echo ""
    echo "Конфигурация GLM:"
    echo "  Файл: ~/.config/glm.json"
    echo "  API ключ: Получите на https://open.bigmodel.cn/"
    echo ""
}

# Запуск Claude Code по умолчанию
if [[ $# -eq 0 ]]; then
    claude
else
    "$@"
fi
EOF

    # Собираем образ
    log_info "🔨 Сборка Claude GLM образа..."
    if docker build -t "claude-glm:latest" "$CONTAINERS_DIR/claude-glm" >> "$LOGS_DIR/claude-glm-build.log" 2>&1; then
        log_success "✅ Образ claude-glm успешно собран"
    else
        log_error "❌ Ошибка сборки образа claude-glm"
        return 1
    fi
    
    # Запускаем контейнер
    log_info "🚀 Запуск Claude GLM контейнера..."
    if docker run -d \
        --name "$container_name" \
        --memory="2g" \
        --cpus="1.0" \
        --restart unless-stopped \
        -v "$workspace_dir:/home/aiuser/workspace" \
        -v "$CONFIG_DIR/glm_config.json:/home/aiuser/.config/glm.json:ro" \
        -v "$PROJECT_ROOT/scripts/claude-glm-wrapper.sh:/home/aiuser/claude-glm.sh:ro" \
        "claude-glm:latest" >> "$LOGS_DIR/claude-glm-run.log" 2>&1; then
        
        log_success "✅ Claude GLM контейнер запущен: $container_name"
        log_info "📁 Рабочая директория: $workspace_dir"
        log_info "🔧 Для подключения: docker exec -it $container_name /bin/bash"
        log_info "⚙️  Настройте GLM API ключ в: $CONFIG_DIR/glm_config.json"
        
        return 0
    else
        log_error "❌ Ошибка запуска Claude GLM контейнера"
        return 1
    fi
}

# Тестирование Claude GLM контейнера
test_claude_glm() {
    log_info "🧪 Тестирование Claude GLM контейнера..."
    
    if ! docker ps --filter "name=claude-glm" --format "{{.Names}}" | grep -q "claude-glm"; then
        log_error "❌ Контейнер claude-glm не запущен"
        return 1
    fi
    
    log_info "🔍 Проверка Claude Code..."
    if docker exec claude-glm claude --version >> "$LOGS_DIR/claude-test.log" 2>&1; then
        log_success "✅ Claude Code работает"
    else
        log_error "❌ Claude Code не работает"
        return 1
    fi
    
    log_info "🔍 Проверка GLM интеграции..."
    if docker exec claude-glm /home/aiuser/claude-glm.sh glm-test >> "$LOGS_DIR/glm-test.log" 2>&1; then
        log_success "✅ GLM интеграция работает"
    else
        log_warning "⚠️ GLM API ключ требует настройки"
    fi
    
    log_success "✅ Тестирование завершено"
}

# Создание инструкций по авторизации
create_auth_instructions() {
    log_info "📋 Создание инструкций по авторизации..."
    
    cat > "$PROJECT_ROOT/AUTH_INSTRUCTIONS.md" << EOF
# Инструкции по авторизации AI контейнеров

## 1. Claude Code (требуется подписка)

### Шаг 1: Подписка Anthropic
1. Перейдите на https://console.anthropic.com/
2. Войдите или создайте аккаунт
3. Оформите подписку на Claude Code

### Шаг 2: Авторизация контейнера
\`\`\`bash
# Запуск контейнера Claude с авторизацией
./ai-manager.sh create-claude-auth
\`\`\`

### Шаг 3: Подключение
\`\`\`bash
# Подключение к авторизованному контейнеру
docker exec -it claude-auth /bin/bash
claude
\`\`\`

## 2. Gemini CLI (требуется API ключ)

### Шаг 1: Получение API ключа
1. Перейдите на https://makersuite.google.com/app/apikey
2. Создайте новый API ключ
3. Сохраните ключ в безопасном месте

### Шаг 2: Настройка
\`\`\`bash
# Создание конфигурации
echo '{"GEMINI_API_KEY": "ваш-api-ключ"}' > config/gemini_config.json

# Запуск контейнера
./ai-manager.sh create-gemini
\`\`\`

## 3. GLM (API авторизация, готово к использованию)

### Шаг 1: Получение API ключа
1. Перейдите на https://open.bigmodel.cn/
2. Зарегистрируйтесь и получите API ключ
3. Отредактируйте \`config/glm_config.json\`

### Шаг 2: Использование
\`\`\`bash
# Контейнер уже готов к использованию
./ai-manager.sh create-claude-glm

# Тестирование
./ai-manager.sh test-claude-glm

# Подключение
docker exec -it claude-glm /bin/bash
claude-glm.sh
\`\`\`

## Порядок рекомендуемой настройки

1. **GLM** - Начните с него (API авторизация)
2. **Gemini** - Требует API ключ настройку  
3. **Claude** - Требует подписку и интерактивную авторизацию

EOF

    log_success "✅ Инструкции по авторизации созданы: $PROJECT_ROOT/AUTH_INSTRUCTIONS.md"
}

# Показать статус контейнеров
show_status() {
    log_info "📊 Статус AI контейнеров:"
    
    printf "%-15s %-15s %-10s %-20s\n" "CONTAINER" "IMAGE" "STATUS" "CREATED"
    printf "%-15s %-15s %-10s %-20s\n" "---------------" "---------------" "----------" "--------------------"
    
    local containers=("claude-glm" "claude-auth" "gemini-auth")
    
    for container in "${containers[@]}"; do
        local info=$(docker ps -a --filter "name=$container" --format "{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.CreatedAt}}" 2>/dev/null || echo "$container\t-\tnot found\t-")
        
        IFS=$'\t' read -r name image status created <<< "$info"
        
        if [[ "$status" == *"Up"* ]]; then
            status="🟢 running"
        elif [[ "$status" == *"Exited"* ]]; then
            status="🔴 stopped"
        else
            status="🟡 $status"
        fi
        
        printf "%-15s %-15s %-10s %-20s\n" "$name" "$image" "$status" "$created"
    done
}

# Очистка всех контейнеров
cleanup_all() {
    log_info "🧹 Очистка всех AI контейнеров..."
    
    local containers=("claude-glm" "claude-auth" "gemini-auth")
    
    for container in "${containers[@]}"; do
        if docker ps -a --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
            docker stop "$container" >> "$LOGS_DIR/cleanup.log" 2>&1 || true
            docker rm "$container" >> "$LOGS_DIR/cleanup.log" 2>&1 || true
            log_info "✅ Контейнер $container удален"
        fi
    done
    
    # Удаление образов
    local images=("claude-glm:latest" "claude-auth:latest" "gemini-auth:latest")
    
    for image in "${images[@]}"; do
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "$image"; then
            docker rmi "$image" >> "$LOGS_DIR/cleanup.log" 2>&1 || true
            log_info "✅ Образ $image удален"
        fi
    done
    
    log_success "✅ Очистка завершена"
}

# Показать справку
show_help() {
    cat << EOF
Новая система управления AI контейнерами v4.0

Использование:
  $0 create-claude-glm    # Создать Claude + GLM (API авторизация)
  $0 test-claude-glm      # Протестировать Claude + GLM
  $0 create-auth-instructions # Создать инструкции по авторизации
  $0 status               # Показать статус контейнеров
  $0 cleanup              # Очистить все контейнеры
  $0 --help               # Показать эту справку

Порядок настройки:
  1. $0 create-claude-glm     # GLM - готов к использованию
  2. Настроить API ключ в config/glm_config.json
  3. $0 test-claude-glm       # Проверить работу
  4. Создавать другие контейнеры по необходимости

EOF
}

# Основной обработчик команд
case "${1:-}" in
    "create-claude-glm")
        check_dependencies
        create_claude_glm_container
        ;;
    "test-claude-glm")
        check_dependencies
        test_claude_glm
        ;;
    "create-auth-instructions")
        create_auth_instructions
        ;;
    "status")
        show_status
        ;;
    "cleanup")
        cleanup_all
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