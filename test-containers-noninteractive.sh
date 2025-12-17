#!/bin/bash

# Неинтерактивная система тестирования AI контейнеров
# Работает без блокировки терминала пользователя

set -euo pipefail

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_LOG_DIR="$PROJECT_ROOT/test-logs"
SESSION_ID=$(date +%s)

# Создаем директорию для логов
mkdir -p "$TEST_LOG_DIR"

# Логирование
log_info() {
    echo "[INFO $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$TEST_LOG_DIR/test-$SESSION_ID.log"
}

log_error() {
    echo "[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$TEST_LOG_DIR/test-$SESSION_ID.log"
}

# Проверка доступности Docker
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker недоступен"
        return 1
    fi
    log_info "Docker доступен"
}

# Тестирование Claude контейнера в фоновом режиме
test_claude_container() {
    log_info "=== Тестирование Claude контейнера ==="
    
    local container_name="claude-test-$SESSION_ID"
    local config_dir="$PROJECT_ROOT/test-configs/claude"
    
    # Создаем тестовую конфигурацию
    mkdir -p "$config_dir"
    
    # Проверяем наличие OAuth данных
    if [[ -f "$HOME/.docker-ai-config/claude_config.json" ]]; then
        log_info "Найдены Claude OAuth данные"
        cp "$HOME/.docker-ai-config/claude_config.json" "$config_dir/"
    else
        log_error "Claude OAuth данные не найдены"
        return 1
    fi
    
    # Создаем Dockerfile для теста
    cat > "$config_dir/Dockerfile" << 'EOF'
FROM mcr.microsoft.com/devcontainers/javascript-node:20

# Установка Claude Code
RUN npm install -g @anthropic-ai/claude-3-dev

# Создание пользователя
RUN useradd -m -s /bin/bash aiuser && \
    mkdir -p /home/aiuser/.config && \
    chown -R aiuser:aiuser /home/aiuser

USER aiuser
WORKDIR /home/aiuser

# Копирование конфигурации
COPY --chown=aiuser:aiuser claude_config.json /home/aiuser/.config/claude.json

# Тестовая команда
CMD ["echo", "Claude container ready for testing"]
EOF

    # Собираем тестовый образ
    log_info "Сборка тестового образа Claude..."
    if docker build -t "claude-test:$SESSION_ID" "$config_dir" >> "$TEST_LOG_DIR/claude-build-$SESSION_ID.log" 2>&1; then
        log_info "✅ Образ Claude успешно собран"
    else
        log_error "❌ Ошибка сборки образа Claude"
        return 1
    fi
    
    # Запускаем контейнер в фоновом режиме
    log_info "Запуск Claude контейнера в фоновом режиме..."
    if docker run -d \
        --name "$container_name" \
        --memory="2g" \
        --cpus="1.0" \
        --restart unless-stopped \
        "claude-test:$SESSION_ID" >> "$TEST_LOG_DIR/claude-run-$SESSION_ID.log" 2>&1; then
        
        log_info "✅ Claude контейнер запущен: $container_name"
        
        # Проверяем статус контейнера
        sleep 3
        if docker ps --filter "name=$container_name" --format "table {{.Names}}\t{{.Status}}" | grep -q "$container_name"; then
            log_info "✅ Claude контейнер работает корректно"
            
            # Показываем информацию о контейнере
            docker inspect "$container_name" --format='{{.State.Status}}: {{.State.StartedAt}}' >> "$TEST_LOG_DIR/claude-status-$SESSION_ID.log"
            
            # Останавливаем тестовый контейнер
            docker stop "$container_name" >> "$TEST_LOG_DIR/claude-stop-$SESSION_ID.log" 2>&1
            docker rm "$container_name" >> "$TEST_LOG_DIR/claude-rm-$SESSION_ID.log" 2>&1
            
            return 0
        else
            log_error "❌ Claude контейнер не запустился корректно"
            docker logs "$container_name" >> "$TEST_LOG_DIR/claude-error-$SESSION_ID.log" 2>&1
            docker rm "$container_name" >> "$TEST_LOG_DIR/claude-cleanup-$SESSION_ID.log" 2>&1
            return 1
        fi
    else
        log_error "❌ Ошибка запуска Claude контейнера"
        return 1
    fi
}

