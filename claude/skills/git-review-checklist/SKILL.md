---
name: git-review-checklist
description: Git code review checklist, commit hygiene standards, and branching strategy reference. Preloaded into the git-code-reviewer agent.
---

# Git Review Checklist

## Pre-Review Scan (run first)

```bash
# Scan for accidentally committed secrets
git log -p origin/main..HEAD | grep -iE '(password|secret|api_key|token|sk-|ghp_|AKIA)\s*[=:]\s*\S+'

# All files changed
git diff --name-status origin/main...HEAD

# Commit count and messages
git log origin/main..HEAD --oneline

# Check for conflict markers left in
git grep -n '<<<<<<< \|======= \|>>>>>>> ' -- ':!*.md'

# File permission changes
git diff --summary origin/main...HEAD | grep 'mode change'
```

## Commit Quality Checklist

- [ ] Each commit is atomic — one logical change, passes tests independently
- [ ] Commit messages follow project convention (Conventional Commits or house standard)
- [ ] No `WIP`, `fixup`, `asdf`, `temp`, `test123` messages in final branch
- [ ] No merge commits on feature branch (should be rebased)
- [ ] No accidentally staged files (`.env`, `*.log`, `node_modules/`, build artifacts)
- [ ] No binary files unless intentional (images, certs)
- [ ] Short SHA referenced in PR body if fixing a regression

## Conventional Commits Reference

```
feat(auth): add OAuth2 PKCE support          ← new feature
fix(api): handle null user in session check  ← bug fix
refactor(db): extract connection pool logic  ← no behavior change
perf(cache): replace LRU with ARC algorithm ← performance
test(auth): add coverage for token expiry   ← tests only
docs(api): update rate limit documentation  ← docs only
chore(deps): bump axios from 1.6 to 1.7     ← maintenance
ci(github): add matrix build for Node 20    ← CI config
feat!: drop support for Node 16             ← BREAKING CHANGE
```

Footer for breaking changes:
```
BREAKING CHANGE: The `config.timeout` field is now in milliseconds, not seconds.
```

## Diff Review Checklist

**Correctness**
- [ ] Edge cases handled: empty, null/nil, zero, negative, max values
- [ ] Off-by-one in loops/slices
- [ ] Error paths handled, not just happy path
- [ ] Concurrent access safe (race conditions, TOCTOU)

**Security**
- [ ] No hardcoded secrets, tokens, keys, passwords
- [ ] No user input in SQL/shell/template without sanitization
- [ ] Auth/authz checked before sensitive operations
- [ ] No sensitive data in log statements

**Quality**
- [ ] No commented-out dead code
- [ ] No debug statements left in (`console.log`, `print`, `debugger`, `fmt.Println`)
- [ ] No magic numbers — named constants used
- [ ] Variable/function names are clear and accurate

**Tests**
- [ ] New behavior has test coverage
- [ ] Tests test behavior, not implementation
- [ ] Failure cases tested, not just success

## Review Output Template

```
## Summary
[1-2 sentence overall assessment]

### 🚨 Blocking
[Must fix before merge — correctness, security, data loss risk]

### ⚠️ Should Fix
[Important issues that don't block but should be addressed]

### 💡 Suggestions
[Non-blocking improvements, alternatives to consider]

### 🔍 Nits
[Style, typos, minor cleanup — low priority]

### ❓ Questions
[Clarifications needed before approving]
```

## Branching Strategy Quick Reference

| Model | When to use | Key rules |
|-------|-------------|-----------|
| **Trunk-based** | High-velocity, mature CI/CD | All to `main`, feature flags for WIP |
| **GitHub Flow** | SaaS, continuous deploy | `main` always deployable, short branches |
| **GitFlow** | Scheduled releases, versioned libs | `develop`, `release/*`, `hotfix/*` |

**Branch naming convention:**
```
feature/TICKET-123-short-description
fix/TICKET-456-null-user-crash
hotfix/TICKET-789-payment-timeout
chore/upgrade-node-20
```

## Common Blockers to Always Flag

- Secrets/credentials in any file
- Force push to protected branch
- `rm -rf` with variables in shell scripts
- SQL string concatenation with user input
- `eval()` with external input
- Breaking changes without version bump
- Merge without CI passing
