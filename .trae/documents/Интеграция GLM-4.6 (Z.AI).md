# План: Реализация Параллельного GLM-контейнера

Мы внедряем поддержку модели GLM-4.6 (через Z.AI) как **независимого, параллельно запускаемого контейнера**.

## 1. Архитектура Изоляции
Мы используем паттерн **"Single Image, Multi-Instance"**:
*   **Image:** `claude-code-tools` (общий, так как CLI один).
*   **Container A:** `claude-code-ephemeral` (конфиг Anthropic).
*   **Container B:** `glm-code-ephemeral` (конфиг Z.AI).

Это обеспечивает параллельную работу без дублирования Docker-образов.

## 2. Реализация в `ai-assistant.zsh`
1.  **Функция `glm()`**:
    *   Использует уникальное имя контейнера: `--name glm-code-ephemeral`.
    *   Использует уникальный volume для стейта: `.glm-state` (вместо `.claude-state`), чтобы история чатов не смешивалась.
    *   **Config Injection:** Создает временный `config.json` с `ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"` и `ANTHROPIC_AUTH_TOKEN=$ZAI_API_KEY`.
    *   Монтирует этот конфиг в `/root/.claude/config.json`.

## 3. Управление Секретами
1.  Добавить логику чтения `ZAI_API_KEY` из `~/.docker-ai-config/global_state/secrets/zai_key`.
2.  Обновить скрипты установки для запроса этого ключа.

## 4. Документация и Тесты
1.  Обновить `README.md` (инструкция по Z.AI).
2.  Добавить тест параллельного запуска.

Это решение полностью покрывает требование параллельной работы с разными моделями.