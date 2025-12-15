#!/bin/bash

# ai-image-selector.sh - Expert AI Image Selection Logic
# Выбирает правильный Docker образ в зависимости от AI провайдера

set -euo pipefail

# Image mapping strategy
readonly IMAGE_MAP=(
    "gemini:gemini-cli:latest"
    "claude:claude-code-tools:latest"
    "chatgpt:openai-cli:latest"
)

select_ai_image() {
    local ai_provider="${1:-gemini}"

    case "$ai_provider" in
        "gemini")
            echo "gemini-cli:latest"
            ;;
        "claude")
            echo "claude-code-tools:latest"
            ;;
        *)
            echo "Error: Unknown AI provider: $ai_provider" >&2
            echo "Supported providers: gemini, claude" >&2
            exit 1
            ;;
    esac
}

# Функция для проверки доступности образа
check_image_exists() {
    local image="$1"
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image}$"; then
        return 0
    else
        return 1
    fi
}

# Основная логика выбора образа
main() {
    local ai_provider="${1:-gemini}"
    local selected_image

    selected_image=$(select_ai_image "$ai_provider")

    if ! check_image_exists "$selected_image"; then
        echo "❌ Image $selected_image not found. Please build it first." >&2
        exit 1
    fi

    echo "$selected_image"
}

# Экспорт функций для использования в других скриптах
export -f select_ai_image
export -f check_image_exists

# Если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi