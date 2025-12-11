# CLAUDE.md

> **🤖 Central AI Assistant Guide for Dual AI Environment**
> *Guidance for Claude Code (claude.ai/code) working in this repository*

## 📑 Table of Contents

1. [⚡ Quick Start](#-quick-start) - Essential commands
2. [🌐 Language Policies](#-language-policies) - Communication rules
3. [🏗️ Project Overview](#️-project-overview) - Architecture summary
4. [🔧 Development Commands](#-development-commands) - Build & usage
5. [⚙️ Configuration Architecture](#️-configuration-architecture) - State management
6. [🔒 Security Model](#-security-model) - Security principles
7. [🤖 AI Mode Differences](#-ai-mode-differences) - Mode comparison
8. [💼 Common Workflows](#-common-workflows) - Development patterns
9. [🐛 Troubleshooting](#-troubleshooting) - Issue resolution
10. [📦 Container Internals](#-container-internals) - Technical details
11. [📚 Required Reading](#-required-reading) - Critical documents

---

## ⚡ Quick Start

**🔥 Most Used Commands (Learn these first)**:

```bash
# Daily AI work
gemini                    # Start Gemini AI
claude                    # Start Claude AI
aic                       # AI Commit (Gemini style)
cic                       # AI Commit (Claude style)

# System operations
./install.sh             # Initial setup
ai-mode <gemini|claude>  # Switch AI mode
gexec <command>          # Run in container
```

---

## 🌐 Language Policies

**🚨 CRITICAL: All interactions must follow Russian language guidelines**

| Context | Language Required | Notes |
|---------|------------------|-------|
| **User Communication** | Russian only | All responses to user |
| **Code Comments** | Russian only | Inline documentation |
| **File Creation** | Russian only | Documentation, texts |
| **Internal Processing** | English preferred | AI internal thoughts |
| **Final Results** | Russian only | Output to user |

---

## 🏗️ Project Overview

This is a **Dual AI Assistant Environment** that provides unified Docker-based access to both Google Gemini CLI and Anthropic Claude Code CLI. The project is designed for macOS developers to manage CLI AI tools without dependency conflicts.

### 🏛️ Core Architecture

#### Main Components

| Component | Purpose | Key Features |
|-----------|---------|--------------|
| **ai-assistant.zsh** | Central wrapper script | • `gemini()` - Gemini CLI launcher<br>• `claude()` - Claude CLI launcher<br>• `aic()/cic()` - AI commits<br>• `gexec()` - Container commands<br>• `ai-mode()` - Mode switcher |
| **Dockerfile** | Container definition | • Base: `node:22-alpine`<br>• Dual AI tools installed<br>• System utilities included |
| **entrypoint.sh** | Runtime router | • Detects `AI_MODE`<br>• Routes to correct CLI |

#### 🔄 Architecture Flow

```
macOS Host
    ↓
ai-assistant.zsh (wrapper)
    ↓
Docker Container
    ↓
entrypoint.sh (router)
    ↓
[ Gemini CLI | Claude CLI ]
```

## 🔧 Development Commands

### 📦 Build and Install
**⚙️ Setup Phase** (Run once):

```bash
# Build Docker image manually
docker build -t claude-code-tools .

# OR use automated installer (recommended)
./install.sh && source ~/.zshrc
```

### 🚀 Daily Usage Commands
**🔄 AI Assistant Operations**:

| Command | Function | When to Use |
|---------|----------|-------------|
| `gemini` | Start Gemini AI | DevOps tasks, automation |
| `claude` | Start Claude AI | Code review, debugging |
| `ai-mode gemini` | Switch to Gemini | Need DevOps perspective |
| `ai-mode claude` | Switch to Claude | Need code analysis |

**🤖 AI-Powered Commits**:

| Command | Style | Best For |
|---------|-------|----------|
| `aic` | DevOps/semantic | Infrastructure changes |
| `cic` | Software Engineer | Code improvements |

**🛠️ System Operations**:

```bash
gexec <command>          # Execute in container environment
gexec npm install        # Example: install npm packages
gexec python script.py   # Example: run Python script
```

### 🧪 Testing and CI
**✅ Quality Assurance**:

```bash
# CI/CD operations
gh workflow run "CI/CD Pipeline"    # Run full pipeline

# Local validation
bash -n install.sh                  # Syntax check
zsh -n ai-assistant.zsh             # Syntax check
docker build -t test .              # Test build
```

## ⚙️ Configuration Architecture

### 🔄 State Synchronization Pattern
**Pattern**: Sync In → Runtime → Sync Out

The project handles VirtioFS limitations through state synchronization:

1. **Sync In**: Copy from `~/.docker-ai-config/` → project `.ai-state/`
2. **Runtime**: Docker mounts `.ai-state/` with configurations
3. **Sync Out**: Save updated configs back to global location

### 📁 Global Configuration (`~/.docker-ai-config/`)

| File | Purpose | Sensitive? |
|------|---------|------------|
| `env` | API keys & environment variables | 🔒 YES |
| `settings.json` | Gemini configuration | No |
| `claude_config.json` | Claude configuration | 🔒 May contain API keys |
| `google_accounts.json` | Gemini OAuth tokens | 🔒 YES |
| `gh_config/` | GitHub CLI configuration | 🔒 YES |

### 📂 Project-Specific State (`<project>/.ai-state/`)

| File | Purpose | Auto-generated |
|------|---------|---------------|
| `ssh_config_clean` | Sanitized SSH config | ✅ |
| `google_accounts.json` | Project Gemini auth | ✅ |
| `settings.json` | Project Gemini settings | ✅ |

### 🛡️ Security Note
The `.ai-state/` directory is **automatically added to `.gitignore`** to prevent committing sensitive data.

## 🔒 Security Model

### 🛡️ Zero Trust Approach

**🔐 Security Principles**:
- ✅ Secrets never leave host disk
- ✅ API keys only in environment variables
- ✅ SSH agent forwarding for authentication
- ✅ Auto `.ai-state/` → `.gitignore`

### 🔧 SSH Configuration Sanitization
**Removed from SSH config for container compatibility**:

- `UseKeychain` - macOS specific
- `AddKeysToAgent` - Agent management
- `IdentityFile` - Key paths
- `IdentitiesOnly` - Identity restriction

### 🔑 Authentication Flow

```
Host SSH Agent
    ↓
Forward to Container
    ↓
Sanitized Config
    ↓
Git/GitHub Operations
```

## 🤖 AI Mode Differences

| Feature | 🧠 Gemini | 🤖 Claude Code |
|---------|-----------|----------------|
| **Persona** | DevOps Engineer | Senior Software Engineer |
| **Strengths** | Systems, automation, CI/CD | Code, algorithms, architecture |
| **Commit Style** | Conventional, semantic | Detailed, descriptive |
| **Authentication** | OAuth Google | API Key Anthropic |
| **Best For** | Infrastructure, deployment | Code review, debugging |

## 💼 Common Workflows

### 🔄 Development Cycle
**Typical AI-Assisted Development**:

```bash
# 1. Start with Gemini for system thinking
cd ~/project
gemini                    # DevOps perspective
# ... make infrastructure changes ...
aic                       # Commit with semantic style

# 2. Switch to Claude for code quality
ai-mode claude            # Change AI mode
claude                    # Code review mode
# ... improve code quality ...
cic                       # Commit with detailed style
```

### 🚀 First-time Setup
**Complete Onboarding**:

```bash
# 1. Installation
git clone <repo> ~/tools/claude-code-docker-tools
cd ~/tools/claude-code-docker-tools
./install.sh && source ~/.zshrc

# 2. Configure APIs
nano ~/.docker-ai-config/env
# Add: export CLAUDE_API_KEY="sk-ant-api03-..."

# 3. Initialize Gemini
gemini                    # First run triggers OAuth

# 4. Start working
gemini                    # or: claude
```

**📖 For Git operations**: See [GIT_WORKFLOWS.md](./GIT_WORKFLOWS.md) for complete Git guide including handoff procedures.

## 🐛 Troubleshooting

### 🔧 Common Issues & Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Docker not running** | "Cannot connect to daemon" | `open -a Docker` |
| **SSH agent empty** | Git auth failures | `ssh-add --apple-use-keychain ~/.ssh/id_ed25519` |
| **Claude API missing** | "API key not found" | Edit `~/.docker-ai-config/env` |
| **Permission denied** | Docker mount errors | Check folder permissions |

**🔧 Git-specific issues**: See [Troubleshooting in GIT_WORKFLOWS.md](./GIT_WORKFLOWS.md#-emergency-procedures) for Git-related problems.

### 🩺 Diagnostic Commands

```bash
# System checks
docker info                                    # Docker status
ssh-add -l                                     # SSH agent status
docker run --rm claude-code-tools --version    # Container version

# Config validation
cat ~/.docker-ai-config/env                   # Check API keys
ls -la ~/.docker-ai-config/                   # Config directory
```

## 📦 Container Internals

### 🔄 Volume Mounts
**Container ↔ Host Mapping**:

| Host | Container | Purpose |
|------|-----------|---------|
| `<project>` | `/app/<project-name>` | Project workspace |
| `<project>/.ai-state` | `/root/.ai` | AI state & config |
| SSH socket | `/run/host-services/ssh-auth.sock` | SSH forwarding |
| `~/.gitconfig` | `/root/.gitconfig` | Git configuration |

### 🔧 Environment Variables
**Runtime Configuration**:

| Variable | Purpose | Required |
|----------|---------|----------|
| `AI_MODE` | CLI selector (`claude`|`gemini`) | Auto-set |
| `CLAUDE_API_KEY` | Claude authentication | 🔒 For Claude |
| `GOOGLE_CLOUD_PROJECT` | Gemini OAuth project | Auto-set |
| `GEMINI_MODEL` | Gemini model selection | Optional |
| `CLAUDE_MODEL` | Claude model selection | Optional |

### 🌐 Network Configuration
**Container Network Settings**:

- **Mode**: `--network host` (optimal performance)
- **SSH**: Agent forwarding enabled
- **Git**: Full SSH/GitHub CLI support
- **External APIs**: Direct access (Claude/Gemini)

---

## 📚 Required Reading (Study Every Session)

### 🚨 CRITICAL DOCUMENTS

**MANDATORY**: Read [AI_SYSTEM_INSTRUCTIONS.md](./AI_SYSTEM_INSTRUCTIONS.md) before making any changes to this repository.

**⚠️ This document contains**:
- Critical testing principles
- Development workflows
- Rules that OVERRIDE all other instructions
- Code quality requirements

**These rules ensure**:
- ✅ Code reliability
- ✅ System stability
- ✅ Quality standards
- ✅ Testing discipline

### 📖 Additional References

- **[GIT_WORKFLOWS.md](./GIT_WORKFLOWS.md)** - Complete Git operations guide, handoff procedures, and emergency rollback instructions
- **[SESSION_MANAGEMENT_ARCHITECTURE.md](./SESSION_MANAGEMENT_ARCHITECTURE.md)** - Multi-instance architecture design for running multiple concurrent AI assistants across different projects

---

## 🏷️ Document Tags

```
Priority: CRITICAL
Type: AI_INSTRUCTIONS
Scope: ENTIRE_REPOSITORY
Version: 2.0
Last Updated: 2025-12-11
Validated: ✅
```