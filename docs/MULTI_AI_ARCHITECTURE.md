# Multi-AI Docker Architecture

## 🏗️ ЭКСПЕРТНАЯ АРХИТЕКТУРА ДЛЯ MULTI-AI DOCKER ОБРАЗОВ

### 🎯 Принципы проектирования

1. **Specialized Images** - Каждый AI имеет свой оптимизированный образ
2. **Smart Selection** - Автоматический выбор правильного образа
3. **Unified Interface** - Единый интерфейс для всех AI
4. **Graceful Fallbacks** - Отказоустойчивость и миграция

### 📦 Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                    ai-assistant.zsh                        │
│                 (Единый интерфейс)                          │
└─────────────────┬───────────────────────────────────────────┘
                  │
    ┌─────────────┼─────────────┐
    │             │             │
    ▼             ▼             ▼
┌─────────┐  ┌─────────┐  ┌──────────────┐
│gemini-cli│  │claude-  │  │future-ai-    │
│:latest  │  │code-    │  │tools:latest  │
│         │  │tools:   │  │              │
│         │  │latest   │  │              │
└─────────┘  └─────────┘  └──────────────┘
    │             │             │
    ▼             ▼             ▼
Gemini API    Claude API   Future APIs
```

### 🔧 Техническая реализация

#### 1. **Image Selector Pattern**

```bash
# Умный выбор образа
select_ai_image() {
    case "$ai_provider" in
        "gemini") echo "gemini-cli:latest" ;;
        "claude") echo "claude-code-tools:latest" ;;
        *) echo "Error: Unknown AI provider" ;;
    esac
}
```

#### 2. **Provider-specific Configuration**

```bash
# Специфичные переменные окружения
setup_provider_env() {
    local provider="$1"
    case "$provider" in
        "gemini")
            echo "-e GOOGLE_CLOUD_PROJECT=gemini-cli-auth-478707"
            ;;
        "claude")
            echo "-e CLAUDE_API_KEY=$CLAUDE_API_KEY"
            ;;
    esac
}
```

#### 3. **Unified Execution Pattern**

```bash
run_ai_container() {
    local provider="$1"
    shift

    local image=$(select_ai_image "$provider")
    local env_vars=$(setup_provider_env "$provider")

    docker run --rm $env_vars "$image" "$provider" "$@"
}
```

### 🚀 Build Strategy

#### Multi-Stage Dockerfile

```dockerfile
# Base stage
FROM node:22-alpine AS base
# ... общие зависимости ...

# Gemini stage
FROM base AS gemini
RUN npm install -g @google/gemini-cli
# ... Gemini специфичные настройки ...

# Claude stage
FROM base AS claude
RUN npm install -g @anthropic-ai/claude-cli
# ... Claude специфичные настройки ...

# Final stage - выбор в runtime
FROM base
COPY --from=gemini /usr/local/lib/node_modules /usr/local/lib/node_modules/gemini
COPY --from=claude /usr/local/lib/node_modules /usr/local/lib/node_modules/claude
# ...
```

### 📋 Deployment Pattern

#### Development

```bash
# Использовать специализированные образы
gemini    # -> gemini-cli:latest
claude    # -> claude-code-tools:latest
```

#### Production

```bash
# Возможно использовать универсальный образ с entrypoint
ai-exec gemini "command"
ai-exec claude "command"
```

### 🔄 Migration Path

1. **Phase 1**: Исправить баг с выбором образа (✅ DONE)
2. **Phase 2**: Реализовать smart image selector
3. **Phase 3**: Оптимизировать Docker образы
4. **Phase 4**: Добавить новые AI провайдеры

### 🎁 Benefits

1. **Performance**: Каждый образ оптимизирован под свой AI
2. **Isolation**: Проблемы с одним AI не влияют на другие
3. **Flexibility**: Легко добавлять новые AI
4. **Simplicity**: Единый интерфейс для всех

### ⚡ Quick Test

```bash
# Test исправленной версии
source ai-assistant.zsh
gemini --version
claude --version

# Должно использовать правильные образы:
docker ps | grep -E "(gemini-cli|claude-code-tools)"
```
