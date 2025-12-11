# CONFIGURATION_REFERENCE.md

> **⚙️ Complete Configuration Reference**
> *All settings, environment variables, and customization options*

**📍 Navigation**: [← Back to CLAUDE.md](./CLAUDE.md)

## 📋 Configuration Overview

This document provides a comprehensive reference for all configuration options in the Dual AI Assistant Environment.

## 🏗️ Configuration Architecture

### Configuration Hierarchy

```
1. System Defaults (built-in)
   ↓
2. Global Configuration (~/.docker-ai-config/)
   ↓
3. Environment Variables
   ↓
4. Project Configuration (.ai-state/)
   ↓
5. Runtime Parameters
```

### Priority Order

Higher priority overrides lower:

1. **Runtime Parameters** (highest)
2. **Project Configuration**
3. **Environment Variables**
4. **Global Configuration**
5. **System Defaults** (lowest)

---

## 🌍 Global Configuration

### Location: `~/.docker-ai-config/`

#### Environment Variables (`env`)

```bash
# Claude API Configuration
export CLAUDE_API_KEY="sk-ant-api03-..."      # Required for Claude mode
export CLAUDE_MODEL="claude-3-5-sonnet-20241022"
export CLAUDE_MAX_TOKENS=4096
export CLAUDE_TEMPERATURE=0.7

# Gemini Configuration
export GEMINI_MODEL="gemini-2.5-pro"
export GOOGLE_CLOUD_PROJECT="your-project-id"

# AI Assistant Behavior
export AI_CURRENT_MODE="gemini"               # or "claude"
export AI_AUTO_UPDATE=true
export AI_LOG_LEVEL="INFO"                    # DEBUG, INFO, WARN, ERROR

# Resource Limits
export AI_MEMORY_LIMIT="1Gi"
export AI_CPU_LIMIT="0.5"
export AI_MAX_INSTANCES=10

# Security Settings
export AI_REQUIRE_MFA=false
export AI_SESSION_TIMEOUT=3600               # seconds

# Development Settings
export AI_DEBUG_MODE=false
export AI_SAVE_SESSIONS=true
export AI_ENABLE_TELEMETRY=false
```

#### Gemini Configuration (`settings.json`)

```json
{
  "model": "gemini-2.5-pro",
  "generationConfig": {
    "temperature": 0.9,
    "topP": 0.8,
    "topK": 40,
    "maxOutputTokens": 8192,
    "candidateCount": 1
  },
  "safetySettings": [
    {
      "category": "HARM_CATEGORY_HARASSMENT",
      "threshold": "BLOCK_MEDIUM_AND_ABOVE"
    },
    {
      "category": "HARM_CATEGORY_HATE_SPEECH",
      "threshold": "BLOCK_MEDIUM_AND_ABOVE"
    },
    {
      "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
      "threshold": "BLOCK_MEDIUM_AND_ABOVE"
    },
    {
      "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
      "threshold": "BLOCK_MEDIUM_AND_ABOVE"
    }
  ],
  "tools": [
    {
      "functionDeclarations": [
        {
          "name": "execute_command",
          "description": "Execute a command in the container",
          "parameters": {
            "type": "object",
            "properties": {
              "command": {
                "type": "string",
                "description": "Command to execute"
              }
            },
            "required": ["command"]
          }
        }
      ]
    }
  ]
}
```

#### Claude Configuration (`claude_config.json`)

```json
{
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 4096,
  "temperature": 0.7,
  "top_p": 0.9,
  "top_k": 40,
  "stream": false,
  "system_prompt": "You are Claude Code, an expert AI assistant for software development. Provide clear, actionable advice and write clean, well-documented code.",
  "tools": {
    "enabled": [
      "bash",
      "text_editor",
      "computer"
    ],
    "bash": {
      "timeout": 30,
      "allowed_commands": [
        "ls", "cat", "grep", "find", "sed", "awk",
        "git", "npm", "python", "node", "docker"
      ]
    },
    "text_editor": {
      "max_file_size": "1MB",
      "allowed_extensions": [".js", ".py", ".sh", ".md", ".json", ".yml", ".yaml"]
    }
  }
}
```

