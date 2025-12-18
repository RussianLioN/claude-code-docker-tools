# GitOps Workflow

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)

---

## GitOps Principles

1. ✅ **Declarative** - Config описан в Git (YAML/JSON)
2. ✅ **Versioned** - Каждое изменение = commit
3. ✅ **Immutable** - Старые версии не изменяются
4. ✅ **Pulled** - Reconciliation loop тянет изменения
5. ✅ **Reconciled** - Автоматическое приведение к desired state

---

## GitOps Workflow

```
┌─────────────────────────────────────────────────────┐
│ 1. Developer                                        │
│    ├─ Edit .claude/settings.json                   │
│    ├─ git commit -m "Update settings"              │
│    └─ git push origin main                         │
└─────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────┐
│ 2. CI/CD Pipeline (GitHub Actions)                 │
│    ├─ Validate JSON syntax (jq)                    │
│    ├─ Run config tests                             │
│    ├─ Check for secrets in plaintext               │
│    └─ Merge to main (if passed)                    │
└─────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────┐
│ 3. Reconciliation Loop (Local Agent)               │
│    ├─ git pull origin main (every 60s)             │
│    ├─ detect_drift()                               │
│    ├─ decrypt_secrets() via SOPS                   │
│    └─ reconcile_config()                           │
└─────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────┐
│ 4. Apply Changes                                    │
│    ├─ validate_claude_config()                     │
│    ├─ sync_claude_config_in()                      │
│    ├─ verify_sync_integrity()                      │
│    └─ smoke_test()                                  │
└─────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────┐
│ 5. Verification & Rollback                         │
│    ├─ If smoke test passed → SUCCESS               │
│    └─ If failed → rollback_config() + alert        │
└─────────────────────────────────────────────────────┘
```

---

## Setup: Encrypted Secrets (SOPS)

### 1. Install SOPS + age

```bash
# macOS
brew install sops age

# Linux
curl -LO https://github.com/mozilla/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops
sudo chmod +x /usr/local/bin/sops
```

### 2. Generate age encryption key

```bash
# Generate key
age-keygen -o ~/.config/sops/age/keys.txt

# Show public key
cat ~/.config/sops/age/keys.txt | grep "public key:"
# Example output: public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
```

### 3. Configure SOPS

```bash
# Create .sops.yaml в корне проекта
cat > .sops.yaml <<SOPS
creation_rules:
  - path_regex: \.claude/\.claude\.json\.enc$
    age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
SOPS

git add .sops.yaml
git commit -m "chore: add SOPS configuration"
```

### 4. Encrypt secrets

```bash
# Encrypt ~/.claude.json
sops --encrypt ~/.claude.json > .claude/.claude.json.enc

# Add encrypted file to Git
git add .claude/.claude.json.enc

# Add plaintext to .gitignore
echo ".claude/.claude.json" >> .gitignore
echo "!.claude/.claude.json.enc" >> .gitignore

git commit -m "feat: add encrypted credentials"
git push
```

### 5. Decrypt on deploy

**Manual**:
```bash
sops --decrypt .claude/.claude.json.enc > ~/.claude.json
chmod 600 ~/.claude.json
```

**Automated** (в `lib/gitops.sh`):
```bash
decrypt_secrets() {
  if [[ -f ".claude/.claude.json.enc" ]]; then
    sops --decrypt .claude/.claude.json.enc > ~/.claude.json
    chmod 600 ~/.claude.json
    echo "✅ Secrets decrypted"
  fi
}
```

---

## Reconciliation Loop

**Файл**: `lib/gitops.sh`

