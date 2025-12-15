# SESSION_MANAGEMENT_ARCHITECTURE.md

> **🔄 Эфемерная Session Management Architecture**
> *Упрощенная архитектура управления сессиями на основе экспертных паттернов эфемерных контейнеров*

**📍 Navigation**: [← Back to CLAUDE.md](./CLAUDE.md)

## 📑 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Expert Pattern Analysis](#expert-pattern-analysis)
3. [Ephemeral Session Model](#ephemeral-session-model)
4. [Implementation Details](#implementation-details)
5. [Configuration Management](#configuration-management)
6. [Migration Guide](#migration-guide)
7. [Legacy Support](#legacy-support)

---

## Architecture Overview

### 🎯 Paradigm Shift: From Persistent to Ephemeral

**❌ Previous Architecture (Problems)**:
- Персистентные контейнеры с сложным lifecycle
- State tracking, health monitoring, auto-recovery
- Container registry, port allocation complexity
- Resource limits, scaling challenges
- Cleanup problems, orphaned containers

**✅ Expert Architecture (Solutions)**:
- Эфемерные контейнеры с `--rm` pattern
- Запуск и забывание (fire-and-forget)
- Автоматическая очистка ресурсов
- Простой configuration sync pattern
- Никаких проблем с масштабированием

### 🏗️ Expert-Based Architecture

```
┌─────────────────────────────────────────────────────────┐
│                Expert Session Manager                    │
│  ┌───────────────────────────────────────────────────┐  │
│  │           ai-assistant.zsh (Wrapper)              │  │ │
│  │  ┌─────────────┬─────────────┬─────────────────┐ │  │ │
│  │  │   gemini()  │   claude()  │   aic()/cic()    │ │  │ │
│  │  │   --rm      │   --rm      │   --rm           │ │  │ │
│  │  └─────────────┴─────────────┴─────────────────┘ │  │ │
│  │  ┌─────────────────────────────────────────────┐ │  │ │
│  │  │        Configuration Sync Engine            │ │  │ │
│  │  │  ├─ sync_in()   ├─ sync_out()   ├─ sanitize() │ │  │ │
│  │  │  └─────────────┴─────────────┴─────────────┘ │  │ │
│  │  └─────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                           │
                    Docker Runtime (--rm)
                           │
┌─────────────────────────────────────────────────────────┐
│              Ephemeral Container Lifecycle                │
│  ┌───────────────────────────────────────────────────┐  │
│  │           claude-code-tools Container              │  │
│  │  • Запуск → Выполнение → Автоочистка --rm           │  │
│  │  • Никакого state tracking                          │  │
│  │  • Никакого health monitoring                      │  │
│  │  • Простота и надежность                            │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Expert Pattern Analysis

### 🧠 Source of Truth: old-scripts/gemini.zsh

**Экспертные паттерны** из проверенного кода:

#### 1. Эфемерный Запуск Контейнера
```bash
# Экспертный паттерн из gemini.zsh (строка 99)
docker run $DOCKER_FLAGS --rm \
  --network host \
  -e GOOGLE_CLOUD_PROJECT=gemini-cli-auth-478707 \
  -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
  -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
  -v "${SSH_KNOWN_HOSTS}":/root/.ssh/known_hosts \
  -v "${SSH_CONFIG_CLEAN}":/root/.ssh/config \
  -v "${GIT_CONFIG}":/root/.gitconfig \
  -v "${GH_CONFIG_DIR}":/root/.config/gh \
  -w "${CONTAINER_WORKDIR}" \
  -v "${TARGET_DIR}":"${CONTAINER_WORKDIR}" \
  -v "${STATE_DIR}":/root/.gemini \
  gemini-cli "$@"
```

**Ключевые принципы**:
- `--rm`: Автоматическая очистка
- `--network host`: Оптимальная производительность
- Минимальные volume mounts
- SSH agent forwarding (не ключи)

#### 2. Configuration Sync Pattern
```bash
# Экспертный sync-in pattern (строки 73-85)
if [[ -n "$GIT_ROOT" ]]; then
  TARGET_DIR="$GIT_ROOT"
  STATE_DIR="$GIT_ROOT/.gemini-state"
else
  TARGET_DIR="$(pwd)"
  STATE_DIR="$HOME/.docker-gemini-config/global_state"
fi

mkdir -p "$STATE_DIR"
if [[ -f "$GLOBAL_AUTH" ]]; then cp "$GLOBAL_AUTH" "$STATE_DIR/google_accounts.json"; fi

# Экспертный sync-out pattern (строки 113-114)
if [[ -f "$STATE_DIR/google_accounts.json" ]]; then cp "$STATE_DIR/google_accounts.json" "$GLOBAL_AUTH"; fi
```

#### 3. SSH Sanitization Pattern
```bash
# Экспертный подход (строки 89-94)
local SSH_CONFIG_CLEAN="$STATE_DIR/ssh_config_clean"
if [[ -f "$SSH_CONFIG_SRC" ]]; then
  grep -vE "UseKeychain|AddKeysToAgent|IdentityFile|IdentitiesOnly" "$SSH_CONFIG_SRC" > "$SSH_CONFIG_CLEAN"
else
  touch "$SSH_CONFIG_CLEAN"
fi
```

## Ephemeral Session Model

### 🚀 Core Principles

#### 1. Fire-and-Forget Execution
```bash
# Каждый вызов = новый эфемерный контейнер
function gemini() {
  ensure_docker_running
  prepare_configuration
  docker run --rm claude-code-tools gemini "$@"
  cleanup_configuration
}
```

**Преимущества**:
- Никаких проблем с orphaned контейнерами
- Автоматическая очистка ресурсов
- Предсказуемое поведение
- Простота отладки

#### 2. Configuration Isolation
```
Global Config (~/.docker-gemini-config/)     Project Config (.gemini-state/)
├── google_accounts.json                    ├── google_accounts.json
├── settings.json                           ├── settings.json
└── gh_config/                              └── ssh_config_clean
         ↑                                          ↑
         └──────── Sync In/Out Pattern ──────────────┘
```

#### 3. SSH Agent Forwarding
```bash
# Никаких SSH ключей в контейнере!
-e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
-v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
```

## Implementation Details

### 📋 Required Components

#### 1. Core Wrapper Functions
```bash
# ai-assistant.zsh - основной wrapper
function gemini() {
  ensure_docker_running
  ensure_ssh_loaded
  sync_in_configuration
  run_ephemeral_container gemini "$@"
  sync_out_configuration
}

function claude() {
  ensure_docker_running
  ensure_ssh_loaded
  sync_in_configuration
  run_ephemeral_container claude "$@"
  sync_out_configuration
}

function aic() {
  gemini commit "$@"
}

function cic() {
  claude commit "$@"
}
```

#### 2. Configuration Management
```bash
function sync_in_configuration() {
  local GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

  if [[ -n "$GIT_ROOT" ]]; then
    TARGET_DIR="$GIT_ROOT"
    STATE_DIR="$GIT_ROOT/.ai-state"
  else
    TARGET_DIR="$(pwd)"
    STATE_DIR="$HOME/.docker-ai-config/global_state"
  fi

  mkdir -p "$STATE_DIR"
  # Copy global configs to state dir
}

function sync_out_configuration() {
  # Copy back any changes
  # Clean up if needed
}
```

#### 3. Container Execution
```bash
function run_ephemeral_container() {
  local command="$1"
  shift

  local DOCKER_FLAGS="-i"
  if [ -t 1 ] && [ -z "$1" ]; then
    DOCKER_FLAGS="-it"
  fi

  docker run $DOCKER_FLAGS --rm \
    --network host \
    -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
    -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
    -v "${TARGET_DIR}":"${CONTAINER_WORKDIR}" \
    -v "${STATE_DIR}":/root/.ai \
    -w "${CONTAINER_WORKDIR}" \
    claude-code-tools "$command" "$@"
}
```

### 🔄 Directory Structure (Simplified)

```
~/.docker-ai-config/                    # Глобальная конфигурация
├── google_accounts.json                # OAuth токены
├── settings.json                       # Gemini настройки
├── claude_config.json                  # Claude настройки
└── global_state/                       # Для non-git проектов

<project>/.ai-state/                    # Проектное состояние
├── google_accounts.json                # Проектные токены
├── settings.json                       # Проектные настройки
└── ssh_config_clean                    # Очищенный SSH конфиг
```

## Configuration Management

### 🛡️ Security Principles

#### Zero Trust Model
- Секреты никогда не покидают диск хоста
- Использование SSH agent forwarding
- Временные volume mounts только на время сессии
- Автоматическая очистка конфиденциальных данных

#### SSH Configuration Sanitization
```bash
# Удаляются macOS-specific директивы
- UseKeychain
- AddKeysToAgent
- IdentityFile
- IdentitiesOnly
```

### 🔄 Sync Patterns

#### Sync-In (Pre-execution)
```bash
function sync_in() {
  # 1. Определить контекст (git проект или нет)
  # 2. Создать state директорию
  # 3. Скопировать необходимые конфигурации
  # 4. Подготовить SSH конфиг
}
```

#### Sync-Out (Post-execution)
```bash
function sync_out() {
  # 1. Сохранить измененные настройки
  # 2. Обновить глобальные конфигурации
  # 3. Очистить временные файлы
}
```

## Migration Guide

### 🔄 From Persistent to Ephemeral

#### Step 1: Update ai-assistant.zsh
```bash
# Удалить сложные функции управления сессиями
# Заменить простыми wrapper функциями

# Старый код (удалить)
function ai-session-manager() { ... }
function start_instance() { ... }
function stop_instance() { ... }

# Новый код (добавить)
function gemini() { ... }  # Эфемерный запуск
function claude() { ... }  # Эфемерный запуск
```

#### Step 2: Remove Persistent Components
```bash
# Удалить файлы
rm -f scripts/ai-session-manager.sh
rm -rf ~/.ai-sessions/
```

#### Step 3: Adopt Expert Patterns
```bash
# Скопировать проверенные паттерны из old-scripts/gemini.zsh
# Адаптировать для double AI mode (Gemini + Claude)
```

## Legacy Support

### 🔄 Backward Compatibility

#### Optional Session Manager
```bash
# Оставить ai-session-manager.sh для legacy поддержки
# Но переписать для использования эфемерных контейнеров

function start_instance() {
  echo "⚠️  Legacy mode deprecated. Use 'gemini' or 'claude' directly."
  gemini  # Простой эфемерный запуск
}
```

#### Migration Path
1. **Phase 1**: Обновить ai-assistant.zsh с эфемерными функциями
2. **Phase 2**: Обновить документацию и примеры
3. **Phase 3**: Депрекейт ai-session-manager.sh
4. **Phase 4**: Удалить legacy компоненты

---

## 🏷️ Architecture Tags

```
Type: EPHEMERAL_SESSION_ARCHITECTURE
Scope: EXPERT_PATTERN_IMPLEMENTATION
Version: 3.0 (Ephemeral Redesign)
Components: 3 (упрощено с 7)
Patterns: 3 (Ephemeral, Sync-In/Out, Zero Trust)
Security_Level: Zero_Trust
Approach: Expert_Proven
Based_On: old-scripts/gemini.zsh
Migration_Status: In_Progress
Complexity: Minimal (vs Previous: High)
```