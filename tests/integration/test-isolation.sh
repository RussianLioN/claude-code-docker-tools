#!/bin/bash
# Integration tests for mode isolation

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

echo "🔬 Запуск интеграционных тестов"
echo "================================"

# Test 1: Check orchestrator works
echo "Тестирование оркестратора..."
if ./bin/ai-orchestrator help >/dev/null 2>&1; then
    echo "✅ Оркестратор работает"
    ((TESTS_PASSED++))
else
    echo "❌ Оркестратор не работает"
    ((TESTS_FAILED++))
fi

# Test 2: Check all modes work
for mode in gemini claude glm; do
    echo "Тестирование режима: $mode"
    if ./bin/ai-orchestrator "$mode" status >/dev/null 2>&1; then
        echo "✅ Режим $mode работает"
        ((TESTS_PASSED++))
    else
        echo "❌ Режим $mode не работает"
        ((TESTS_FAILED++))
    fi
done

# Test 3: Check symlinks work
for symlink in gemini claude glm; do
    echo "Тестирование симлинка: $symlink"
    if ./bin/"$symlink" status >/dev/null 2>&1; then
        echo "✅ Симлинк $symlink работает"
        ((TESTS_PASSED++))
    else
        echo "❌ Симлинк $symlink не работает"
        ((TESTS_FAILED++))
    fi
done

# Test 4: Check error handling
echo "Тестирование обработки ошибок..."
if ./bin/ai-orchestrator invalid-mode status 2>/dev/null; then
    echo "❌ Обработка ошибок не работает"
    ((TESTS_FAILED++))
else
    echo "✅ Обработка ошибок работает"
    ((TESTS_PASSED++))
fi

echo "================================"
echo "Результаты тестирования:"
echo "Пройдено: $TESTS_PASSED"
echo "Провалено: $TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}🎉 Все интеграционные тесты пройдены!${NC}"
    exit 0
else
    echo -e "${RED}❌ Некоторые тесты провалены${NC}"
    exit 1
fi
