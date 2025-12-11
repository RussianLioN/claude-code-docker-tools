# GIT_WORKFLOWS.md

> **🔄 GitOps & Handoff Guide for AI-Assisted Development**
> *Complete reference for Git operations, branching strategies, and handoff procedures*

## 📑 Table of Contents

1. [⚡ Quick Git Commands](#-quick-git-commands) - Daily operations
2. [🌿 Branching Strategy](#-branching-strategy) - GitFlow adapted
3. [🤝 Commit Standards](#-commit-standards) - Message conventions
4. [📤 Handoff Procedures](#-handoff-procedures) - Session transitions
5. [🔄 PR & Review Process](#-pr--review-process) - Collaboration
6. [🚨 Emergency Procedures](#-emergency-procedures) - Rollback & fix
7. [🏷️ Tagging & Releases](#-tagging--releases) - Version control
8. [🔧 Git Configuration](#-git-configuration) - Setup & optimization

---

## ⚡ Quick Git Commands

### 🔄 Daily Operations

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `git status` | Check working directory | Before any operation |
| `git add .` | Stage all changes | After modifications |
| `git commit -m "msg"` | Create commit | After staging |
| `git push` | Send to remote | After commit |
| `git pull` | Update from remote | Before starting work |

### 📊 Status & Inspection

```bash
# Quick overview
git status                    # Working directory status
git log --oneline -5         # Last 5 commits
git branch -a                # All branches

# Detailed inspection
git diff                     # Unstaged changes
git diff --staged           # Staged changes
git log --graph --oneline   # Branch visualization
```

### 🚀 Fast Workflow

```bash
# Complete commit cycle
git add .
git commit -m "feat: description"
git push

# Quick sync with remote
git pull --rebase
git push
```

---

## 🌿 Branching Strategy

### 📋 Branch Types & Purpose

| Branch Type | Naming Convention | Purpose | Lifetime |
|-------------|------------------|---------|----------|
| **master** | `master` | Production-ready code | Permanent |
| **develop** | `develop` | Integration branch | Permanent |
| **feature** | `feature/description` | New features | Temporary |
| **hotfix** | `hotfix/issue-description` | Critical fixes | Temporary |
| **release** | `release/vX.X.X` | Release preparation | Temporary |

### 🔄 Branch Creation Workflow

```bash
# Create feature branch from develop
git checkout develop
git pull origin develop
git checkout -b feature/add-new-ai-mode

# Create hotfix from master
git checkout master
git pull origin master
git checkout -b hotfix/fix-security-issue

# Create release from develop
git checkout develop
git pull origin develop
git checkout -b release/v1.2.0
```

### 🎯 Branch Merging Strategy

```bash
# Feature → Develop (merge commit)
git checkout develop
git merge --no-ff feature/add-new-ai-mode
git push origin develop

# Release → Master (fast-forward)
git checkout master
git merge --ff-only release/v1.2.0
git tag v1.2.0
git push origin master --tags

# Hotfix → Master & Develop
git checkout master
git merge --no-ff hotfix/fix-security-issue
git checkout develop
git merge --no-ff hotfix/fix-security-issue
```

---

## 🤝 Commit Standards

### 📝 Conventional Commit Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### 🏷️ Commit Types

| Type | Purpose | Examples |
|------|---------|----------|
| `feat` | New feature | `feat(ai): add claude mode support` |
| `fix` | Bug fix | `fix(docker): resolve volume mount issue` |
| `docs` | Documentation | `docs(readme): update installation guide` |
| `style` | Formatting | `style(zsh): improve code formatting` |
| `refactor` | Refactoring | `refactor(config): simplify state sync` |
| `test` | Tests | `test(ci): add integration tests` |
| `chore` | Maintenance | `chore(deps): update dependencies` |
| `perf` | Performance | `perf(docker): optimize build time` |

### ✅ Commit Message Examples

```bash
# Good commits
feat(ai): add dual-mode switching functionality
fix(ssh): resolve agent forwarding in container
docs(api): update authentication documentation
refactor(sync): simplify state synchronization logic

# Bad commits (avoid)
"fixed stuff"
"update"
"tmp"
"wip"
```

### 🔍 Commit Quality Checklist

Before committing, verify:
- [ ] Commit message follows conventional format
- [ ] Type is appropriate for changes
- [ ] Description is clear and concise
- [ ] No sensitive data included
- [ ] Related issue referenced (if applicable)

---

## 📤 Handoff Procedures

### 🎯 When to Create Handoff

**Create handoff when**:
- Completing significant feature implementation
- Ending work session with incomplete changes
- Transitioning between AI modes (Gemini ↔ Claude)
- Handing off to human developer
- Creating save point for complex changes

### 📋 Handoff Template

```markdown
# Handoff Summary

## 📝 Context
**AI Mode**: [Gemini/Claude]
**Session Goal**: [Brief description]
**Time Spent**: [Duration]

## ✅ Completed
- [ ] Task 1 completed
- [ ] Feature 2 implemented
- [ ] Bug 3 fixed

## 🔄 In Progress
- [ ] Feature 4 - 80% complete
- [ ] Refactoring 5 - started

## 🚧 Blockers
- [ ] Issue with dependency X
- [ ] Waiting for API response

## 📋 Next Steps
1. Complete feature 4
2. Test integration
3. Update documentation

## 🏷️ Technical Details
- **Branch**: feature/feature-name
- **Last Commit**: abc1234
- **Files Modified**: file1.js, file2.py
- **Tests Status**: Passing/Failing
```

### 📤 Creating Handoff

```bash
# 1. Save current state
git add .
git commit -m "handoff: save session progress - $(date +%Y-%m-%d)"

# 2. Create handoff file
cat > HANDOFF.md << 'EOF'
# Handoff Summary
[Fill in template above]
EOF

git add HANDOFF.md
git commit -m "docs: add session handoff - $(date +%Y-%m-%d)"

# 3. Push for visibility
git push
```

### 📥 Resuming from Handoff

```bash
# 1. Pull latest changes
git pull

# 2. Read handoff
cat HANDOFF.md

# 3. Remove handoff when starting
git rm HANDOFF.md
git commit -m "chore: remove handoff - session resumed"
```

---

## 🔄 PR & Review Process

### 📋 Creating Pull Request

```bash
# 1. Push feature branch
git push origin feature/add-new-ai-mode

# 2. Create PR via GitHub CLI
gh pr create \
  --title "feat: add new AI mode support" \
  --body "## Description
Adds support for new AI mode with enhanced capabilities.

## Changes
- Implement new mode switching
- Add configuration options
- Update documentation

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed"

# 3. Request reviewers
gh pr edit --add-reviewer "username1,username2"
```

### ✅ PR Checklist

**Before creating PR**:
- [ ] Code follows project conventions
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Commit messages are clear
- [ ] No sensitive data committed

**PR Requirements**:
- [ ] Clear description of changes
- [ ] Testing instructions included
- [ ] Screenshots if UI changes
- [ ] Breaking changes highlighted

### 🔍 Review Process

```bash
# View PR details
gh pr view

# Checkout PR for local testing
gh pr checkout 123

# Request changes
gh pr review 123 --comment "Please add tests for new feature"

# Approve PR
gh pr review 123 --approve
```

---

## 🚨 Emergency Procedures

### 🔙 Rollback Procedures

```bash
# 1. Soft reset (keep changes)
git reset --soft HEAD~1

# 2. Hard reset (discard changes)
git reset --hard HEAD~1

# 3. Rollback to specific commit
git reset --hard abc1234

# 4. Emergency rollback to tag
git checkout v1.0.0
git checkout -b hotfix/emergency-fix
# Make fix...
git checkout master
git merge --no-ff hotfix/emergency-fix
git tag v1.0.1
```

### 🚨 Recovering from Bad State

```bash
# If you messed up working directory
git checkout -- file_name
git checkout -- .  # All files

# If you messed up staging area
git reset HEAD file_name
git reset HEAD      # All files

# If you committed to wrong branch
git checkout correct_branch
git cherry-pick abc1234
git checkout wrong_branch
git reset --hard HEAD~1

# If you pushed broken code
git revert abc1234
git push origin master
```

### 📞 Emergency Communication

```bash
# Create emergency branch
git checkout -b emergency/fix-production-issue
# Fix issue...
git add .
git commit -m "hotfix: critical production fix"
git push origin emergency/fix-production-issue

# Notify team (example)
# Slack: @channel Emergency fix deployed to branch emergency/fix-production-issue
# Please review immediately
```

---

## 🏷️ Tagging & Releases

### 📦 Creating Tags

```bash
# Lightweight tag
git tag v1.0.0

# Annotated tag with message
git tag -a v1.0.0 -m "Release version 1.0.0
- Add dual AI support
- Fix security issues
- Update documentation"

# Push tags
git push origin --tags

# Push specific tag
git push origin v1.0.0
```

### 🎯 Release Workflow

```bash
# 1. Prepare release branch
git checkout develop
git checkout -b release/v1.2.0

# 2. Finalize release
# Update version numbers, changelog, etc.
git add .
git commit -m "chore: prepare release v1.2.0"

# 3. Merge to master
git checkout master
git merge --no-ff release/v1.2.0
git tag v1.2.0

# 4. Merge back to develop
git checkout develop
git merge --no-ff release/v1.2.0

# 5. Push all
git push origin master develop --tags

# 6. Create GitHub release
gh release create v1.2.0 --title "Version 1.2.0" --notes "## Changes
- Add new features
- Fix bugs
- Update documentation"
```

---

## 🔧 Git Configuration

### ⚙️ Essential Settings

```bash
# User identity
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Default editor
git config --global core.editor "vim"

# Default branch name
git config --global init.defaultBranch main

# Push behavior
git config --global push.default simple

# Rebase behavior
git config --global pull.rebase true

# Credential helper (macOS)
git config --global credential.helper osxkeychain
```

### 🎨 Useful Aliases

```bash
# Status shortcuts
git config --global alias.st 'status'
git config --global alias.co 'checkout'
git config --global alias.br 'branch'
git config --global alias.cm 'commit -m'

# Log shortcuts
git config --global alias.lg 'log --graph --oneline --decorate --all'
git config --global alias.last 'log -1 HEAD'
git config --global alias.ls 'log --pretty=format:"%h %ad | %s%d [%an]" --graph --date=short'

# Diff shortcuts
git config --global alias.d 'diff'
git config --global alias.dc 'diff --cached'
git config --global alias.ds 'diff --staged'

# Undo shortcuts
git config --global alias.unstage 'reset HEAD --'
git config --global alias.lastcommit 'rev-parse HEAD'
git config --global alias.undo 'reset --soft HEAD~1'
```

### 🔄 Advanced Configuration

```bash
# Handle line endings
git config --global core.autocrlf input  # macOS/Linux
git config --global core.autocrlf true   # Windows

# Large file handling
git config --global core.preloadindex true
git config --global core.fscache true
git config --global gc.auto 256

# Merge tool configuration
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd 'code --wait $MERGED'
```

---

## 📚 Best Practices Summary

### ✅ Daily Habits
1. **Pull before work** - Always sync with remote
2. **Commit often** - Small, focused commits
3. **Push frequently** - Share progress regularly
4. **Review before push** - Check commit messages
5. **Clean workspace** - Commit or stash before switching

### 🚨 Things to Avoid
1. **Don't commit sensitive data**
2. **Don't force push to shared branches**
3. **Don't commit broken code to master**
4. **Don't ignore merge conflicts**
5. **Don't work on master directly**

### 🎯 Pro Tips
1. **Use pre-commit hooks** for validation
2. **Enable GPG signing** for security
3. **Configure automatic backup** of work
4. **Use issue tracking integration**
5. **Maintain clean commit history**

---

## 🏷️ Document Tags

```
Priority: HIGH
Type: WORKFLOW_GUIDE
Scope: GIT_OPERATIONS
Version: 1.0
Last Updated: 2025-12-11
Validated: ✅
Related: CLAUDE.md, AI_SYSTEM_INSTRUCTIONS.md
```

---

*This document should be updated when Git workflows evolve or new procedures are introduced.*