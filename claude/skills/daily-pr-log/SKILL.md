---
name: daily-pr-log
description: Use when the user says "add to the PR log", "log this PR", or provides a PR URL to record. Appends the URL to the daily PR log file in the knowledge base.
version: 1.0.2
---

# Daily PR Log

> **This copy is read-only.**
> Skills are vendored into a project as copies, and this may be one.
> Edit this skill upstream, bump its version, then re-pull it - never edit the copy where it landed.
> Upstream is https://raw.githubusercontent.com/jkkelley/dotfiles/refs/heads/main/claude/skills/daily-pr-log/SKILL.md, and `skill-update.sh` pulls it from there - no dotfiles checkout is needed on this machine.
> `skill-update.sh` replaces the skill's directory rather than merging into it, so a local edit is destroyed by the next update with no conflict and no warning.
> The registry's content hash cannot catch it either, because a project's copy legitimately differs from upstream.

## Overview

Appends one or more PR URLs to the daily log file in `~/projects/knowledge-base`. Files are plain `.txt`, organized by year and month. Directory structure is scaffolded automatically.

## Log Location

```
~/projects/knowledge-base/docs/git/daily-prs/YYYY/MM/YYYYMMDD_git_prs.txt
```

Example for 2026-05-15:
```
docs/git/daily-prs/2026/05/20260515_git_prs.txt
```

## File Format

```
Daily PRs — YYYY-MM-DD

PR Counter for today: N

https://github.com/<your-github-username>/<repo>/pull/5
https://github.com/<your-github-username>/<repo>/pull/12
```

## Steps

1. **Resolve today's date** — run `date +%Y-%m-%d` via Bash to get the actual current date. Never rely on the session date from context or memory — late-night sessions cross midnight and context dates go stale. Extract `YYYY`, `MM`, `YYYYMMDD` from the command output.
2. **Scaffold the directory** — create `docs/git/daily-prs/YYYY/MM/` if it does not exist
3. **Create the file** if it does not exist with this structure:
   ```
   Daily PRs — YYYY-MM-DD

   PR Counter for today: 0

   ```
4. **Append** the URL on a new line at the end of the file
5. **Increment the counter** — read the current `PR Counter for today: N` value, replace with `N+1`
6. **Commit and push** to `knowledge-base` main:
   ```
   docs: log PR(s) for YYYY-MM-DD
   ```

## Rules

- Files use `.txt` extension, not `.md`
- One bare URL per line, no blank lines between URLs, no formatting
- Never overwrite or edit existing URL entries
- Always update the counter when appending
- Always commit and push after appending

## Do NOT log these PRs

**Never append a PR to the log if that PR's only changes are inside `docs/git/daily-prs/`.** That directory IS the log — logging a commit to the log creates an infinite loop.

This applies even if the user says "add this PR" and hands you a URL. Check what the PR touches. If it's only `docs/git/daily-prs/`, stop and tell the user: "That PR is a log commit itself — skipping to avoid a loop."
