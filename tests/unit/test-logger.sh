#!/bin/bash
# Unit tests for logger module

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

echo "🧪 Запуск unit тестов для логгера"
echo "=================================="

# Test 1: Check logger library exists
echo "Тестирование наличия библиотеки логгера..."
if [[ -f "lib/logger.sh" ]]; then
    echo "✅ Библиотека логгера найдена"
    ((TESTS_PASSED++))
else
    echo "❌ Библиотека логгера не найдена"
    ((TESTS_FAILED++))
fi

# Test 2: Check logger is sourceable
echo "Тестирование исходного кода логгера..."
if source lib/logger.sh 2>/dev/null; then
    echo "✅ Логгер может быть загружен"
    ((TESTS_PASSED++))
else
    echo "❌ Логгер не может быть загружен"
    ((TESTS_FAILED++))
fi

# Test 3: Check log functions exist
echo "Тестирование функций логгера..."
if declare -f log_info >/dev/null && declare -f log_error >/dev/null; then
    echo "✅ Функции логгера доступны"
    ((TESTS_PASSED++))
else
    echo "❌ Функции логгера недоступны"
    ((TESTS_FAILED++))
fi

# Test 4: Test logging output
echo "Тестирование вывода логгера..."
TEST_OUTPUT=$(log_info "Test message" 2>&1 || true)
if [[ "$TEST_OUTPUT" == *"[INFO]"* && "$TEST_OUTPUT" == *"Test message"* ]]; then
    echo "✅ Вывод логгера корректен"
    ((TESTS_PASSED++))
else
    echo "❌ Вывод логгера некорректен"
    ((TESTS_FAILED++))
fi

echo "==================================="
echo "Результаты тестирования:"
echo "Пройдено: $TESTS_PASSED"
echo "Провалено: $TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ Все unit тесты пройдены успешно${NC}"
    exit 0
else
    echo -e "${RED}❌ Некоторые unit тесты провалены${NC}"
    exit 1
fi
