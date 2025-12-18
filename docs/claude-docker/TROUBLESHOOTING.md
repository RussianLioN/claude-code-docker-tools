# Troubleshooting Guide

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)

---

## Частые Проблемы

### 1. "Container not cleaned up"

```bash
# Диагностика
docker ps -a -f name=claude-session

# Решение
docker rm -f $(docker ps -a -q -f name=claude-session)

# Проверка --rm flag
grep "docker run" ai-assistant.zsh | grep -q -- "--rm" || echo "Missing --rm flag!"
```

### 2. "OAuth authentication failed"

```bash
# macOS: Проверить Keychain
security find-generic-password -s "claude.ai" -a "$USER" -w

# Проверить ~/.claude.json
jq -e '.claudeAiOauth.accessToken' ~/.claude.json || echo "Token missing"

# Re-extract from Keychain
extract_keychain_credentials
```

### 3. "Sync failed / data corruption"

```bash
# Проверить integrity
verify_sync_integrity "$HOME/.claude" "$CLAUDE_STATE_DIR"

# Restore from backup
disaster_recovery

# Проверить flock
lsof /tmp/claude-config-sync.lock
```

### 4. "Performance degradation"

```bash
# Проверить resource usage
docker stats $(docker ps -q -f name=claude-session)

# Проверить I/O
iostat -x 1 5

# Проверить backups size
du -sh ~/.claude-backups/*

# Cleanup old backups
find ~/.claude-backups -mtime +30 -exec rm -rf {} \;
```

### 5. "MCP servers not working"

```bash
# Проверить paths
jq '.mcp.servers' ~/.claude.json

# Re-run path rewriting
fix_mcp_paths

# Test MCP server manually
npx -y @modelcontextprotocol/server-filesystem /workspace
```

## Debug Mode

```bash
# Enable verbose logging
export CLAUDE_DOCKER_DEBUG=true

# Run with trace
set -x
claude --help
set +x

# Check all logs
tail -100 ~/.claude-docker-events.jsonl
tail -100 ~/.claude-docker-errors.log
tail -100 ~/.claude-docker-sync.log
```

---

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)
