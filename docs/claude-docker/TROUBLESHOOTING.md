# Troubleshooting Guide

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)

---

## Частые Проблемы

### 1. "Container not cleaned up"

**Симптомы**: Контейнеры остаются после выхода

**Диагностика**:
```bash
# Проверить оставшиеся контейнеры
docker ps -a -f name=claude-session
```

**Решение**:
```bash
# Очистить orphaned контейнеры
docker rm -f $(docker ps -a -q -f name=claude-session)

# Проверить наличие --rm flag
grep "docker run" ai-assistant.zsh | grep -q -- "--rm" || echo "Missing --rm flag!"
```

**Причина**: Отсутствует `--rm` flag в docker run команде

**Профилактика**: Убедиться что `docker run --rm` используется

---

### 2. "OAuth authentication failed"

**Симптомы**:
- "Authentication failed" при запуске
- "No valid credentials" ошибка

**Диагностика**:
```bash
# macOS: Проверить Keychain
security find-generic-password -s "claude.ai" -a "$USER" -w

# Проверить ~/.claude.json
jq -e '.claudeAiOauth.accessToken' ~/.claude.json || echo "Token missing"

# Проверить permissions
ls -la ~/.claude.json
```

**Решение**:
```bash
# Re-extract from Keychain
extract_keychain_credentials

# Или вручную создать ~/.claude.json
cat > ~/.claude.json <<JSON
{
  "claudeAiOauth": {
    "accessToken": "YOUR_ACCESS_TOKEN",
    "refreshToken": "YOUR_REFRESH_TOKEN",
    "expiresAt": $(date -v+7d +%s)000
  }
}
JSON
chmod 600 ~/.claude.json
```

**Причина**: Keychain credentials не извлечены или ~/.claude.json отсутствует

**Профилактика**: Запускать `extract_keychain_credentials()` при каждом старте

---

### 3. "Sync failed / data corruption"

**Симптомы**:
- "Sync integrity verification failed"
- Файлы отсутствуют после sync
- Checksum mismatch ошибки

**Диагностика**:
```bash
# Проверить integrity
verify_sync_integrity "$HOME/.claude" "$CLAUDE_STATE_DIR"

# Проверить locks
lsof /tmp/claude-config-sync.lock

# Проверить последний backup
cat /tmp/claude-last-backup
ls -lh $(cat /tmp/claude-last-backup)
```

**Решение**:
```bash
# Restore from backup
disaster_recovery

# Или конкретный backup
restore_from_backup "$HOME/.claude-backups/20250118-143000"

# Проверить flock работает
which flock || brew install util-linux
```

**Причина**:
- Concurrent writes без locking
- rsync interrupted
- Disk full

**Профилактика**:
- `pre_sync_backup()` перед каждым sync
- Проверка disk space
- flock locking

---

### 4. "Performance degradation"

**Симптомы**:
- Slow startup (> 5s)
- High latency (> 10s P95)
- CPU/Memory spikes

**Диагностика**:
```bash
# Проверить resource usage
docker stats $(docker ps -q -f name=claude-session)

# Проверить I/O
iostat -x 1 5

# Проверить backups size
du -sh ~/.claude-backups/*

# Проверить logs size
du -sh ~/.claude-docker-*.log ~/.claude-docker-*.jsonl
```

**Решение**:
```bash
# Cleanup old backups
find ~/.claude-backups -mtime +30 -exec rm -rf {} \;

# Rotate logs
mv ~/.claude-docker-events.jsonl ~/.claude-docker-events.jsonl.old
mv ~/.claude-docker-metrics.jsonl ~/.claude-docker-metrics.jsonl.old

# Проверить resource limits
grep -A5 "resource_limits=" ai-assistant.zsh

# Increase limits if needed
# --memory="4g" --cpus="4.0"
```

**Причина**:
- Too many backups
- Large logs not rotated
- Insufficient resource limits

**Профилактика**:
- Retention policy (30 дней)
- Log rotation
- Monitoring disk usage

---

### 5. "MCP servers not working"

**Симптомы**:
- MCP servers не видны в контейнере
- "Cannot find module" ошибки
- Path errors в MCP config

**Диагностика**:
```bash
# Проверить paths в ~/.claude.json
jq '.mcp.servers' ~/.claude.json

# Проверить path rewriting работает
grep "fix_mcp_paths" lib/sync.sh
```