# Тестирование Gemini контейнера в фоновом режиме
test_gemini_container() {
    log_info "=== Тестирование Gemini контейнера ==="
    
    local container_name="gemini-test-$SESSION_ID"
    local config_dir="$PROJECT_ROOT/test-configs/gemini"
    
    # Создаем тестовую конфигурацию
    mkdir -p "$config_dir"
    
    # Проверяем наличие API ключа
    if [[ -f "$HOME/.docker-ai-config/gemini_config.json" ]]; then
        log_info "Найдены Gemini конфигурационные данные"
        cp "$HOME/.docker-ai-config/gemini_config.json" "$config_dir/"
    else
        log_info "Создаем тестовую конфигурацию Gemini"
        echo '{"GEMINI_API_KEY": "test-key-for-validation"}' > "$config_dir/gemini_config.json"
    fi
    
    # Создаем Dockerfile для теста
    cat > "$config_dir/Dockerfile" << 'EOF'
FROM python:3.11-slim

# Установка зависимостей
RUN pip install --no-cache-dir google-generativeai

# Создание пользователя
RUN useradd -m -s /bin/bash aiuser

USER aiuser
WORKDIR /home/aiuser

# Тестовая команда
CMD ["python3", "-c", "import google.generativeai as genai; print('Gemini SDK ready')"]
EOF

    # Собираем тестовый образ
    log_info "Сборка тестового образа Gemini..."
    if docker build -t "gemini-test:$SESSION_ID" "$config_dir" >> "$TEST_LOG_DIR/gemini-build-$SESSION_ID.log" 2>&1; then
        log_info "✅ Образ Gemini успешно собран"
    else
        log_error "❌ Ошибка сборки образа Gemini"
        return 1
    fi
    
    # Запускаем контейнер в фоновом режиме
    log_info "Запуск Gemini контейнера в фоновом режиме..."
    if docker run -d \
        --name "$container_name" \
        --memory="1g" \
        --cpus="0.5" \
        --restart unless-stopped \
        "gemini-test:$SESSION_ID" >> "$TEST_LOG_DIR/gemini-run-$SESSION_ID.log" 2>&1; then
        
        log_info "✅ Gemini контейнер запущен: $container_name"
        
        # Проверяем статус контейнера
        sleep 3
        if docker ps --filter "name=$container_name" --format "table {{.Names}}\t{{.Status}}" | grep -q "$container_name"; then
            log_info "✅ Gemini контейнер работает корректно"
            
            # Останавливаем тестовый контейнер
            docker stop "$container_name" >> "$TEST_LOG_DIR/gemini-stop-$SESSION_ID.log" 2>&1
            docker rm "$container_name" >> "$TEST_LOG_DIR/gemini-rm-$SESSION_ID.log" 2>&1
            
            return 0
        else
            log_error "❌ Gemini контейнер не запустился корректно"
            docker logs "$container_name" >> "$TEST_LOG_DIR/gemini-error-$SESSION_ID.log" 2>&1
            docker rm "$container_name" >> "$TEST_LOG_DIR/gemini-cleanup-$SESSION_ID.log" 2>&1
            return 1
        fi
    else
        log_error "❌ Ошибка запуска Gemini контейнера"
        return 1
    fi
}

# Тестирование GLM контейнера в фоновом режиме
test_glm_container() {
    log_info "=== Тестирование GLM контейнера ==="
    
    local container_name="glm-test-$SESSION_ID"
    local config_dir="$PROJECT_ROOT/test-configs/glm"
    
    # Создаем тестовую конфигурацию
    mkdir -p "$config_dir"
    
    # Создаем Dockerfile для теста
    cat > "$config_dir/Dockerfile" << 'EOF'
FROM python:3.11-slim

# Установка зависимостей
RUN pip install --no-cache-dir zhipuai

# Создание пользователя
RUN useradd -m -s /bin/bash aiuser

USER aiuser
WORKDIR /home/aiuser

# Тестовая команда
CMD ["python3", "-c", "import zhipuai; print('GLM SDK ready')"]
EOF

    # Собираем тестовый образ
    log_info "Сборка тестового образа GLM..."
    if docker build -t "glm-test:$SESSION_ID" "$config_dir" >> "$TEST_LOG_DIR/glm-build-$SESSION_ID.log" 2>&1; then
        log_info "✅ Образ GLM успешно собран"
    else
        log_error "❌ Ошибка сборки образа GLM"
        return 1
    fi
    
    # Запускаем контейнер в фоновом режиме
    log_info "Запуск GLM контейнера в фоновом режиме..."
    if docker run -d \
        --name "$container_name" \
        --memory="1g" \
        --cpus="0.5" \
        --restart unless-stopped \
        "glm-test:$SESSION_ID" >> "$TEST_LOG_DIR/glm-run-$SESSION_ID.log" 2>&1; then
        
        log_info "✅ GLM контейнер запущен: $container_name"
        
        # Проверяем статус контейнера
        sleep 3
        if docker ps --filter "name=$container_name" --format "table {{.Names}}\t{{.Status}}" | grep -q "$container_name"; then
            log_info "✅ GLM контейнер работает корректно"
            
            # Останавливаем тестовый контейнер
            docker stop "$container_name" >> "$TEST_LOG_DIR/glm-stop-$SESSION_ID.log" 2>&1
            docker rm "$container_name" >> "$TEST_LOG_DIR/glm-rm-$SESSION_ID.log" 2>&1
            
            return 0
        else
            log_error "❌ GLM контейнер не запустился корректно"
            docker logs "$container_name" >> "$TEST_LOG_DIR/glm-error-$SESSION_ID.log" 2>&1
            docker rm "$container_name" >> "$TEST_LOG_DIR/glm-cleanup-$SESSION_ID.log" 2>&1
            return 1
        fi
    else
        log_error "❌ Ошибка запуска GLM контейнера"
        return 1
    fi
}

