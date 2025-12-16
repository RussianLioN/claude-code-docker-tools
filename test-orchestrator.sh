#!/bin/bash
# Простая проверка создания оркестратора

set -euo pipefail

echo "🧪 Тестирование создания оркестратора..."

# Создаем тестовую директорию
TEST_DIR="./test-orchestrator"
mkdir -p "$TEST_DIR/bin"

# Создаем оркестратор
cat > "$TEST_DIR/bin/ai-orchestrator" << 'EOF'
#!/bin/bash
# AI Orchestrator - Central dispatcher for AI modules
# Version: 2.0.0

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/../modules"
LIB_DIR="$SCRIPT_DIR/../lib"

# Load libraries
# source "$LIB_DIR/logger.sh"

# Show usage
show_usage() {
    cat << USAGE_EOF
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

USAGE_EOF
}

# Main orchestrator function
orchestrate() {
    local mode="${1:-}"
    local command="${2:-help}"
    shift 2 || true
    
    # Handle help case
    if [[ "$mode" == "help" || "$mode" == "--help" || "$mode" == "-h" ]]; then
        show_usage
        return 0
    fi
    
    # Validate mode
    case "$mode" in
        gemini|g) mode="gemini" ;;
        claude|c) mode="claude" ;;
        glm|z) mode="glm" ;;
        "") show_usage; return 0 ;;
        *) echo "Ошибка: Неизвестный режим: $mode" >&2; show_usage; return 1 ;;
    esac
    
    echo "Модуль: $mode, команда: $command"
    return 0
}

# Main entry point
main() {
    orchestrate "$@"
}

main "$@"
EOF

chmod +x "$TEST_DIR/bin/ai-orchestrator"

echo "✅ Оркестратор создан"
echo "🧪 Тестирование..."

# Тестируем
"$TEST_DIR/bin/ai-orchestrator" help
echo ""
"$TEST_DIR/bin/ai-orchestrator" gemini status
echo ""
"$TEST_DIR/bin/ai-orchestrator" invalid-mode

echo "✅ Тест завершен"

# Очистка
rm -rf "$TEST_DIR"