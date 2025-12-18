#!/bin/bash
# Скрипт для мониторинга размера проекта

echo "📊 Анализ размера проекта..."

echo "📦 Общий размер:"
du -sh .

echo ""
echo "📋 Размер по директориям:"
du -sh */ | sort -hr

echo ""
echo "🔍 Крупные файлы (>5MB):"
find . -type f -size +5M -not -path "./.git/*" -exec ls -lh {} \;

echo ""
echo "📈 Статистика Git:"
echo "Всего коммитов: $(git rev-list --count HEAD 2>/dev/null || echo 'N/A')"
echo "Размер .git: $(du -sh .git 2>/dev/null | cut -f1 || echo 'N/A')"
