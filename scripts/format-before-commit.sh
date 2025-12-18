#!/bin/bash
# scripts/format-before-commit.sh - Форматирование кода перед коммитом

set -euo pipefail

echo "🔧 Автоматическое форматирование перед коммитом..."

# Форматирование Markdown файлов
if command -v markdownlint &>/dev/null; then
    echo "📝 Форматирование Markdown файлов..."
    find . -name "*.md" -not -path "./node_modules/*" -not -path "./.git/*" -print0 | \
    xargs -0 -r markdownlint --fix 2>/dev/null || true
fi

# Удаление trailing whitespace
echo "🧹 Удаление trailing whitespace..."
find . -type f -not -path "./node_modules/*" -not -path "./.git/*" -not -name "*.png" -not -name "*.jpg" -print0 | \
while IFS= read -r -d '' file; do
    if [[ -f "$file" ]]; then
        sed -i '' 's/[[:space:]]*$//' "$file" 2>/dev/null || true
    fi
done

# Добавление новых строк в конце файлов
echo "📄 Добавление новых строк в конце файлов..."
find . -type f -not -path "./node_modules/*" -not -path "./.git/*" -not -name "*.png" -not -name "*.jpg" -not -path "./.ai-state/*" -print0 | \
while IFS= read -r -d '' file; do
    if [[ -f "$file" ]] && [[ -s "$file" ]] && [[ "$(tail -c1 "$file" | wc -l)" -eq 0 ]]; then
        echo >> "$file" 2>/dev/null || true
    fi
done

echo "✅ Форматирование завершено!"
echo "💡 Теперь можно сделать коммит через TRAE"