---

## 📁 Project Configuration

### Location: `<project>/.ai-state/`

#### Project Context (`context.json`)

```json
{
  "project_name": "my-awesome-project",
  "project_type": "web_application",
  "tech_stack": {
    "frontend": "React",
    "backend": "Node.js",
    "database": "PostgreSQL",
    "deployment": "Docker"
  },
  "ai_preferences": {
    "default_mode": "claude",
    "focus_areas": ["security", "performance", "code_quality"],
    "excluded_patterns": ["node_modules", ".git", "dist"],
    "custom_prompt_additions": "This project uses TypeScript and follows strict typing conventions."
  },
  "session_history": {
    "last_session": "2025-12-11T10:30:00Z",
    "total_sessions": 15,
    "preferred_commands": ["refactor", "optimize", "debug"]
  }
}
```

#### Custom Prompts (`prompts/`)

```
.ai-state/prompts/
├── code-review.txt
├── architecture-analysis.txt
├── performance-optimization.txt
└── debugging-guide.txt
```

**Example Prompt (`code-review.txt`)**:
```
You are conducting a code review for this project. Focus on:

1. Security vulnerabilities
2. Performance bottlenecks
3. Code maintainability
4. Best practices adherence
5. Error handling completeness

Project context: {project_context}
Tech stack: {tech_stack}

Provide specific, actionable feedback with code examples where appropriate.
```

---

## 🐳 Container Configuration

### Dockerfile Build Args

```bash
# Custom versions during build
docker build \
  --build-arg GEMINI_VERSION=latest \
  --build-arg CLAUDE_VERSION=latest \
  --build-arg NODE_VERSION=22 \
  -t claude-code-tools .
```

### Runtime Configuration

```bash
# Environment-specific settings
docker run -e AI_MODE=claude \
           -e CLAUDE_MODEL=claude-3-opus-20240229 \
           -e AI_DEBUG_MODE=true \
           claude-code-tools
```

### Resource Limits

```yaml
# docker-compose.yml example
version: '3.8'
services:
  ai-assistant:
    image: claude-code-tools:latest
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 1G
        reservations:
          cpus: '0.25'
          memory: 512M
    environment:
      - AI_MODE=claude
      - CLAUDE_TEMPERATURE=0.5
```

---

## 🔧 Shell Configuration

### ai-assistant.zsh Configuration

```bash
# Custom configuration in ~/.zshrc
export AI_TOOLS_HOME="$HOME/tools/claude-code-docker-tools"

# Custom aliases
alias ai-dev='cd ~/dev && gemini'
alias ai-review='claude && cic'

# Custom functions
ai-workon() {
  local project=$1
  cd ~/projects/$project
  gemini
}

ai-config() {
  local key=$1
  local value=$2
  if [[ -n "$value" ]]; then
    echo "export $key=\"$value\"" >> ~/.docker-ai-config/env
  else
    grep "^export $key=" ~/.docker-ai-config/env
  fi
}
```

### Multi-Instance Configuration

```yaml
# ~/.docker-ai-config/instances.yml
instances:
  default:
    memory_limit: "1Gi"
    cpu_limit: "0.5"
    auto_start: false

  development:
    memory_limit: "2Gi"
    cpu_limit: "1.0"
    auto_start: true
    preferred_ports: [9001, 9002, 9003]

  production:
    memory_limit: "4Gi"
    cpu_limit: "2.0"
    security_level: "high"
    monitoring: true
```

---

## 🔌 Plugin Configuration

### Plugin System (Future Feature)

```json
{
  "plugins": {
    "enabled": ["github-integration", "jira-sync", "slack-notifications"],
    "github-integration": {
      "token": "${GITHUB_TOKEN}",
      "default_repo": "my-org/my-repo",
      "auto_create_prs": true
    },
    "jira-sync": {
      "url": "https://mycompany.atlassian.net",
      "username": "${JIRA_USERNAME}",
      "api_token": "${JIRA_TOKEN}",
      "project_key": "AI"
    },
    "slack-notifications": {
      "webhook_url": "${SLACK_WEBHOOK}",
      "channels": ["#ai-development", "#alerts"]
    }
  }
}
```

