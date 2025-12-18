#!/bin/bash
# tests/phase1-foundation-tests.sh

set -euo pipefail

source lib/backup.sh
source lib/validation.sh
source lib/error_handling.sh

echo "🧪 Phase 1: Foundation & Safety Tests"

# Test 1: Backup creation
echo "Test 1: Backup creation..."
backup_dir=$(backup_claude_data)
[[ -d "$backup_dir" ]] || {
  echo "❌ FAIL: Backup directory not created"
  exit 1
}
echo "✅ PASS"

# Test 2: Backup verification
echo "Test 2: Backup verification..."
verify_backup "$backup_dir" || {
  echo "❌ FAIL: Backup verification failed"
  exit 1
}
echo "✅ PASS"

# Test 3: Config validation
echo "Test 3: Config validation..."
validate_claude_config "$@" || {
  echo "❌ FAIL: Config validation failed"
  exit 1
}
echo "✅ PASS"

# Test 4: Docker environment
echo "Test 4: Docker environment..."
validate_docker_environment || {
  echo "❌ FAIL: Docker environment validation failed"
  exit 1
}
echo "✅ PASS"

# Test 5: Error logging
echo "Test 5: Error logging..."
log_error "Test error message" "test_context"
[[ -f "$ERROR_LOG" ]] || {
  echo "❌ FAIL: Error log not created"
  exit 1
}
echo "✅ PASS"

echo ""
echo "✅ All Phase 1 tests passed!"
echo "Ready to proceed to Phase 2"
