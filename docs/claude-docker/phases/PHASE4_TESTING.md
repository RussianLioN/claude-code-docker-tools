# Phase 4: Testing & Validation (Дни 15-21)

**📍 Navigation**: [← Back to Plan v3.0](../../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)

---

## 🎯 Цель Фазы

Comprehensive testing для **production confidence**:
- Enhanced E2E test suite (20+ tests)
- Performance benchmarks
- Load testing (50+ parallel sessions)
- Chaos engineering
- Final validation

---

## 4.1 Comprehensive E2E Tests

**Файл**: `tests/comprehensive-e2e-tests.sh`

**Test Suite** (20+ tests):

### Basic Functionality (7 tests)
1. **Authentication** - OAuth working
2. **Config sync** - Bidirectional sync works
3. **Container cleanup** - Ephemeral containers (--rm)
4. **Multi-session** - 10+ parallel sessions
5. **Resource limits** - Memory/CPU/PID enforced
6. **Health checks** - Monitoring working
7. **Error handling** - Graceful failures

### Data Safety (5 tests)
8. **Crash recovery** - Data persists after kill
9. **Concurrent writes** - No corruption
10. **Backup integrity** - 3-2-1 strategy works
11. **Sync verification** - Checksums match
12. **Rollback capability** - Can restore

### Performance (3 tests)
13. **Startup time** - < 3s
14. **Latency P95** - < 5s
15. **Throughput** - 10 req/s sustained

### Integration (3 tests)
16. **MCP server paths** - Rewriting works
17. **Keychain extraction** - macOS integration
18. **GitOps reconciliation** - Config sync from Git

### Chaos Engineering (2 tests)
19. **Network failure** - Graceful degradation
20. **Disk full** - Error handling

**Test Implementation Example**:
```bash
#!/bin/bash
# tests/comprehensive-e2e-tests.sh

set -euo pipefail

echo "🧪 Comprehensive E2E Tests (20+ tests)"

# Test 1: Authentication
echo "Test 1: Authentication..."
claude --version >/dev/null 2>&1 || {
  echo "❌ FAIL: Authentication failed"
  exit 1
}
echo "✅ PASS"

# Test 8: Crash recovery
echo "Test 8: Crash recovery..."
echo "test-data-$$" > ~/.claude/crash-test.txt
# Kill container mid-operation
docker ps -q -f name=claude-session | head -1 | xargs -r docker kill
sleep 2
# Verify data persists
[[ -f ~/.claude/crash-test.txt ]] || {
  echo "❌ FAIL: Data lost after crash"
  exit 1
}
rm ~/.claude/crash-test.txt
echo "✅ PASS"

# ... 18 more tests ...

echo ""
echo "✅ All 20 E2E tests passed!"
```

---

## 4.2 Performance Benchmarks

**Файл**: `tests/performance-benchmarks.sh`

### Startup Performance
- **Cold start**: < 3s
- **Warm start** (config cached): < 1s
- **Container spawn**: < 2s

### Runtime Performance
- **Sync IN**: < 500ms
- **Sync OUT**: < 500ms
- **Claude command latency**: < 2s (P50), < 5s (P95)

### Resource Usage
- **Memory per container**: < 512MB
- **CPU usage**: < 10% idle, < 50% active
- **Disk I/O**: < 10MB/s

### Scalability
- **Max concurrent sessions**: 20+
- **Session startup rate**: 5/second
- **Total system memory**: < 8GB for 10 sessions

**Benchmark Implementation**:
```bash
#!/bin/bash
# tests/performance-benchmarks.sh

set -euo pipefail

echo "📊 Performance Benchmarks"

# Benchmark 1: Cold start
echo "Benchmark 1: Cold start latency..."
start_time=$(date +%s%3N)
claude --version >/dev/null 2>&1
end_time=$(date +%s%3N)
duration=$((end_time - start_time))

if (( duration > 3000 )); then
  echo "❌ FAIL: Cold start took ${duration}ms (> 3000ms)"
  exit 1
fi
echo "✅ PASS: ${duration}ms"

# Benchmark 2: P95 latency
echo "Benchmark 2: P95 latency..."
latencies=()
for i in {1..100}; do
  start=$(date +%s%3N)
  claude --help >/dev/null 2>&1
  end=$(date +%s%3N)
  latencies+=($((end - start)))
done

# Calculate P95
p95=$(printf '%s\n' "${latencies[@]}" | sort -n | awk 'BEGIN{c=0}{a[c]=$0;c++}END{print a[int(c*0.95)]}')

if (( p95 > 5000 )); then
  echo "❌ FAIL: P95 latency ${p95}ms (> 5000ms)"
  exit 1
fi
echo "✅ PASS: ${p95}ms"

# ... more benchmarks ...

echo ""
echo "✅ All benchmarks passed!"
```