**Решение**:
```bash
# Re-run path rewriting
source lib/sync.sh
fix_mcp_paths

# Test MCP server manually
npx -y @modelcontextprotocol/server-filesystem /workspace

# Проверить volume mounts
docker inspect $(docker ps -q -f name=claude-session) | jq '.[].Mounts'
```

**Причина**:
- Host paths в config (не rewritten)
- MCP server не установлен
- Volume mount issues

**Профилактика**: `fix_mcp_paths()` автоматически вызывается в `sync_claude_config_in()`

---

### 6. "Disk full / No space left"

**Симптомы**:
- "No space left on device"
- Sync fails
- Container cannot start

**Диагностика**:
```bash
# Проверить disk usage
df -h ~
du -sh ~/.claude-backups
du -sh ~/.docker-ai-config
du -sh ~/Library/Containers/com.docker.docker
```

**Решение**:
```bash
# Cleanup old backups
find ~/.claude-backups -mtime +7 -exec rm -rf {} \;

# Cleanup Docker
docker system prune -af --volumes

# Rotate logs
rm ~/.claude-docker-*.log.old
rm ~/.claude-docker-*.jsonl.old

# Cleanup staging
rm -rf ~/.docker-ai-config/global_state/claude_config.old
```

**Причина**:
- Backups не очищаются
- Docker images накапливаются
- Logs растут

**Профилактика**:
- Retention policy
- Automated cleanup
- Disk usage monitoring

---

## Debug Mode

**Enable verbose logging**:
```bash
# Set debug flag
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

**Structured logging queries**:
```bash
# Filter errors
jq 'select(.level == "ERROR")' ~/.claude-docker-events.jsonl

# Last 10 operations
jq -r '.event' ~/.claude-docker-events.jsonl | tail -10

# Calculate P95 latency
jq -s 'map(select(.metric == "claude.invocation.duration")) |
       sort_by(.value) | .[length * 0.95 | floor].value' \
  ~/.claude-docker-metrics.jsonl
```

---

## Health Checks

**Verify system health**:
```bash
# 1. Docker running
docker info >/dev/null 2>&1 || echo "Docker not running"

# 2. Config valid
validate_claude_config

# 3. Backups exist
ls -lh ~/.claude-backups/latest/

# 4. No orphaned containers
docker ps -a -f name=claude-session

# 5. Disk space
df -h ~ | awk 'NR==2 && $5 > "80%" {print "Disk usage critical: " $5}'

# 6. Logs readable
tail -1 ~/.claude-docker-events.jsonl | jq empty

# 7. OAuth valid
jq -e '.claudeAiOauth.accessToken' ~/.claude.json >/dev/null
```

---

## Emergency Recovery

**Complete system recovery**:
```bash
# 1. Stop all containers
docker ps -q -f name=claude-session | xargs -r docker kill

# 2. Restore from backup
disaster_recovery

# 3. Verify restoration
validate_claude_config
claude --version

# 4. Check logs
tail -20 ~/.claude-docker-events.jsonl
```

**Nuclear option** (complete reinstall):
```bash
# 1. Backup current state
tar -czf ~/claude-emergency-backup-$(date +%s).tar.gz \
  ~/.claude ~/.claude.json ~/.docker-ai-config

# 2. Clean everything
rm -rf ~/.claude ~/.claude.json ~/.docker-ai-config
rm -rf ~/.claude-docker-*

# 3. Restore from cloud backup (if available)
rclone copy remote:claude-backups/latest.tar.gz ~/
tar -xzf ~/latest.tar.gz -C ~/

# 4. Re-run setup
./install.sh
```

---

## Getting Help

**Collect diagnostic information**:
```bash
# Create support bundle
mkdir -p ~/claude-support-bundle
cp ~/.claude-docker-errors.log ~/claude-support-bundle/
cp ~/.claude-docker-events.jsonl ~/claude-support-bundle/
docker ps -a > ~/claude-support-bundle/containers.txt
docker images > ~/claude-support-bundle/images.txt
df -h > ~/claude-support-bundle/disk.txt
tar -czf ~/claude-support-bundle.tar.gz ~/claude-support-bundle/
echo "Send claude-support-bundle.tar.gz for analysis"
```

---

**📍 Navigation**: [← Back to Plan v3.0](../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)
