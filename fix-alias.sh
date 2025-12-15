#!/bin/bash

# Script to fix gemini alias conflict
# Replaces old gemini-docker-setup reference with current claude-code-docker-tools

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_ASSISTANT_SCRIPT="$CURRENT_DIR/ai-assistant.zsh"
ZSHRC="$HOME/.zshrc"

echo "🔧 Fixing AI Assistant aliases in $ZSHRC..."

if [[ -f "$ZSHRC" ]]; then
  # Create backup
  cp "$ZSHRC" "$ZSHRC.bak"
  echo "📦 Backup created at $ZSHRC.bak"

  # Remove old reference if exists
  if grep -q "gemini-docker-setup" "$ZSHRC"; then
    sed -i '' '/gemini-docker-setup/d' "$ZSHRC"
    echo "🗑️  Removed old gemini-docker-setup reference"
  fi

  # Add new reference if not exists
  if ! grep -q "claude-code-docker-tools/ai-assistant.zsh" "$ZSHRC"; then
    echo "" >> "$ZSHRC"
    echo "# AI Assistant Tools" >> "$ZSHRC"
    echo "source \"$AI_ASSISTANT_SCRIPT\"" >> "$ZSHRC"
    echo "✅ Added new AI Assistant reference"
  else
    echo "✅ AI Assistant reference already exists"
  fi

  echo "🎉 Done! Please run: source ~/.zshrc"
else
  echo "❌ .zshrc not found"
fi
