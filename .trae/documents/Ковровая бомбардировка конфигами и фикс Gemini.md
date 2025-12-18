# План: Тотальное исправление путей конфигурации

Мы устраняем "угадывание" путей, монтируя конфиги во все возможные локации, которые может использовать Node.js приложение.

## 1. Gemini Fix (Приоритет: High)

1. **Диагностика:** Добавить `ls -l $STATE_DIR/google_accounts.json` перед запуском, чтобы видеть, копируется ли файл.
2. **Исправление:** Убедиться, что `GLOBAL_AUTH` указывает на верный файл (`~/.docker-ai-config/google_accounts.json`) и копируется в `STATE_DIR`.

## 2. GLM Fix (Приоритет: High)

1. **Config Storage:** Используем `~/.docker-ai-config/global_state/glm_storage`.
2. **Config Generation:** Генерируем `config.json` (стандартное имя) с содержимым Z.AI.
3. **Mount Strategy (Double Mount):**
    * Монтируем папку хоста `glm_storage` -> `/root/.claude` (Legacy path)
    * Монтируем ту же папку `glm_storage` -> `/root/.config/claude` (XDG path)
    * Это гарантирует, что где бы CLI ни искал конфиг, он его найдет.

## 3. Verification

1. `gemini`: Должен стартовать без auth URL.
2. `glm`: Должен стартовать без auth URL и использовать Z.AI API.

Это решение покрывает все варианты поведения CLI.
