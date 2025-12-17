#!/bin/bash

# Тест интерактивного ввода пользователя

echo "=== ТЕСТ ИНТЕРАКТИВНОГО ВВОДА ==="
echo ""

# Функция ожидания ввода
wait_for_user_input() {
    local prompt="$1"
    local var_name="$2"
    local default_value="${3:-}"
    
    echo "🔸 $prompt"
    if [[ -n "$default_value" ]]; then
        echo "🔸 По умолчанию: $default_value"
    fi
    echo "🔸 Введите ответ и нажмите Enter:"
    echo -n "> "
    
    read user_input
    
    if [[ -z "$user_input" && -n "$default_value" ]]; then
        user_input="$default_value"
    fi
    
    printf -v "$var_name" '%s' "$user_input"
    echo "✅ Введено: $user_input"
    echo ""
}

# Функция ожидания подтверждения
wait_for_confirmation() {
    local prompt="$1"
    local default="${2:-N}"
    
    echo "❓ $prompt"
    echo "🔸 Введите 'y' или 'Y' для подтверждения (по умолчанию: $default):"
    echo -n "> "
    
    read confirmation
    
    if [[ -z "$confirmation" ]]; then
        confirmation="$default"
    fi
    
    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        echo "✅ Подтверждено"
        echo ""
        return 0
    else
        echo "❌ Отменено"
        echo ""
        return 1
    fi
}

# Тест 1: Простой ввод
echo "ТЕСТ 1: Простой ввод текста"
wait_for_user_input "Введите ваше имя" user_name "Аноним"

echo "Привет, $user_name!"
echo ""

# Тест 2: Ввод числа
echo "ТЕСТ 2: Ввод числа"
wait_for_user_input "Введите ваш возраст" user_age "25"

echo "Вам $user_age лет"
echo ""

# Тест 3: Подтверждение
echo "ТЕСТ 3: Подтверждение действия"
if wait_for_confirmation "Продолжить тестирование?" "Y"; then
    echo "Отлично! Продолжаем..."
else
    echo "Жаль, но тестирование прервано"
    exit 0
fi

# Тест 4: Выбор из вариантов
echo "ТЕСТ 4: Выбор из вариантов"
echo "Доступные варианты:"
echo "  1. Claude"
echo "  2. Gemini" 
echo "  3. GLM"
echo ""

wait_for_user_input "Выберите AI ассистента (1-3)" ai_choice "1"

case "$ai_choice" in
    "1")
        echo "Вы выбрали Claude"
        ;;
    "2")
        echo "Вы выбрали Gemini"
        ;;
    "3")
        echo "Вы выбрали GLM"
        ;;
    *)
        echo "Некорректный выбор: $ai_choice"
        ;;
esac

echo ""
echo "=== ТЕСТ УСПЕШНО ЗАВЕРШЕН ==="
echo "Все интерактивные функции работают корректно!"