---

## 4.3 Load Testing

**Файл**: `tests/load-testing.sh`

### Load Scenarios

#### Scenario 1: Burst load
- 20 simultaneous `claude --help` calls
- **Verify**: No failures, all containers cleaned

#### Scenario 2: Sustained load
- 100 sequential invocations over 10 minutes
- **Verify**: Consistent performance, no memory leaks

#### Scenario 3: Stress test
- 50 parallel long-running sessions
- **Verify**: Resource limits enforced, no OOM

#### Scenario 4: Chaos test
- Random container kills during execution
- **Verify**: Data persists, auto-recovery works

**Load Test Implementation**:
```bash
#!/bin/bash
# tests/load-testing.sh

set -euo pipefail

echo "⚡ Load Testing"

# Scenario 1: Burst load
echo "Scenario 1: Burst load (20 parallel)..."
for i in {1..20}; do
  claude --help >/dev/null 2>&1 &
done
wait

# Check for failures
failures=$(grep -c "ERROR" ~/.claude-docker-errors.log 2>/dev/null || echo 0)
if (( failures > 0 )); then
  echo "❌ FAIL: $failures errors during burst"
  exit 1
fi

# Check container cleanup
sleep 3
orphaned=$(docker ps -a -f name=claude-session -q | wc -l)
if (( orphaned > 0 )); then
  echo "❌ FAIL: $orphaned containers not cleaned"
  exit 1
fi
echo "✅ PASS"

# Scenario 3: Stress test
echo "Scenario 3: Stress test (50 parallel long-running)..."
for i in {1..50}; do
  (sleep 30 && claude --version) >/dev/null 2>&1 &
done

# Monitor resource usage
max_memory=0
for i in {1..30}; do
  memory=$(docker stats --no-stream --format "{{.MemUsage}}" 2>/dev/null | awk '{sum+=$1} END{print sum}')
  (( memory > max_memory )) && max_memory=$memory
  sleep 1
done

# Wait for completion
wait

# Verify no OOM
if (( max_memory > 8000 )); then  # 8GB
  echo "❌ FAIL: Memory usage ${max_memory}MB exceeded limit"
  exit 1
fi
echo "✅ PASS: Peak memory ${max_memory}MB"

echo ""
echo "✅ All load tests passed!"
```

---

## 4.4 Pre-Production Checklist

**Критичные проверки перед production**:

### Security
- [ ] Secrets encrypted (SOPS/age)
- [ ] ~/.claude.json permissions (600)
- [ ] No credentials in Git
- [ ] Resource limits configured

### Reliability
- [ ] 3-2-1 backups configured
- [ ] DR tested successfully
- [ ] Rollback tested successfully
- [ ] Health checks passing

### Observability
- [ ] Logging enabled
- [ ] Metrics collection working
- [ ] Alerts configured
- [ ] Dashboard accessible

### Performance
- [ ] All benchmarks passing
- [ ] Load tests successful
- [ ] No resource leaks
- [ ] SLOs defined

### GitOps
- [ ] Config in Git
- [ ] Drift detection enabled
- [ ] Reconciliation loop tested
- [ ] Audit trail working

**Verification Script**:
```bash
#!/bin/bash
# Verify production readiness

echo "🔍 Production Readiness Check"

# Run all test suites
./tests/phase1-foundation-tests.sh
./tests/phase2-core-tests.sh
./tests/comprehensive-e2e-tests.sh
./tests/performance-benchmarks.sh
./tests/load-testing.sh

# Smoke tests
claude --version
claude --help

# Verify observability
tail -10 ~/.claude-docker-events.jsonl
tail -10 ~/.claude-docker-metrics.jsonl

# Verify backup
ls -lh ~/.claude-backups/latest/

# Verify GitOps (if enabled)
git status
git log -1 .claude/

# Final validation
validate_claude_config
validate_docker_environment

# DR test
disaster_recovery --dry-run

echo ""
echo "✅ Production readiness verified!"
```

---

## 📋 Phase 4 Checklist

- [ ] Создать `tests/comprehensive-e2e-tests.sh` (20+ tests)
- [ ] Создать `tests/performance-benchmarks.sh`
- [ ] Создать `tests/load-testing.sh`
- [ ] Запустить все тесты
- [ ] Убедиться что все проходят
- [ ] Проверить Pre-Production Checklist
- [ ] Документировать результаты тестирования
- [ ] Коммит: `git commit -m "feat(phase4): comprehensive testing & validation"`

---

**🎉 Completion**: После Phase 4 система готова к production deployment!

**📍 Navigation**: [← Back to Plan v3.0](../../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)
