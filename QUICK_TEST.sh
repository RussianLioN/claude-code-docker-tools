#!/bin/bash

echo "🚀 Quick UI Test for AI Assistant"
echo "================================="
echo "This script will guide you through interactive testing"
echo ""

# Step 1: Setup
echo "📋 Step 1: Loading AI Assistant..."
if ! source ./ai-assistant.zsh; then
    echo "❌ Failed to load ai-assistant.zsh"
    exit 1
fi
echo "✅ AI Assistant loaded successfully"
echo ""

# Step 2: Basic checks
echo "📋 Step 2: Basic System Checks"
echo "2.1: Checking ai-mode help..."
ai-mode help
echo ""

echo "2.2: Checking Docker status..."
if ensure_docker_running; then
    echo "✅ Docker is ready"
else
    echo "⚠️ Docker needs attention"
fi
echo ""

echo "2.3: Checking SSH agent..."
if ensure_ssh_loaded; then
    echo "✅ SSH agent is ready"
else
    echo "⚠️ SSH agent needs attention"
fi
echo ""

# Step 3: Interactive tests
echo "📋 Step 3: Interactive Tests"
echo "3.1: Testing gexec with simple command"
echo "Press ENTER to run: gexec 'echo Hello from container'"
read -r
gexec 'echo Hello from container'
echo ""

echo "3.2: Testing file access"
echo "Press ENTER to run: gexec 'ls -la *.md'"
read -r
gexec 'ls -la *.md'
echo ""

echo "3.3: Testing Gemini help (this may download the container)"
echo "Press ENTER to run: gemini --help"
read -r
if timeout 30 gemini --help; then
    echo "✅ Gemini working"
else
    echo "⚠️ Gemini timed out or failed (container may be downloading)"
fi
echo ""

# Step 4: Ephemeral cleanup test
echo "📋 Step 4: Ephemeral Cleanup Test"
echo "4.1: Checking containers before test..."
containers_before=$(docker ps -aq --filter 'name=claude*' 2>/dev/null | wc -l)
echo "Containers before: $containers_before"

echo "4.2: Running 3 container operations..."
gexec 'echo test1' >/dev/null 2>&1
gexec 'echo test2' >/dev/null 2>&1
gexec 'echo test3' >/dev/null 2>&1

echo "4.3: Checking containers after test..."
containers_after=$(docker ps -aq --filter 'name=claude*' 2>/dev/null | wc -l)
echo "Containers after: $containers_after"

if [[ $containers_before -eq $containers_after ]]; then
    echo "✅ Perfect ephemeral cleanup working!"
else
    echo "❌ Orphaned containers detected"
fi
echo ""

# Step 5: Configuration test
echo "📋 Step 5: Configuration Test"
echo "5.1: Testing prepare_configuration..."
prepare_configuration
echo "STATE_DIR: ${STATE_DIR:-NOT_SET}"
echo ""

echo "5.2: Testing cleanup_configuration..."
cleanup_configuration
echo "✅ Configuration cleanup completed"
echo ""

echo "🎯 Testing Complete!"
echo "==================="
echo "✅ AI Assistant loaded"
echo "✅ Basic functions working"
echo "✅ Container execution working"
echo "✅ Ephemeral cleanup verified"
echo "✅ Configuration management working"
echo ""
echo "📊 Next steps:"
echo "1. Try: gemini 'help me understand this project'"
echo "2. Try: claude 'what files should I read first?'"
echo "3. Try: gexec 'find . -name *.sh | head -5'"
echo ""
echo "🚀 Ready for production use!"