```bash
#!/bin/bash
# lib/gitops.sh - GitOps reconciliation

set -euo pipefail

GITOPS_CHECK_INTERVAL="${GITOPS_CHECK_INTERVAL:-60}"  # seconds
GITOPS_REPO_PATH="${GITOPS_REPO_PATH:-$(pwd)}"

# Detect config changes
config_changed_since_last_run() {
  local last_commit=$(cat ~/.claude-gitops-last-commit 2>/dev/null || echo "")
  local current_commit=$(git -C "$GITOPS_REPO_PATH" rev-parse HEAD)

  if [[ "$last_commit" != "$current_commit" ]]; then
    # Check if .claude/ changed
    if git -C "$GITOPS_REPO_PATH" diff --name-only "$last_commit" "$current_commit" | grep -q "^\.claude/"; then
      echo "$current_commit" > ~/.claude-gitops-last-commit
      return 0
    fi
  fi

  return 1
}

# Decrypt secrets via SOPS
decrypt_secrets() {
  if [[ -f "$GITOPS_REPO_PATH/.claude/.claude.json.enc" ]]; then
    sops --decrypt "$GITOPS_REPO_PATH/.claude/.claude.json.enc" > ~/.claude.json
    chmod 600 ~/.claude.json
    log_event "info" "secrets_decrypted" "{}"
  fi
}

# Reconcile config from Git to runtime
reconcile_config() {
  echo "🔄 Reconciling config from Git..."

  # Pull latest
  git -C "$GITOPS_REPO_PATH" pull origin main --quiet || {
    log_error "Git pull failed" "gitops"
    return 1
  }

  # Detect changes
  if ! config_changed_since_last_run; then
    return 0
  fi

  echo "📝 Config changes detected, applying..."

  # Decrypt secrets
  decrypt_secrets || {
    log_error "Decryption failed" "gitops"
    return 1
  }

  # Sync config from repo to ~/.claude/
  rsync -a --delete \
    "$GITOPS_REPO_PATH/.claude/" "$HOME/.claude/" || {
    log_error "Config sync failed" "gitops"
    return 1
  }

  # Validate
  validate_claude_config || {
    log_error "Config validation failed after sync" "gitops"
    # Rollback
    rollback_config
    return 1
  }

  # Smoke test
  smoke_test || {
    log_error "Smoke test failed after config change" "gitops"
    # Rollback
    rollback_config
    return 1
  }

  log_event "info" "config_reconciled" "{}"
  echo "✅ Config reconciled successfully"
}

# Smoke test
smoke_test() {
  claude --version >/dev/null 2>&1
}

# Rollback config
rollback_config() {
  echo "🚨 Rolling back config..."

  # Restore from last backup
  local last_backup=$(cat /tmp/claude-last-backup 2>/dev/null || echo "")
  if [[ -n "$last_backup" && -d "$last_backup" ]]; then
    rsync -a --delete "$last_backup/claude/" "$HOME/.claude/"
    cp "$last_backup/claude.json" "$HOME/.claude.json" 2>/dev/null || true
    echo "✅ Config rolled back"
  else
    echo "❌ No backup found for rollback"
    return 1
  fi
}

# Detect config drift (runtime != Git)
detect_drift() {
  local git_checksum=$(find "$GITOPS_REPO_PATH/.claude/" -type f -name "*.json" -exec md5 {} \; | sort | md5)
  local runtime_checksum=$(find "$HOME/.claude/" -type f -name "*.json" -exec md5 {} \; | sort | md5)

  if [[ "$git_checksum" != "$runtime_checksum" ]]; then
    log_event "warn" "config_drift_detected" "{}"
    return 0  # Drift detected
  fi

  return 1  # No drift
}

# Main reconciliation loop
gitops_reconcile_loop() {
  echo "🔄 Starting GitOps reconciliation loop..."

  while true; do
    reconcile_config || {
      log_error "Reconciliation failed" "gitops"
    }

    sleep "$GITOPS_CHECK_INTERVAL"
  done
}

# Export functions
export -f reconcile_config
export -f decrypt_secrets
export -f detect_drift
export -f gitops_reconcile_loop
```

---

## CI/CD Integration (GitHub Actions)

**Файл**: `.github/workflows/validate-config.yml`

```yaml
name: Validate Claude Config

on:
  pull_request:
    paths:
      - '.claude/**'
  push:
    branches:
      - main
    paths:
      - '.claude/**'

jobs:
  validate:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Install jq
        run: sudo apt-get install -y jq

      - name: Validate JSON syntax
        run: |
          for file in .claude/*.json; do
            echo "Validating $file..."
            jq empty "$file" || exit 1
          done

      - name: Check for plaintext secrets
        run: |
          # Ensure .claude.json is encrypted
          if [[ -f .claude/.claude.json ]]; then
            echo "ERROR: .claude.json must be encrypted (.claude.json.enc)"
            exit 1
          fi

          # Check for leaked tokens
          if grep -r "sk-ant-" .claude/; then
            echo "ERROR: Found plaintext API token"
            exit 1
          fi

      - name: Validate settings schema
        run: |
          # Add custom validation logic here
          echo "✅ Config validation passed"
```

---

## Audit Trail

**Log all config changes**:
```bash
# In lib/gitops.sh
audit_config_change() {
  local change_type="$1"
  local files_changed="$2"

  cat >> ~/.claude-gitops-audit.log <<AUDIT
{
  "timestamp": "$(date -Iseconds)",
  "change_type": "$change_type",
  "files": "$files_changed",
  "commit": "$(git -C "$GITOPS_REPO_PATH" rev-parse HEAD)",
  "user": "$USER"
}
AUDIT
}
```

**Query audit log**:
```bash
# Show all config changes
jq -r '.timestamp + " " + .change_type + " " + .files' \
  ~/.claude-gitops-audit.log

# Show changes by user
jq -r 'select(.user == "john") | .timestamp + " " + .files' \
  ~/.claude-gitops-audit.log
```

---

## Team Collaboration

### Multi-user setup

```bash
# Share encrypted config via Git
git clone https://github.com/team/claude-config.git
cd claude-config

# Each user generates their own age key
age-keygen -o ~/.config/sops/age/keys.txt

# Admin adds user's public key to .sops.yaml
cat >> .sops.yaml <<SOPS
  - path_regex: \.claude/\.claude\.json\.enc$
    age: >-
      age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p,
      age1<NEW_USER_PUBLIC_KEY>
SOPS

# Re-encrypt with new keys
sops updatekeys .claude/.claude.json.enc

git add .sops.yaml .claude/.claude.json.enc
git commit -m "feat: add new team member"
git push
```

---

## Drift Detection Dashboard

```bash
#!/bin/bash
# Show config drift status

echo "=== GitOps Status ==="
echo ""

# Last sync time
if [[ -f ~/.claude-gitops-last-commit ]]; then
  last_commit=$(cat ~/.claude-gitops-last-commit)
  echo "Last synced commit: $last_commit"
else
  echo "Never synced"
fi

# Current Git commit
current_commit=$(git -C "$GITOPS_REPO_PATH" rev-parse HEAD)
echo "Current Git commit: $current_commit"

# Drift detection
if detect_drift; then
  echo "⚠️ Config drift detected!"
  echo "Run 'reconcile_config' to sync"
else
  echo "✅ No drift - runtime matches Git"
fi
```

---

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)
