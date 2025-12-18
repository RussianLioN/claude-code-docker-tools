# GitOps Integration

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)

---

## 🔄 GitOps Workflow

**📘 Детальная реализация**: [lib/gitops.sh](../../lib/gitops.sh)

**Принципы GitOps**:

1. ✅ **Declarative**: Config описан в Git (YAML/JSON)
2. ✅ **Versioned**: Каждое изменение = commit
3. ✅ **Immutable**: Старые версии не изменяются
4. ✅ **Pulled**: Reconciliation loop тянет изменения
5. ✅ **Reconciled**: Автоматическое приведение к desired state

## Encrypted Secrets (SOPS)

**Setup**:

```bash
# 1. Install SOPS + age
brew install sops age

# 2. Generate key
age-keygen -o ~/.config/sops/age/keys.txt

# 3. Configure SOPS
cat > .sops.yaml <<SOPS
creation_rules:
  - path_regex: \.claude/\.claude\.json\.enc$
    age: <YOUR_AGE_PUBLIC_KEY>
SOPS

# 4. Encrypt secrets
sops --encrypt .claude/.claude.json > .claude/.claude.json.enc
git add .claude/.claude.json.enc
echo ".claude/.claude.json" >> .gitignore
```

**Decrypt on deploy**:

```bash
# Автоматически в sync_claude_config_in()
sops --decrypt .claude/.claude.json.enc > ~/.claude.json
```

## Reconciliation Loop

**Автоматическая синхронизация Git → Runtime**:

```bash
# Запускается как background service
gitops_reconcile_loop() {
  while true; do
    # Pull latest from Git
    git pull origin main --quiet

    # Detect changes
    if config_changed_since_last_run; then
      # Decrypt secrets
      decrypt_secrets

      # Validate
      validate_claude_config || continue

      # Apply
      sync_claude_config_in

      # Verify
      smoke_test || rollback_config
    fi

    sleep 60  # Check every minute
  done
}
```

---

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)
