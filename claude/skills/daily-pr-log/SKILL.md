---
name: daily-pr-log
description: Use when the user says "add to the PR log", "log this PR", or provides a PR URL to record. Appends the URL to the daily PR log file in the knowledge base.
---

# Daily PR Log

## Overview

Appends one or more PR URLs to the daily log file in `~/projects/knowledge-base`. Files are organized by year and month. The directory structure is scaffolded automatically if it doesn't exist yet.

## Log Location

```
~/projects/knowledge-base/docs/git/daily-prs/YYYY/MM/YYYYMMDD_git_prs.md
```

Example for 2026-05-15:
```
docs/git/daily-prs/2026/05/20260515_git_prs.md
```

## Steps

1. **Resolve today's date** — get `YYYY`, `MM`, `YYYYMMDD` from the current date
2. **Scaffold the directory** — create `docs/git/daily-prs/YYYY/MM/` if it does not exist
3. **Create the file** if it does not exist, with this header:
   ```markdown
   # Daily PRs — YYYY-MM-DD
   ```
4. **Append** each PR URL on its own line — never overwrite existing content
5. **Commit and push** to `knowledge-base` main:
   ```
   docs: log PR(s) for YYYY-MM-DD
   ```

## File Format

```markdown
# Daily PRs — 2026-05-15

https://github.com/<your-github-username>/<repo>/pull/5
https://github.com/<your-github-username>/<repo>/pull/12
```

## Rules

- One URL per line, no labels or extra formatting
- Never overwrite or edit existing entries
- Always append — even if the PR was already logged (duplicates are better than data loss; the user can clean up)
- Always commit and push after appending

## Do NOT log these PRs

**Never append a PR to the log if that PR's only changes are inside `docs/git/daily-prs/`.** That directory IS the log — logging a commit to the log creates an infinite loop.

This applies even if the user says "add this PR" and hands you a URL. Check what the PR touches. If it's only `docs/git/daily-prs/`, stop and tell the user: "That PR is a log commit itself — skipping to avoid a loop."
