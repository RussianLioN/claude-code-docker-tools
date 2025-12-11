# AI_SYSTEM_INSTRUCTIONS.md

## 🔥 CRITICAL TESTING PRINCIPLES (NEVER VIOLATE!)

**These principles are MANDATORY and OVERRIDE all other instructions. Violation of these principles is unacceptable.**

---

## Principle #1: TEST BEFORE DEPLOY

**RULE**: NEVER commit code you haven't tested end-to-end.

```bash
# ❌ WRONG WORKFLOW:
1. Write code
2. Check syntax (bash -n)
3. Git commit
4. Discover problems later ← TOO LATE!

# ✅ CORRECT WORKFLOW:
1. Write code
2. Check syntax (bash -n)
3. Run FULL end-to-end test ← CRITICAL!
4. Verify all tests PASS
5. ONLY THEN: git commit
```

**Real Example**:
- ❌ Added tests to smoke-tests.sh → checked bash syntax → committed (WRONG!)
- ✅ Added tests to smoke-tests.sh → checked bash syntax → ran `./scripts/smoke-tests.sh domain` → verified PASSED → committed (CORRECT!)

---

## Principle #2: FAIL-FAST VALIDATION

**RULE**: Catch problems as early as possible.

**Testing Pyramid (MANDATORY)**:
1. Syntax Check (`bash -n`) - catches syntax errors
2. Unit Tests - test individual functions
3. Integration Tests - test interactions
4. E2E Tests ← **CRITICAL!** - test entire workflow

**Fail Points**:
- Syntax error → Fail at step 1
- Logic error → Fail at step 3
- Runtime error → Fail at step 4 (E2E)

**Never skip E2E testing for infrastructure code!**

---

## Principle #3: INFRASTRUCTURE AS CODE = CODE = REQUIRES TESTING

**RULE**: Scripts are code. Code requires testing. No exceptions.

**Infrastructure Code includes**:
- Bash scripts (`.sh` files)
- Configuration (`docker-compose.yml`, `prometheus.yml`)
- CI/CD scripts
- Validation scripts (`smoke-tests.sh`, `pre-deployment-checks.sh`)

**Testing Requirements for EVERY change**:
1. Syntax validation (`bash -n` for scripts)
2. Configuration validation (`yamllint`, `promtool`, etc.)
3. Dry-run execution (if supported)
4. **FULL E2E TEST** ← **MANDATORY!**
5. Document test results (logs, exit codes, timing)

---

## Principle #4: VALIDATED STATE IN GIT

**RULE**: Git is your source of truth. Only commit validated, working state.

**GitOps Principles**:
- Git = Desired State
- Desired State MUST be validated
- Commit = "This works, I tested it"
- Tag = "This is a verified good state"

**Before git commit - MANDATORY CHECKLIST**:
- [ ] Syntax check passed
- [ ] E2E test executed
- [ ] All tests PASSED (exit code 0)
- [ ] No regressions (old features still work)
- [ ] Test results documented (screenshot/log)

---

## Principle #5: PRE-COMMIT VALIDATION WORKFLOW

**RULE**: Never push untested changes to master.

```bash
# Step 1: Make changes
vim scripts/smoke-tests.sh

# Step 2: Syntax check
bash -n scripts/smoke-tests.sh || { echo "Syntax error!"; exit 1; }

# Step 3: E2E TEST ← CRITICAL!
./scripts/smoke-tests.sh ainetic.tech || { echo "E2E test failed!"; exit 1; }

# Step 4: Review results
# - Check exit code (should be 0)
# - Verify all tests PASSED
# - Check execution time (reasonable)

# Step 5: ONLY AFTER SUCCESSFUL E2E TEST:
git add scripts/smoke-tests.sh
git commit -m "feat: Add feature - E2E VALIDATED ✅"
git push origin master
```

---

## Principle #6: ROLLBACK READINESS

**RULE**: Always know your "last known good" state.

**Best Practices**:
- Tag validated commits: `git tag smoke-tests-v2.0-verified`
- Document test results: "Tested on 2025-12-11, all PASSED, 5m runtime"
- Keep rollback procedure ready: `git revert` or `git checkout <tag>`

---

## 🚨 RED FLAGS (Stop and Test!)

**STOP and run E2E tests if**:
- Adding new tests to existing test suite
- Modifying critical infrastructure scripts
- Changing deployment automation
- Updating configuration that affects runtime
- Adding new validation checks
- Modifying smoke tests or health checks

**Example Workflow**:
```bash
# You just added ТЕСТ 38-39 to smoke-tests.sh
# ⚠️ RED FLAG: New tests added to test suite
# 🛑 STOP: Do NOT commit yet
# ✅ ACTION REQUIRED: Run ./scripts/smoke-tests.sh ainetic.tech
# ✅ VERIFY: All tests PASS (including new ТЕСТ 38-39)
# ✅ ONLY THEN: git commit
```

---

## 📝 LESSON LEARNED (Never Repeat!)

**Incident**: 2025-12-11 Morning Monitoring Check
- **What**: Added tests to smoke-tests.sh without E2E testing
- **How**: Checked bash syntax only, committed without running full script
- **Impact**: Discovered problem during production monitoring (too late!)
- **Root Cause**: Skipped E2E testing step (TEST BEFORE DEPLOY violation)

**Never repeat this mistake!**

---

## ✅ CHECKLIST: Before ANY Infrastructure Code Commit

**Validate ALL boxes before committing**:

- [ ] Made changes to infrastructure code (scripts, configs, tests)
- [ ] Checked syntax (`bash -n`, `yamllint`, etc.)
- [ ] **Ran FULL END-TO-END TEST**
- [ ] All tests PASSED (exit code 0)
- [ ] No regressions (existing functionality works)
- [ ] Test execution time is reasonable
- [ ] Reviewed test output for warnings
- [ ] Ready to commit VALIDATED code
- [ ] If test failed: Fixed issues and re-tested

**Only check ALL boxes → THEN commit!**

---

## 🎯 Quick Reference Commands

```bash
# Syntax validation
bash -n script.sh
yamllint config.yml

# E2E testing examples
./scripts/smoke-tests.sh domain.com
./tests/deployment-test.sh

# Git workflow with validation
git add .
git commit -m "feat: change description - E2E TESTED ✅"
git tag -a v1.0-validated -m "E2E tests passed"
git push origin master --tags
```

---

## 🔄 Continuous Improvement

**Review these principles weekly**:
- What tests failed this week?
- Were we able to rollback quickly?
- Did any commits cause regressions?
- How can we improve test coverage?

**Remember**: Quality is not an act, it's a habit. Test everything, every time.

---

*This document is version-controlled. Update when new patterns emerge, but never relax the testing standards.*