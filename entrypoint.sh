#!/bin/bash

# Claude Code + Gemini Dual Mode Entrypoint
# Автоматическое определение режима работы на основе переменных окружения

set -e

# Определяем основной AI ассистент
if [[ "$AI_MODE" == "claude" ]]; then
    echo "🤖 Claude Code Mode Activated"
    export AI_PROVIDER="claude"
    export AI_MODEL=${CLAUDE_MODEL:-"claude-3-5-sonnet-20241022"}

    # Запускаем Claude Code
    if command -v claude &> /dev/null; then
        exec claude "$@"
    else
        echo "⚠️  Claude CLI not found. Falling back to manual mode..."
        exec /bin/bash "$@"
    fi
else
    echo "🧠 Gemini Mode (Default)"
    export AI_PROVIDER="gemini"
    export AI_MODEL=${GEMINI_MODEL:-"gemini-2.5-pro"}

    # Запускаем Gemini CLI
    exec gemini "$@"
fi
