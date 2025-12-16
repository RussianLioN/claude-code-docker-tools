# 🏗️ Архитектурный план: Модульная система AI-ассистентов

> **Проект:** Рефакторинг ai-assistant.zsh в модульную архитектуру
> **Статус:** Детализированный план реализации
> **Версия:** 5.0
> **Приоритет:** P0 - Устранение критических конфликтов авторизации

---

## 📋 Содержание
1. [Анализ текущих проблем](#1-анализ-текущих-проблем)
2. [Требования и спецификации](#2-требования-и-спецификации)
3. [Архитектурные решения](#3-архитектурные-решения)
4. [Детализированный план реализации](#4-детализированный-план-реализации)
5. [Система отслеживания прогресса](#5-система-отслеживания-прогресса)
6. [Контроль качества](#6-контроль-качества)

---

## 1. Анализ текущих проблем

### 🚨 Критические конфликты авторизации
- **Claude Code:** ✅ Работает корректно
- **Gemini:** ❌ Запрашивает авторизацию Claude вместо Google OAuth
- **GLM (Z.AI):** ❌ Запрашивает авторизацию Claude вместо подключения к Z.AI API

### 🔍 Корневая причина
```bash
# Строки 350-390 в ai-assistant.zsh:
# - GLM mode принудительно устанавливает AI_MODE=claude
# - Все режимы используют Claude-специфичные переменные окружения
# - Все режимы монтируются в /root/.claude-config
# - Отсутствует механизм изоляции между режимами
```

---

## 2. Требования и спецификации

### 📋 Функциональные требования
| ID | Требование | Приоритет | Статус |
|----|------------|-----------|--------|
| FR-001 | Изоляция переменных окружения между режимами | P0 | ❌ |
| FR-002 | Независимые точки монтирования для каждого режима | P0 | ❌ |
| FR-003 | Сохранение обратной совместимости | P1 | ✅ |
| FR-004 | Модульная архитектура с общей библиотекой | P1 | ❌ |
| FR-005 | Система логирования и отладки | P2 | ✅ |

### 🔧 Технические спецификации
- **Изоляция окружения:** Каждый режим использует только свои переменные
- **Монтирование:** Раздельные пути `/root/.{gemini,claude,glm}-config`
- **Переменные:** Префиксы `GEMINI_*`, `CLAUDE_*`, `GLM_*` для изоляции
- **Конфигурация:** JSON файлы с валидацией структуры
- **Логирование:** Структурированные логи с уровнями (INFO, WARN, ERROR, DEBUG)

---

## 3. Архитектурные решения

### 🏛️ Целевая архитектура
```
~/.docker-ai-tools/
├── lib/
│   ├── ai-core.sh         # Ядро системы (общие функции)
│   ├── docker-manager.sh  # Управление Docker контейнерами
│   ├── config-validator.sh # Валидация конфигураций
│   └── logger.sh          # Система логирования
├── modules/
│   ├── gemini.sh          # Google Gemini (изолированный)
│   ├── claude.sh          # Anthropic Claude (изолированный)
│   └── glm.sh             # GLM-4.6 Z.AI (изолированный)
├── bin/
│   └── ai-orchestrator    # Центральный диспетчер
├── config/
│   ├── gemini/            # Конфигурация Gemini
│   ├── claude/            # Конфигурация Claude
│   └── glm/               # Конфигурация GLM
└── logs/                  # Логи всех сервисов
```

### 🔗 Принципы изоляции
1. **Переменные окружения:** Префиксы по режимам
2. **Файловая система:** Раздельные директории конфигурации
3. **Сетевые ресурсы:** Изолированные сессии
4. **Логирование:** Раздельные лог-файлы по режимам

---

## 4. Детализированный план реализации

### 📊 Обзор этапов
| Этап | Название | Длительность | Критические задачи | Критерии успеха |
|------|----------|--------------|-------------------|-----------------|
| 1 | Анализ и подготовка | 4-6 часов | Изоляция переменных, создание библиотеки | Все режимы запускаются без конфликтов |
| 2 | Базовая изоляция | 6-8 часов | Раздельные mount points, переменные окружения | Тесты проходят, нет конфликтов |
| 3 | Модульная архитектура | 8-12 часов | Создание модулей, общая библиотека | Модули работают изолированно |
| 4 | Интеграция и тестирование | 4-6 часов | Системное тестирование, CI/CD | Все тесты проходят |
| 5 | Документация и деплой | 2-4 часа | Обновление документации, релиз | Документация полная |

---

### 🔧 Этап 1: Анализ и подготовка (4-6 часов)

#### 🎯 Цель: Устранить критические конфликты авторизации

#### 📋 Подзадачи:

**1.1. Анализ текущих конфликтов (30 мин)**
- Запустить `./test-ai-isolation.sh`
- Документировать точные конфликты
- Создать отчет о проблемах

**1.2. Создание изоляционного враппера (1 час)**
```bash
# Создать ~/.docker-ai-config/isolate-modes.sh
cat > ~/.docker-ai-config/isolate-modes.sh << 'EOF'
#!/bin/bash
# Изоляционный враппер для немедленного исправления

isolate_gemini() {
    unset ANTHROPIC_API_KEY ANTHROPIC_BASE_URL CLAUDE_API_KEY
    export GEMINI_MODE=1 AI_MODE=gemini
    export GEMINI_API_KEY="${GEMINI_API_KEY:-$(cat ~/.docker-ai-config/global_state/secrets/gemini_key 2>/dev/null || echo '')}"
    gemini "$@"
}

isolate_glm() {
    unset ANTHROPIC_API_KEY ANTHROPIC_BASE_URL CLAUDE_API_KEY
    export GLM_MODE=1 AI_MODE=glm
    export ZAI_API_KEY="${ZAI_API_KEY:-$(cat ~/.docker-ai-config/global_state/secrets/zai_key 2>/dev/null || echo '')}"
    glm "$@"
}

isolate_claude() {
    export CLAUDE_MODE=1 AI_MODE=claude
    claude "$@"
}
EOF
chmod +x ~/.docker-ai-config/isolate-modes.sh
```

**1.3. Быстрое исправление в ai-assistant.zsh (2 часа)**
```bash
# Заменить строки 350-390 на изолированную версию
if [[ "$command" == "glm" ]]; then
    # Удалить загрязнение Claude
    unset ANTHROPIC_API_KEY ANTHROPIC_BASE_URL CLAUDE_API_KEY
    export AI_MODE=glm GLM_MODE=1
    # Использовать GLM-специфичный mount point
    -v "${GLM_STATE_DIR}":/root/.glm-config
fi

if [[ "$command" == "gemini" ]]; then
    # Удалить загрязнение Claude
    unset ANTHROPIC_API_KEY ANTHROPIC_BASE_URL CLAUDE_API_KEY
    export AI_MODE=gemini GEMINI_MODE=1
    # Использовать Gemini-специфичный mount point
    -v "${GEMINI_STATE_DIR}":/root/.gemini-config
fi
```

**1.4. Тестирование изоляции (1 час)**
```bash
# Тест каждого режима
source ~/.docker-ai-config/isolate-modes.sh
echo "Testing Gemini..." && isolate_gemini --help
echo "Testing GLM..." && isolate_glm --help
echo "Testing Claude..." && isolate_claude --help
```

#### ✅ Критерии завершения:
- [ ] Все три режима запускаются без конфликтов
- [ ] Каждый режим использует свои переменные окружения
- [ ] Отсутствует cross-contamination между режимами
- [ ] `./test-ai-isolation.sh` проходит без ошибок

---

### 🏗️ Этап 2: Базовая изоляция (6-8 часов)

#### 🎯 Цель: Реализовать раздельные mount points и переменные окружения

#### 📋 Подзадачи:

**2.1. Создание структуры директорий (30 мин)**
```bash
mkdir -p ~/.docker-ai-tools/{lib,modules,bin,config/{gemini,claude,glm},logs}
mkdir -p ~/.docker-ai-config/{gemini_state,claude_state,glm_state}
```

**2.2. Реализация конфигурационной системы (2 часа)**
```bash
# Создать ~/.docker-ai-tools/lib/config-manager.sh
cat > ~/.docker-ai-tools/lib/config-manager.sh << 'EOF'
#!/bin/bash
# Конфигурационный менеджер с изоляцией

get_mode_config() {
    local mode="$1"
    local key="$2"
    local config_file="$HOME/.docker-ai-config/${mode}_state/config.json"
    
    if [[ -f "$config_file" ]]; then
        jq -r ".${key} // empty" "$config_file" 2>/dev/null
    fi
}

set_mode_config() {
    local mode="$1"
    local key="$2"
    local value="$3"
    local config_file="$HOME/.docker-ai-config/${mode}_state/config.json"
    
    mkdir -p "$(dirname "$config_file")"
    
    if [[ -f "$config_file" ]]; then
        jq ".${key} = \"$value\"" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
    else
        echo "{\"${key}\": \"$value\"}" > "$config_file"
    fi
}

validate_mode_config() {
    local mode="$1"
    local config_file="$HOME/.docker-ai-config/${mode}_state/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        echo "{\"error\": \"Config file not found\"}"
        return 1
    fi
    
    if ! jq empty "$config_file" 2>/dev/null; then
        echo "{\"error\": \"Invalid JSON\"}"
        return 1
    fi
    
    return 0
}
EOF
chmod +x ~/.docker-ai-tools/lib/config-manager.sh
```

**2.3. Система логирования (1 час)**
```bash
# Создать ~/.docker-ai-tools/lib/logger.sh
cat > ~/.docker-ai-tools/lib/logger.sh << 'EOF'
#!/bin/bash
# Система логирования с уровнями

LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_DIR="${LOG_DIR:-$HOME/.docker-ai-tools/logs}"

log_debug() { [[ "$LOG_LEVEL" == "DEBUG" ]] && log_message "DEBUG" "$@"; }
log_info() { log_message "INFO" "$@"; }
log_warn() { log_message "WARN" "$@"; }
log_error() { log_message "ERROR" "$@"; }

log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="$LOG_DIR/ai-$(date +%Y%m%d).log"
    
    mkdir -p "$LOG_DIR"
    echo "[$timestamp] [$level] $message" | tee -a "$log_file"
}
EOF
chmod +x ~/.docker-ai-tools/lib/logger.sh
```

**2.4. Docker менеджер с изоляцией (2 часа)**
```bash
# Создать ~/.docker-ai-tools/lib/docker-manager.sh
cat > ~/.docker-ai-tools/lib/docker-manager.sh << 'EOF'
#!/bin/bash
# Docker менеджер с режимной изоляцией

source "$(dirname "$0")/logger.sh"

run_ai_container() {
    local mode="$1"
    local image="$2"
    local command="$3"
    local extra_args="$4"
    
    local container_name="${mode}-session-$(date +%s)"
    local state_dir="$HOME/.docker-ai-config/${mode}_state"
    local mount_point="/root/.${mode}-config"
    
    log_info "Запуск контейнера для режима: $mode"
    log_debug "Контейнер: $container_name"
    log_debug "Образ: $image"
    log_debug "Команда: $command"
    log_debug "Mount point: $mount_point"
    
    # Установить режим-специфичные переменные
    local -a env_vars=()
    env_vars+=("-e" "AI_MODE=$mode")
    env_vars+=("-e" "${mode^^}_MODE=1")
    
    # Добавить режим-специфичные API ключи
    case "$mode" in
        gemini)
            local gemini_key=$(cat "$HOME/.docker-ai-config/global_state/secrets/gemini_key" 2>/dev/null || echo '')
            [[ -n "$gemini_key" ]] && env_vars+=("-e" "GEMINI_API_KEY=$gemini_key")
            ;;
        glm)
            local zai_key=$(cat "$HOME/.docker-ai-config/global_state/secrets/zai_key" 2>/dev/null || echo '')
            [[ -n "$zai_key" ]] && env_vars+=("-e" "ZAI_API_KEY=$zai_key")
            env_vars+=("-e" "ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic")
            ;;
        claude)
            local claude_key=$(cat "$HOME/.docker-ai-config/global_state/secrets/claude_key" 2>/dev/null || echo '')
            [[ -n "$claude_key" ]] && env_vars+=("-e" "CLAUDE_API_KEY=$claude_key")
            ;;
    esac
    
    # Запустить контейнер с изоляцией
    docker run --rm \
        --name "$container_name" \
        --hostname "${mode}-dev-env" \
        --network host \
        "${env_vars[@]}" \
        -v "$state_dir":"$mount_point" \
        -w "/workspace" \
        $extra_args \
        "$image" $command
}

validate_docker_environment() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker не установлен"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon не запущен"
        return 1
    fi
    
    return 0
}
EOF
chmod +x ~/.docker-ai-tools/lib/docker-manager.sh
```

**2.5. Тестирование изоляции (30 мин)**
```bash
# Тест каждого режима с новой системой
source ~/.docker-ai-tools/lib/logger.sh
source ~/.docker-ai-tools/lib/config-manager.sh
source ~/.docker-ai-tools/lib/docker-manager.sh

# Тест Gemini
log_info "Тестирование Gemini изоляции..."
run_ai_container "gemini" "claude-code-tools" "echo 'Gemini mode test'" ""

# Тест GLM
log_info "Тестирование GLM изоляции..."
run_ai_container "glm" "claude-code-tools" "echo 'GLM mode test'" ""

# Тест Claude
log_info "Тестирование Claude изоляции..."
run_ai_container "claude" "claude-code-tools" "echo 'Claude mode test'" ""
```

#### ✅ Критерии завершения:
- [ ] Каждый режим имеет свой mount point
- [ ] Переменные окружения изолированы по режимам
- [ ] Конфигурационные файлы валидируются
- [ ] Логирование работает для каждого режима

---

### 🔧 Этап 3: Модульная архитектура (8-12 часов)

#### 🎯 Цель: Создать независимые модули для каждого AI-сервиса

#### 📋 Подзадачи:

**3.1. Создание модуля Gemini (3 часа)**
```bash
# Создать ~/.docker-ai-tools/modules/gemini.sh
cat > ~/.docker-ai-tools/modules/gemini.sh << 'EOF'
#!/bin/bash
# Google Gemini AI Module
# Version: 2.0.0

set -euo pipefail

# Load libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logger.sh"
source "$SCRIPT_DIR/../lib/docker-manager.sh"
source "$SCRIPT_DIR/../lib/config-manager.sh"

# Module configuration
MODULE_NAME="gemini"
MODULE_VERSION="2.0.0"
DOCKER_IMAGE="claude-code-tools"  # Используем тот же образ
DEFAULT_MODEL="gemini-pro"

# Main functions
ai_gemini_start() {
    local args="$*"
    log_info "Запуск Google Gemini"
    log_debug "Аргументы: $args"
    
    # Валидация окружения
    if ! validate_docker_environment; then
        log_error "Docker окружение не валидно"
        return 1
    fi
    
    # Запуск контейнера
    run_ai_container "$MODULE_NAME" "$DOCKER_IMAGE" "gemini $args" ""
}

ai_gemini_stop() {
    log_info "Остановка Google Gemini"
    # Остановка всех контейнеров Gemini
    docker ps --format "{{.Names}}" | grep "^gemini-session-" | xargs -r docker stop
}

ai_gemini_status() {
    log_info "Статус Google Gemini"
    local running_containers=$(docker ps --format "{{.Names}}" | grep "^gemini-session-" | wc -l)
    
    if [[ $running_containers -gt 0 ]]; then
        log_info "Активных контейнеров: $running_containers"
        docker ps --format "table {{.Names}}\t{{.Status}}" | grep "gemini-session"
    else
        log_info "Нет активных контейнеров Gemini"
    fi
}

# CLI interface
main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        start|s) ai_gemini_start "$@" ;;
        stop|x) ai_gemini_stop "$@" ;;
        status|st) ai_gemini_status "$@" ;;
        help|h) echo "Usage: $0 {start|stop|status} [args...]" ;;
        *) log_error "Неизвестная команда: $command"; exit 1 ;;
    esac
}

main "$@"
EOF
chmod +x ~/.docker-ai-tools/modules/gemini.sh
```

**3.2. Создание модуля GLM (3 часа)**
```bash
# Создать ~/.docker-ai-tools/modules/glm.sh
cat > ~/.docker-ai-tools/modules/glm.sh << 'EOF'
#!/bin/bash
# GLM-4.6 (Z.AI) AI Module
# Version: 2.0.0

set -euo pipefail

# Load libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logger.sh"
source "$SCRIPT_DIR/../lib/docker-manager.sh"
source "$SCRIPT_DIR/../lib/config-manager.sh"

# Module configuration
MODULE_NAME="glm"
MODULE_VERSION="2.0.0"
DOCKER_IMAGE="claude-code-tools"
DEFAULT_MODEL="glm-4.6"
ZAI_BASE_URL="https://api.z.ai/api/anthropic"

# Main functions
ai_glm_start() {
    local args="$*"
    log_info "Запуск GLM-4.6 (Z.AI)"
    log_debug "Аргументы: $args"
    
    # Валидация окружения
    if ! validate_docker_environment; then
        log_error "Docker окружение не валидно"
        return 1
    fi
    
    # Проверка ZAI API ключа
    local zai_key=$(get_mode_config "glm" "api_key")
    if [[ -z "$zai_key" ]]; then
        zai_key="${ZAI_API_KEY:-}"
        if [[ -z "$zai_key" && -f "$HOME/.docker-ai-config/global_state/secrets/zai_key" ]]; then
            zai_key=$(cat "$HOME/.docker-ai-config/global_state/secrets/zai_key")
        fi
    fi
    
    if [[ -z "$zai_key" ]]; then
        log_error "ZAI API ключ не найден"
        log_info "Установите ZAI_API_KEY или сохраните ключ в ~/.docker-ai-config/global_state/secrets/zai_key"
        return 1
    fi
    
    # Создать конфигурацию GLM
    local glm_config_file="$HOME/.docker-ai-config/glm_state/settings.json"
    mkdir -p "$(dirname "$glm_config_file")"
    
    cat > "$glm_config_file" << JSON
{
  "ANTHROPIC_AUTH_TOKEN": "$zai_key",
  "ANTHROPIC_BASE_URL": "$ZAI_BASE_URL",
  "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
  "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.6",
  "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.6",
  "ANTHROPIC_MODEL": "glm-4.6",
  "alwaysThinkingEnabled": true,
  "includeCoAuthoredBy": false,
  "permissions": {
    "ask": [],
    "defaultMode": "default",
    "deny": []
  }
}
JSON
    
    log_debug "Создана конфигурация GLM в: $glm_config_file"
    
    # Запуск контейнера с Z.AI настройками
    local extra_args="-v $HOME/.docker-ai-config/glm_state:/root/.claude-config"
    run_ai_container "$MODULE_NAME" "$DOCKER_IMAGE" "claude $args" "$extra_args"
}

ai_glm_stop() {
    log_info "Остановка GLM-4.6 (Z.AI)"
    # Остановка всех контейнеров GLM
    docker ps --format "{{.Names}}" | grep "^glm-session-" | xargs -r docker stop
}

ai_glm_status() {
    log_info "Статус GLM-4.6 (Z.AI)"
    local running_containers=$(docker ps --format "{{.Names}}" | grep "^glm-session-" | wc -l)
    
    if [[ $running_containers -gt 0 ]]; then
        log_info "Активных контейнеров: $running_containers"
        docker ps --format "table {{.Names}}\t{{.Status}}" | grep "glm-session"
    else
        log_info "Нет активных контейнеров GLM"
    fi
}

# CLI interface
main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        start|s) ai_glm_start "$@" ;;
        stop|x) ai_glm_stop "$@" ;;
        status|st) ai_glm_status "$@" ;;
        help|h) echo "Usage: $0 {start|stop|status} [args...]" ;;
        *) log_error "Неизвестная команда: $command"; exit 1 ;;
    esac
}

main "$@"
EOF
chmod +x ~/.docker-ai-tools/modules/glm.sh
```

**3.3. Создание модуля Claude (2 часа)**
```bash
# Создать ~/.docker-ai-tools/modules/claude.sh
cat > ~/.docker-ai-tools/modules/claude.sh << 'EOF'
#!/bin/bash
# Anthropic Claude Code AI Module
# Version: 2.0.0

set -euo pipefail

# Load libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logger.sh"
source "$SCRIPT_DIR/../lib/docker-manager.sh"
source "$SCRIPT_DIR/../lib/config-manager.sh"

# Module configuration
MODULE_NAME="claude"
MODULE_VERSION="2.0.0"
DOCKER_IMAGE="claude-code-tools"
DEFAULT_MODEL="claude-3-sonnet-20240229"

# Main functions
ai_claude_start() {
    local args="$*"
    log_info "Запуск Anthropic Claude Code"
    log_debug "Аргументы: $args"
    
    # Валидация окружения
    if ! validate_docker_environment; then
        log_error "Docker окружение не валидно"
        return 1
    fi
    
    # Запуск контейнера
    run_ai_container "$MODULE_NAME" "$DOCKER_IMAGE" "claude $args" ""
}

ai_claude_stop() {
    log_info "Остановка Anthropic Claude Code"
    # Остановка всех контейнеров Claude
    docker ps --format "{{.Names}}" | grep "^claude-session-" | xargs -r docker stop
}

ai_claude_status() {
    log_info "Статус Anthropic Claude Code"
    local running_containers=$(docker ps --format "{{.Names}}" | grep "^claude-session-" | wc -l)
    
    if [[ $running_containers -gt 0 ]]; then
        log_info "Активных контейнеров: $running_containers"
        docker ps --format "table {{.Names}}\t{{.Status}}" | grep "claude-session"
    else
        log_info "Нет активных контейнеров Claude"
    fi
}

# CLI interface
main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        start|s) ai_claude_start "$@" ;;
        stop|x) ai_claude_stop "$@" ;;
        status|st) ai_claude_status "$@" ;;
        help|h) echo "Usage: $0 {start|stop|status} [args...]" ;;
        *) log_error "Неизвестная команда: $command"; exit 1 ;;
    esac
}

main "$@"
EOF
chmod +x ~/.docker-ai-tools/modules/claude.sh
```

**3.4. Тестирование модулей (2 часа)**
```bash
# Тест каждого модуля
source ~/.docker-ai-tools/lib/logger.sh

log_info "Тестирование модулей..."

# Тест Claude модуля
echo "=== Claude Module Test ==="
~/.docker-ai-tools/modules/claude.sh status

# Тест Gemini модуля  
echo "=== Gemini Module Test ==="
~/.docker-ai-tools/modules/gemini.sh status

# Тест GLM модуля
echo "=== GLM Module Test ==="
~/.docker-ai-tools/modules/glm.sh status
```

#### ✅ Критерии завершения:
- [ ] Каждый модуль запускается изолированно
- [ ] Модули не конфликтуют между собой
- [ ] Собственные переменные окружения для каждого модуля
- [ ] Собственные точки монтирования для каждого модуля

---

### 🔧 Этап 4: Интеграция и тестирование (4-6 часов)

#### 🎯 Цель: Объединить все компоненты и провести комплексное тестирование

#### 📋 Подзадачи:

**4.1. Создание центрального оркестратора (1 час)**
```bash
# Создать ~/.docker-ai-tools/bin/ai-orchestrator
cat > ~/.docker-ai-tools/bin/ai-orchestrator << 'EOF'
#!/bin/bash
# AI Orchestrator - Центральный диспетчер
# Version: 2.0.0

set -euo pipefail

# Configuration
MODULES_DIR="$(dirname "$0")/../modules"
LIB_DIR="$(dirname "$0")/../lib"

# Load core libraries
source "$LIB_DIR/logger.sh"
source "$LIB_DIR/config-manager.sh"

# Show usage
show_usage() {
    cat << EOF
AI Orchestrator v2.0.0

Использование: ai-orchestrator <режим> <команда> [аргументы...]

Режимы:
  gemini, g    - Google Gemini
  claude, c    - Anthropic Claude Code  
  glm, z       - GLM-4.6 (Z.AI)

Команды:
  start [args] - Запустить AI-сервис
  stop         - Остановить AI-сервис
  status       - Показать статус
  help         - Показать эту справку

Примеры:
  ai-orchestrator gemini start
  ai-orchestrator claude status
  ai-orchestrator glm stop

EOF
}

# Main orchestrator function
orchestrate() {
    local mode="${1:-}"
    local command="${2:-help}"
    shift 2 || true
    
    # Validate mode
    case "$mode" in
        gemini|g) mode="gemini" ;;
        claude|c) mode="claude" ;;
        glm|z) mode="glm" ;;
        "") show_usage; return 0 ;;
        *) log_error "Неизвестный режим: $mode"; show_usage; return 1 ;;
    esac
    
    # Validate command
    case "$command" in
        start|stop|status|help) ;;
        *) log_error "Неизвестная команда: $command"; show_usage; return 1 ;;
    esac
    
    # Execute module
    local module_script="$MODULES_DIR/$mode.sh"
    
    if [[ ! -f "$module_script" ]]; then
        log_error "Модуль не найден: $module_script"
        return 1
    fi
    
    log_info "Запуск модуля: $mode $command"
    exec "$module_script" "$command" "$@"
}

# Main entry point
main() {
    orchestrate "$@"
}

main "$@"
EOF
chmod +x ~/.docker-ai-tools/bin/ai-orchestrator
```

**4.2. Создание симлинков для обратной совместимости (30 мин)**
```bash
# Создать симлинки для старых команд
ln -sf ~/.docker-ai-tools/bin/ai-orchestrator ~/.docker-ai-tools/bin/gemini
ln -sf ~/.docker-ai-tools/bin/ai-orchestrator ~/.docker-ai-tools/bin/claude  
ln -sf ~/.docker-ai-tools/bin/ai-orchestrator ~/.docker-ai-tools/bin/glm

# Добавить в PATH
export PATH="$HOME/.docker-ai-tools/bin:$PATH"
```

**4.3. Создание meta-скрипта для обратной совместимости (1 час)**
```bash
# Создать обновленный ai-assistant.zsh с делегацией
cat > ~/.docker-ai-tools/ai-assistant.zsh << 'EOF'
#!/bin/bash
# AI Assistant - Meta-скрипт для обратной совместимости
# Делегирует выполнение модулям через orchestrator

# Проверить, установлен ли orchestrator
if command -v ai-orchestrator &> /dev/null; then
    # Использовать новую систему
    ai-orchestrator "$@"
else
    # Fallback на старую систему
    echo "⚠️  Новая модульная система не найдена. Используйте старый скрипт."
    echo "Установите: export PATH=\"$HOME/.docker-ai-tools/bin:\$PATH\""
    return 1
fi
EOF
chmod +x ~/.docker-ai-tools/ai-assistant.zsh
```

**4.4. Комплексное тестирование (2 часа)**
```bash
# Создать тестовый сценарий ~/.docker-ai-tools/tests/integration-test.sh
cat > ~/.docker-ai-tools/tests/integration-test.sh << 'EOF'
#!/bin/bash
# Интеграционное тестирование модульной системы

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Test functions
test_mode_isolation() {
    echo -e "${YELLOW}Тест: Изоляция режимов${NC}"
    
    # Test environment isolation
    for mode in gemini claude glm; do
        echo -n "  Проверка изоляции $mode... "
        
        # Check that mode doesn't have other mode's variables
        case "$mode" in
            gemini)
                if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
                    echo -e "${RED}FAIL${NC} - Claude variables found"
                    ((TESTS_FAILED++))
                else
                    echo -e "${GREEN}PASS${NC}"
                    ((TESTS_PASSED++))
                fi
                ;;
            claude)
                # Claude can have its own variables
                echo -e "${GREEN}PASS${NC}"
                ((TESTS_PASSED++))
                ;;
            glm)
                if [[ -n "${ANTHROPIC_API_KEY:-}" && "${ANTHROPIC_BASE_URL:-}" != "https://api.z.ai/api/anthropic" ]]; then
                    echo -e "${RED}FAIL${NC} - Claude base URL found"
                    ((TESTS_FAILED++))
                else
                    echo -e "${GREEN}PASS${NC}"
                    ((TESTS_PASSED++))
                fi
                ;;
        esac
    done
}

test_container_isolation() {
    echo -e "${YELLOW}Тест: Изоляция контейнеров${NC}"
    
    # Test container creation for each mode
    for mode in gemini claude glm; do
        echo -n "  Проверка контейнера $mode... "
        
        # Run container in test mode
        if ~/.docker-ai-tools/modules/$mode.sh status >/dev/null 2>&1; then
            echo -e "${GREEN}PASS${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}FAIL${NC}"
            ((TESTS_FAILED++))
        fi
    done
}

test_orchestrator_functionality() {
    echo -e "${YELLOW}Тест: Функциональность оркестратора${NC}"
    
    # Test orchestrator help
    echo -n "  Проверка справки оркестратора... "
    if ~/.docker-ai-tools/bin/ai-orchestrator help >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Test orchestrator with each mode
    for mode in gemini claude glm; do
        echo -n "  Проверка оркестратора $mode... "
        if ~/.docker-ai-tools/bin/ai-orchestrator "$mode" status >/dev/null 2>&1; then
            echo -e "${GREEN}PASS${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}FAIL${NC}"
            ((TESTS_FAILED++))
        fi
    done
}

test_backward_compatibility() {
    echo -e "${YELLOW}Тест: Обратная совместимость${NC}"
    
    # Test that old commands still work
    echo -n "  Проверка обратной совместимости... "
    
    # Check if old functions exist
    if command -v gemini &> /dev/null && command -v claude &> /dev/null && command -v glm &> /dev/null; then
        echo -e "${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
    fi
}

# Main test execution
main() {
    echo -e "${YELLOW}🚀 Запуск интеграционного тестирования${NC}"
    echo "=================================="
    
    test_mode_isolation
    echo
    test_container_isolation
    echo
    test_orchestrator_functionality
    echo
    test_backward_compatibility
    echo
    
    echo "=================================="
    echo -e "${YELLOW}Результаты тестирования:${NC}"
    echo -e "Пройдено: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Провалено: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 Все тесты пройдены!${NC}"
        exit 0
    else
        echo -e "${RED}❌ Некоторые тесты провалены${NC}"
        exit 1
    fi
}

main "$@"
EOF
chmod +x ~/.docker-ai-tools/tests/integration-test.sh
```

**4.5. Запуск интеграционного тестирования (30 мин)**
```bash
# Запустить интеграционные тесты
~/.docker-ai-tools/tests/integration-test.sh
```

#### ✅ Критерии завершения:
- [ ] Все интеграционные тесты проходят
- [ ] Нет конфликтов между режимами
- [ ] Обратная совместимость работает
- [ | Оркестратор правильно маршрутизирует команды

---

### 🔧 Этап 5: Документация и деплой (2-4 часа)

#### 🎯 Цель: Подготовить полную документацию и выпустить релиз

#### 📋 Подзадачи:

**5.1. Обновление README.md (30 мин)**
```markdown
# Добавить в README.md:
## Новая модульная система (v2.0)

### Установка
```bash
# Добавить в ~/.zshrc или ~/.bashrc:
export PATH="$HOME/.docker-ai-tools/bin:$PATH"
source ~/.docker-ai-config/isolate-modes.sh
```

### Использование
```bash
# Новый способ (рекомендованный)
ai-orchestrator gemini start
ai-orchestrator claude status
ai-orchestrator glm stop

# Старый способ (все еще работает)
gemini start
claude status
glm stop
```

### Архитектура
- **Модули:** Независимые скрипты для каждого AI
- **Изоляция:** Раздельные переменные и mount points
- **Логирование:** Структурированные логи для каждого режима
```

**5.2. Создание CHANGELOG.md (30 мин)**
```markdown
# Changelog

## [2.0.0] - 2025-12-16
### Added
- Модульная архитектура с изолированными компонентами
- Система изоляции переменных окружения
- Раздельные mount points для каждого режима
- Центральный оркестратор ai-orchestrator
- Комплексная система логирования
- Интеграционные тесты

### Fixed
- Конфликты авторизации между режимами
- Проблема с Claude auth в Gemini/GLM режимах
- Изоляция состояния между различными AI-сервисами

### Changed
- Разделение монолитного скрипта на модули
- Улучшена структура конфигурационных файлов
- Обновлена система управления состоянием
```

**5.3. Создание руководства по миграции (1 час)**
```bash
# Создать ~/.docker-ai-tools/MIGRATION_GUIDE.md
cat > ~/.docker-ai-tools/MIGRATION_GUIDE.md << 'EOF'
# Руководство по миграции на v2.0

## Быстрая миграция (рекомендованная)

1. **Добавить в PATH:**
```bash
echo 'export PATH="$HOME/.docker-ai-tools/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

2. **Протестировать:**
```bash
ai-orchestrator gemini status
ai-orchestrator claude status
ai-orchestrator glm status
```

3. **Использовать новые команды:**
```bash
ai-orchestrator gemini start
ai-orchestrator claude start
ai-orchestrator glm start
```

## Подробная миграция

### 1. Сохранение текущих настроек
```bash
cp -r ~/.docker-ai-config ~/.docker-ai-config.backup
```

### 2. Установка новой системы
# Система автоматически создаст необходимые директории
```

**5.4. Финальное тестирование и релиз (1 час)**
```bash
# Финальный тест всех компонентов
echo "=== Финальное тестирование ==="

# Тест установки
export PATH="$HOME/.docker-ai-tools/bin:$PATH"

# Тест всех режимов
for mode in gemini claude glm; do
    echo "Тестирование $mode..."
    ai-orchestrator "$mode" status
done

# Тест обратной совместимости
if command -v gemini &> /dev/null; then
    echo "Тест обратной совместимости..."
    gemini status
fi

echo "✅ Релиз готов!"
```

#### ✅ Критерии завершения:
- [ ] Документация полная и актуальна
- [ ] Все примеры кода работают
- [ ] CHANGELOG.md содержит все изменения
- [ ] Руководство по миграции готово
- [ ] Финальное тестирование прошло успешно

---

## 5. Система отслеживания прогресса

### 📊 Прогресс-бар по этапам
```
Этап 1: [████████░░] 80% - Анализ и подготовка
Этап 2: [░░░░░░░░░░] 0% - Базовая изоляция
Этап 3: [░░░░░░░░░░] 0% - Модульная архитектура
Этап 4: [░░░░░░░░░░] 0% - Интеграция и тестирование
Этап 5: [░░░░░░░░░░] 0% - Документация и деплой
```

### 🎯 Ключевые метрики
- **Время восстановления (MTTR):** С 30 минут до 5 минут
- **Изоляция режимов:** 100% (никаких конфликтов)
- **Покрытие тестами:** ≥ 80% критических функций
- **Совместимость:** 100% (все старые команды работают)

### 📈 Ежедневный отчет
```bash
# Скрипт для генерации отчета о прогрессе
~/.docker-ai-tools/scripts/progress-report.sh
```

---

## 6. Контроль качества

### 🔍 Проверки качества кода
- **ShellCheck:** Проверка синтаксиса и best practices
- **Линтеры:** Соблюдение стиля кода
- **Unit тесты:** Покрытие критических функций
- **Интеграционные тесты:** Проверка взаимодействия компонентов

### 🛡️ Безопасность
- **Изоляция:** Никаких пересечений между режимами
- **Валидация:** Проверка всех входных данных
- **Логирование:** Полная прозрачность операций
- **Резервное копирование:** Возможность отката

### 📊 Метрики качества
- **Надежность:** 99.9% uptime
- **Производительность:** ≤ 150% от текущего времени
- **Удобство использования:** Интуитивный интерфейс
- **Поддерживаемость:** Чистый, документированный код

---

## 📞 Поддержка и обратная связь

### 🆘 Экстренная поддержка
- **Issue #1:** Конфликты авторизации - использовать изоляционный враппер
- **Issue #2:** Сбои в работе - проверить логи в `~/.docker-ai-tools/logs/`
- **Issue #3:** Проблемы с Docker - запустить `docker system prune`

### 📧 Контакты
- **GitHub Issues:** [Создать issue](https://github.com/RussianLioN/claude-code-docker-tools/issues)
- **Документация:** [Wiki](https://github.com/RussianLioN/claude-code-docker-tools/wiki)
- **Чат:** [Discussions](https://github.com/RussianLioN/claude-code-docker-tools/discussions)

---

*Последнее обновление: 2025-12-16*  
*Следующее обновление: По мере выполнения этапов*  
*Ответственный: AI Assistant (Trae IDE)*