---

## 📊 Monitoring Configuration

### Metrics Collection

```yaml
# ~/.docker-ai-config/monitoring.yml
metrics:
  enabled: true
  collection_interval: 30s
  retention_period: 7d

  endpoints:
    prometheus: "http://localhost:9090"
    grafana: "http://localhost:3000"

  alerts:
    high_cpu_usage:
      threshold: 80
      duration: 5m
      action: "notify"

    memory_leak:
      threshold: 90
      duration: 2m
      action: "restart"

    container_failure:
      condition: "container_exited"
      action: "alert_and_restart"
```

### Logging Configuration

```json
{
  "logging": {
    "level": "INFO",
    "format": "json",
    "outputs": ["console", "file"],
    "file": {
      "path": "~/.docker-ai-config/logs/ai-assistant.log",
      "max_size": "100MB",
      "max_files": 5,
      "compress": true
    },
    "structured": {
      "include_timestamp": true,
      "include_level": true,
      "include_component": true,
      "include_session_id": true
    }
  }
}
```

---

## 🎨 Customization Examples

### Custom AI Modes

```bash
# Create custom AI mode function
ai-devops() {
  export AI_CURRENT_MODE="gemini"
  export GEMINI_TEMPERATURE=0.3
  export AI_FOCUS="infrastructure"
  gemini "$@"
}

ai-creative() {
  export AI_CURRENT_MODE="claude"
  export CLAUDE_TEMPERATURE=0.9
  export AI_FOCUS="innovation"
  claude "$@"
}
```

### Project Templates

```bash
# Initialize project with AI configuration
ai-init() {
  local project_type=$1
  local project_name=$2

  mkdir -p "$project_name/.ai-state/prompts"

  case "$project_type" in
    "react")
      cat > "$project_name/.ai-state/context.json" << EOF
{
  "project_type": "react_frontend",
  "tech_stack": {"frontend": "React", "state": "Redux"},
  "focus_areas": ["component_reusability", "performance", "accessibility"]
}
EOF
      ;;
    "node-api")
      cat > "$project_name/.ai-state/context.json" << EOF
{
  "project_type": "node_api",
  "tech_stack": {"backend": "Node.js", "database": "MongoDB"},
  "focus_areas": ["api_design", "security", "scalability"]
}
EOF
      ;;
  esac
}
```

### Environment-Specific Configs

```bash
# Development environment
ai-env-dev() {
  export AI_DEBUG_MODE=true
  export AI_LOG_LEVEL="DEBUG"
  export AI_AUTO_SAVE=true
}

# Production environment
ai-env-prod() {
  export AI_DEBUG_MODE=false
  export AI_LOG_LEVEL="WARN"
  export AI_REQUIRE_MFA=true
  export AI_SESSION_TIMEOUT=1800
}
```

---

## 🔍 Configuration Validation

### Validation Script

```bash
#!/bin/bash
# validate-config.sh

echo "🔍 Validating AI Assistant Configuration..."

# Check required files
required_files=(
  "$HOME/.docker-ai-config/env"
  "$HOME/.docker-ai-config/settings.json"
  "$HOME/.docker-ai-config/claude_config.json"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "❌ Missing required file: $file"
    exit 1
  fi
done

# Validate JSON files
for json_file in "$HOME/.docker-ai-config"/*.json; do
  if ! jq empty "$json_file" 2>/dev/null; then
    echo "❌ Invalid JSON in: $json_file"
    exit 1
  fi
done

# Check API key
if ! grep -q "CLAUDE_API_KEY" "$HOME/.docker-ai-config/env"; then
  echo "⚠️  Warning: Claude API key not configured"
fi

# Validate Docker
if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker is not running"
  exit 1
fi

echo "✅ Configuration validation passed"
```

---

## 🏷️ Configuration Tags

```
Type: CONFIGURATION_REFERENCE
Scope: ALL_SETTINGS
Version: 2.0
Environment_Variables: 15
JSON_Schemas: 3
Default_Values: 42
Last_Updated: 2025-12-11
Validation_Script: included
```