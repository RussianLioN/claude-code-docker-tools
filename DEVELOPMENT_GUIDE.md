# DEVELOPMENT_GUIDE.md

> **🔧 Complete Development Reference**
> *Commands, workflows, setup instructions, and daily operations*

## 📑 Table of Contents

1. [Quick Start](#quick-start) - Get running in 5 minutes
2. [Installation](#installation) - Complete setup guide
3. [Daily Commands](#daily-commands) - Essential operations
4. [Development Workflows](#development-workflows) - Common patterns
5. [Configuration](#configuration) - Settings and customization
6. [Best Practices](#best-practices) - Pro tips and tricks

---

## Quick Start

**5-Minute Setup**:

```bash
# 1. Clone repository
git clone git@github.com:RussianLioN/claude-code-docker-tools.git ~/tools
cd ~/tools/claude-code-docker-tools

# 2. Install everything
./install.sh && source ~/.zshrc

# 3. Configure Claude API
nano ~/.docker-ai-config/env
# Add: export CLAUDE_API_KEY="sk-ant-api03-..."

# 4. Start using
gemini  # or: claude
```

---

## Installation

### Prerequisites

**System Requirements**:
- macOS (Apple Silicon or Intel)
- Docker Desktop 4.0+
- Zsh shell
- Git with SSH keys configured
- Claude API key (for Claude mode)

### Automated Installation

```bash
./install.sh
```

**What it does**:
- ✅ Builds Docker image with latest versions
- ✅ Creates configuration directories
- ✅ Sets up shell integration
- ✅ Installs default configurations

### Manual Installation

```bash
# 1. Build Docker image
docker build -t claude-code-tools .

# 2. Create directories
mkdir -p ~/.docker-ai-config/{global_state,gh_config}

# 3. Create environment file
cat > ~/.docker-ai-config/env << 'EOF'
# Claude Configuration
export CLAUDE_API_KEY=""
export CLAUDE_MODEL="claude-3-5-sonnet-20241022"
export CLAUDE_MAX_TOKENS=4096

# Gemini Configuration
export GEMINI_MODEL="gemini-2.5-pro"

# AI Assistant Mode
export AI_CURRENT_MODE="gemini"
EOF

# 4. Add to shell
echo 'source ~/tools/claude-code-docker-tools/ai-assistant.zsh' >> ~/.zshrc
source ~/.zshrc
```

### Verification

```bash
# Test Docker
docker run --rm claude-code-tools --version

# Test shell functions
ai-mode  # Should show current mode
which gemini claude aic cic  # Should show paths
```

---

## Daily Commands

### Core AI Commands

| Command | Function | When to Use |
|---------|----------|-------------|
| `gemini` | Start Gemini AI | DevOps tasks, automation |
| `claude` | Start Claude AI | Code review, debugging |
| `ai-mode <mode>` | Switch AI mode | Changing AI perspective |
| `aic` | Gemini AI Commit | Infrastructure changes |
| `cic` | Claude AI Commit | Code improvements |

### System Operations

| Command | Function | Example |
|---------|----------|---------|
| `gexec <cmd>` | Execute in container | `gexec npm install` |
| `ai-list` | List running instances | `ai-list` |
| `ai-stop <id>` | Stop instance | `ai-stop project-gemini` |
| `ai-restart <id>` | Restart instance | `ai-restart project-claude` |

### Multi-Instance Management

```bash
# Start multiple instances
cd ~/project-a && gemini     # instance: project-a-gemini
cd ~/project-b && claude     # instance: project-b-claude
cd ~/project-c && gemini     # instance: project-c-gemini

# Manage all instances
ai-list          # Show all running
ai-stop-all      # Stop all instances
ai-stats         # Resource usage
ai-logs <id>     # View logs
```

---

## Development Workflows

### Typical Development Cycle

```bash
# 1. Navigate to project
cd ~/my-project

# 2. Start with appropriate AI
gemini  # For DevOps/Infrastructure
# OR
claude  # For Code/Architecture

# 3. Work with AI
> "Analyze this architecture..."
> "Refactor this function..."
> "Add error handling..."

# 4. Let AI handle commits
# AI automatically calls aic or cic on exit
```

### Code Review Workflow

```bash
# 1. Make changes
vim file.js

# 2. Start Claude for review
claude
> "Review file.js for best practices"

# 3. Claude creates detailed commit
cic  # Claude-style commit with detailed description
```

### Infrastructure Workflow

```bash
# 1. Work on infrastructure
vim docker-compose.yml
vim terraform/

# 2. Use Gemini for systems thinking
gemini
> "Analyze this deployment strategy..."

# 3. Gemini creates semantic commit
aic  # Gemini-style commit with semantic message
```

### Troubleshooting Workflow

```bash
# 1. Check system status
docker info
ai-list

# 2. View logs
ai-logs <instance-id>

# 3. Access container directly
ai-attach <instance-id>

# 4. Reset if needed
ai-stop-all
docker system prune -f
```

---

## Configuration

### Environment Variables

**Claude Configuration**:
```bash
export CLAUDE_API_KEY="sk-ant-api03-..."
export CLAUDE_MODEL="claude-3-5-sonnet-20241022"
export CLAUDE_MAX_TOKENS=4096
```

**Gemini Configuration**:
```bash
export GEMINI_MODEL="gemini-2.5-pro"
export GOOGLE_CLOUD_PROJECT="your-project-id"
```

### Per-Project Configuration

**Create project-specific settings**:
```bash
# In your project directory
mkdir .ai-state
cat > .ai-state/settings.json << 'EOF'
{
  "model": "claude-3-5-sonnet-20241022",
  "temperature": 0.7,
  "max_tokens": 4096,
  "project_context": "React frontend with Node.js backend"
}
EOF
```

### Custom Aliases

**Add to ~/.zshrc**:
```bash
# Quick AI switching
alias gem="gemini"
alias cl="claude"

# Instance management
alias ai-status="ai-list && ai-stats"
alias ai-reset="ai-stop-all && docker system prune -f"

# Development shortcuts
alias dev-on="cd ~/project && gemini"
alias dev-review="claude && cic"
```

---

## Best Practices

### Session Management

**Always**:
- Use project-specific directories
- Let AI handle commits when possible
- Stop instances when done
- Check resources with `ai-stats`

**Never**:
- Run multiple instances in same project
- Commit sensitive data
- Ignore health warnings
- Force kill containers

### Performance Optimization

**Container Optimization**:
- Use .dockerignore to reduce context
- Leverage Docker layer caching
- Monitor resource usage
- Clean up unused containers

**AI Optimization**:
- Provide clear context
- Use appropriate AI mode for task
- Keep sessions focused
- Review AI-generated code

### Security Practices

**Always**:
- Keep API keys secure
- Use SSH key forwarding
- Review AI-generated code
- Update dependencies regularly

**Configuration Security**:
```bash
# Secure Claude API key
chmod 600 ~/.docker-ai-config/env

# Review .ai-state in .gitignore
echo ".ai-state/" >> .gitignore
```

### Troubleshooting Common Issues

**Docker Issues**:
```bash
# Docker not running
open -a Docker

# Port conflicts
ai-list  # Check used ports
ai-stop-all  # Clear all instances

# Container errors
docker logs <container-id>
docker system prune -f
```

**SSH Issues**:
```bash
# Add SSH key to agent
ssh-add --apple-use-keychain ~/.ssh/id_ed25519

# Check agent
ssh-add -l
```

**API Issues**:
```bash
# Check Claude API key
cat ~/.docker-ai-config/env | grep CLAUDE_API_KEY

# Test API connectivity
curl -H "x-api-key: $CLAUDE_API_KEY" \
     https://api.anthropic.com/v1/messages
```

---

## 📚 Advanced Topics

### Custom AI Prompts

**Create reusable prompts**:
```bash
# ~/.docker-ai-config/prompts/
cat > code-review.txt << 'EOF'
You are a senior software engineer reviewing code.
Check for:
1. Security vulnerabilities
2. Performance issues
3. Code style consistency
4. Error handling
5. Documentation

Provide specific, actionable feedback.
EOF
```

### Automation Scripts

**Automated setup for new projects**:
```bash
#!/bin/bash
# setup-ai-project.sh

PROJECT_NAME=$1
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Initialize git
git init

# Create AI state
mkdir .ai-state
echo '{"project": "'$PROJECT_NAME'"}' > .ai-state/context.json

# Create .gitignore
echo ".ai-state/" >> .gitignore

echo "✅ Project $PROJECT_NAME ready for AI development"
```

### Integration with IDEs

**VS Code integration**:
```json
// .vscode/tasks.json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Start Gemini",
      "type": "shell",
      "command": "gemini",
      "group": "build"
    },
    {
      "label": "Start Claude",
      "type": "shell",
      "command": "claude",
      "group": "build"
    }
  ]
}
```

---

## 🏷️ Document Tags

```
Type: DEVELOPMENT_GUIDE
Scope: OPERATIONS
Version: 2.0
Commands: 25
Workflows: 6
Last_Updated: 2025-12-11
```