# Генерация отчета о тестировании
generate_test_report() {
    local report_file="$TEST_LOG_DIR/test-report-$SESSION_ID.md"
    
    cat > "$report_file" << EOF
# Отчет о тестировании AI контейнеров

**Дата тестирования:** $(date '+%Y-%m-%d %H:%M:%S')  
**ID сессии:** $SESSION_ID  

## Результаты тестирования

$(cat "$TEST_LOG_DIR/test-$SESSION_ID.log" | grep -E "^\[.*\]" | tail -20)

## Логи сборки

- Claude: [claude-build-$SESSION_ID.log](claude-build-$SESSION_ID.log)
- Gemini: [gemini-build-$SESSION_ID.log](gemini-build-$SESSION_ID.log)  
- GLM: [glm-build-$SESSION_ID.log](glm-build-$SESSION_ID.log)

## Логи выполнения

- Claude: [claude-run-$SESSION_ID.log](claude-run-$SESSION_ID.log)
- Gemini: [gemini-run-$SESSION_ID.log](gemini-run-$SESSION_ID.log)
- GLM: [glm-run-$SESSION_ID.log](glm-run-$SESSION_ID.log)

## Статус контейнеров

$(docker ps -a --filter "name=test-$SESSION_ID" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Контейнеры не найдены")

---

**Автоматически сгенерировано системой тестирования**
EOF

    log_info "📊 Отчет о тестировании создан: $report_file"
}

# Основная функция выполнения тестов
run_all_tests() {
    log_info "🚀 Начало неинтерактивного тестирования AI контейнеров"
    log_info "ID сессии: $SESSION_ID"
    
    local test_results=()
    
    # Проверка Docker
    if ! check_docker; then
        log_error "Тестирование прервано: Docker недоступен"
        return 1
    fi
    
    # Тестирование каждого контейнера
    if test_claude_container; then
        test_results+=("Claude: ✅ УСПЕХ")
    else
        test_results+=("Claude: ❌ ОШИБКА")
    fi
    
    if test_gemini_container; then
        test_results+=("Gemini: ✅ УСПЕХ")
    else
        test_results+=("Gemini: ❌ ОШИБКА")
    fi
    
    if test_glm_container; then
        test_results+=("GLM: ✅ УСПЕХ")
    else
        test_results+=("GLM: ❌ ОШИБКА")
    fi
    
    # Генерация отчета
    generate_test_report
    
    # Вывод результатов
    log_info "=== ИТОГИ ТЕСТИРОВАНИЯ ==="
    for result in "${test_results[@]}"; do
        log_info "$result"
    done
    
    log_info "📁 Все логи сохранены в: $TEST_LOG_DIR/"
    log_info "📊 Полный отчет: $TEST_LOG_DIR/test-report-$SESSION_ID.md"
    
    # Очистка тестовых конфигураций
    rm -rf "$PROJECT_ROOT/test-configs"
    
    log_info "✅ Неинтерактивное тестирование завершено"
}

# Показать справку
show_help() {
    cat << EOF
Неинтерактивная система тестирования AI контейнеров

Использование:
  $0                    # Запустить все тесты
  $0 --help            # Показать эту справку
  $0 --logs            # Показать последние логи
  $0 --cleanup         # Очистить тестовые контейнеры и образы

Режим работы:
- Все контейнеры запускаются в фоновом режиме (-d)
- Нет интерактивных сессий и блокировки терминала
- Автоматическая очистка после тестирования
- Подробные логи для каждого этапа

EOF
}

# Показать последние логи
show_logs() {
    local latest_log=$(ls -t "$TEST_LOG_DIR"/test-*.log 2>/dev/null | head -1)
    if [[ -n "$latest_log" ]]; then
        echo "Последние логи тестирования:"
        tail -50 "$latest_log"
    else
        echo "Логи тестирования не найдены"
    fi
}

# Очистка тестовых ресурсов
cleanup_test_resources() {
    log_info "🧹 Очистка тестовых ресурсов..."
    
    # Удаление тестовых контейнеров
    local test_containers=$(docker ps -a --filter "name=test-" --format "{{.Names}}" 2>/dev/null || true)
    if [[ -n "$test_containers" ]]; then
        echo "$test_containers" | xargs -r docker rm -f
        log_info "✅ Тестовые контейнеры удалены"
    fi
    
    # Удаление тестовых образов
    local test_images=$(docker images --filter "reference=*test-*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true)
    if [[ -n "$test_images" ]]; then
        echo "$test_images" | xargs -r docker rmi -f
        log_info "✅ Тестовые образы удалены"
    fi
    
    # Очистка логов (старше 7 дней)
    find "$TEST_LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    log_info "✅ Старые логи очищены"
}

# Обработка аргументов командной строки
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --logs|-l)
        show_logs
        exit 0
        ;;
    --cleanup|-c)
        cleanup_test_resources
        exit 0
        ;;
    "")
        run_all_tests
        exit 0
        ;;
    *)
        echo "Неизвестный аргумент: $1"
        show_help
        exit 1
        ;;
esac