# Operator Skill — Sessions & Help Design
**Date:** 2026-06-05

## Summary

Two new intents added to the operator skill: `sessions` (log Claude sessions for the day) and `help` (display a reference card of all operator capabilities). A new `references/help-card.md` file becomes the single source of truth for the help card, written to both the skill directory and `$OPERATOR_REPO/HELP_README.md`. The operator `README.md` is updated as a one-time implementation step to document both the `claude-sessions/` directory structure and the `HELP_README.md`.

---

## Scope

### What this changes
- `claude/skills/operator/SKILL.md` — two new intents added (`sessions`, `help`); intent dispatch list updated; data layout tree updated; update convention documented
- `claude/skills/operator/references/help-card.md` — new file, source of truth for help content
- `$OPERATOR_REPO/README.md` — updated now (implementation step) to document claude-sessions and HELP_README.md
- `$OPERATOR_REPO/HELP_README.md` — created now (implementation step) from `references/help-card.md`

### What this does NOT change
- Existing intents a–j are untouched
- Data layout of `$OPERATOR_REPO` outside of new `claude-sessions/` directory tree
- Subagent behavior (operator-planner, operator-triage)

---

## Intent: sessions

### Trigger phrases
`"log my sessions"`, `"log a few sessions"`, `"operator capture claude sessions"`, `"I need to log my session"`, `"I need to log a few sessions"`

### File path structure
```
$OPERATOR_REPO/claude-sessions/
└── YYYY/
    └── MM/
        └── DD-claude-sessions.md
```

- `YYYY`, `MM`, `DD` derived from current system date at time of invocation
- Operator creates `claude-sessions/` if missing, then `YYYY/` if missing, then `MM/` if missing, before writing

### Append vs create logic
```bash
TODAY=$(date +%Y/%m/%d)
FILE="$OPERATOR_REPO/claude-sessions/$TODAY-claude-sessions.md" # resolved: YYYY/MM/DD-claude-sessions.md
```
- If file exists → append new rows to the existing table
- If file does not exist → create file with header + table header + rows

### File format
```markdown
# Claude Sessions — YYYY-MM-DD

| Time Logged | Session Name | Directory |
|-------------|-------------|-----------|
| YYYYMMDD HH:MM:SS | <session name> | <directory> |
```

Time logged format: `date +"%Y%m%d %H:%M:%S"` — captured at the moment operator logs the entry, not when the session started.

### Input modes

**Interactive (one-at-a-time):**
```
Operator: How many sessions are we logging?
User: 2
Operator: Session 1 — name?
User: operator skill update - capture sessions/dirs
Operator: Session 1 — directory?
User: ~/dotfiles
Operator: Session 2 — name?
...
```

**Bulk (all at once):**
```
User: log sessions:
  - operator skill update @ ~/dotfiles
  - homelab cert-manager fix @ ~/homelab
```
Format: `<name> @ <directory>` per line, one session per line.
Parsing rule: split each line on the **last** `@` — everything before it is the session name, everything after is the directory. This handles `@` characters in session names cleanly.

### Behavior
1. Run pull-on-read: `git -C "$OPERATOR_REPO" pull --rebase` — warn but continue on failure
2. Determine input mode from prompt (interactive vs bulk)
3. Collect all session name + directory pairs
4. Capture timestamp: `date +"%Y%m%d %H:%M:%S"`
5. Resolve file path: `$OPERATOR_REPO/claude-sessions/$(date +%Y)/$(date +%m)/$(date +%d)-claude-sessions.md`
6. Create missing directories if needed: `mkdir -p "$(dirname "$FILE")"`
7. If file does not exist: write header + table header + rows; if file exists: append rows only
8. `git -C "$OPERATOR_REPO" add claude-sessions/`
9. `git -C "$OPERATOR_REPO" commit -m "sessions: YYYY-MM-DD — N session(s) logged"`
10. `git -C "$OPERATOR_REPO" push` — on failure: commit stands locally, tell the user: *"Logged locally but push failed. Run `git -C $OPERATOR_REPO push` to retry."*
11. Print: `"Logged N session(s) to claude-sessions/YYYY/MM/DD-claude-sessions.md and pushed to remote."`
12. New line: `"Happy Claud'ing"`

---

## Intent: help

### Trigger phrases
`"hey operator, help"`, `"what can you do"`, `"operator commands"`, `"what are your intents"`

### Behavior
1. Read `references/help-card.md` from this skill's directory
2. Print the full contents to chat
3. If `$OPERATOR_REPO/HELP_README.md` does not exist: write it from `references/help-card.md`, commit + push silently
4. No other git changes — read-only intent

---

## references/help-card.md — Content

```markdown
# Operator — Help

## Intents

| Intent | What it does | Example |
|--------|-------------|---------|
| capture | Drop a thought to your inbox — no action taken, just saved | `"hey operator, work: idea — try LangGraph"` |
| plan | Ask what you should work on right now | `"hey operator, what should I work on"` |
| status | See project status across all domains or one project | `"hey operator, status on migration-X"` |
| new-project | Create a new project card under a domain | `"hey operator, work: new project — migration-X"` |
| close | Mark a project done, paused, blocked, or abandoned | `"hey operator, migration-X is done"` |
| new-domain | Create a new life domain (work, personal, etc.) | `"hey operator, new domain: consulting"` |
| north-star | Edit or walk through a domain's north-star | `"hey operator, work north-star: add constraint X"` |
| agenda | Show the last planned agenda for today | `"hey operator, agenda"` |
| triage | Work through inbox items one by one | `"hey operator, let's triage"` |
| backlog | Log a bug or task to a project's backlog | `"hey operator, yieldpoint-ai: backlog — timeout flicker"` |
| sessions | Log one or more Claude sessions for the day | `"hey operator, log my sessions"` |
| help | Show this reference card | `"hey operator, help"` |

## Intent Categories

| Category | What it captures |
|----------|-----------------|
| capture | Raw ideas, thoughts, and observations — unprocessed, inbox-only |
| plan / agenda | Work recommendations and scheduled priorities weighted by time-of-week |
| status | Snapshot of where projects stand — active, blocked, last touched |
| new-project / close | Lifecycle events — creating, pausing, finishing, or abandoning a project |
| new-domain / north-star | Domain setup and long-term direction — mission, goals, constraints |
| triage | Decisions on inbox items — trash, promote to project, append to existing |
| backlog | Bugs, tasks, and rough edges tied to a specific project |
| sessions | Claude session activity — when they ran, what they were, where they lived |
| help | Operator's own capabilities and usage reference |
```

---

## Skill Update Convention

When a new intent is added to the operator skill:

1. Update `references/help-card.md` with the new intent row (both Intents table and Categories table)
2. Update `SKILL.md` with the new intent behavior
3. Update the intent dispatch list in SKILL.md to include the new intent name
4. Write the updated `references/help-card.md` content to `$OPERATOR_REPO/HELP_README.md`
5. Commit + push the operator repo: `"help: add <intent-name> intent"`
6. Announce to the user:
   ```
   New capability added: <intent-name>
   <one-line description>
   Try it: "<example trigger phrase>"
   ```

---

## Data layout (updated)

```
$OPERATOR_REPO/
├── README.md
├── HELP_README.md
├── claude-sessions/
│   └── YYYY/
│       └── MM/
│           └── DD-claude-sessions.md
├── domains/
│   └── <domain>/
│       ├── north-star.md
│       ├── projects/
│       │   └── <slug>.md
│       └── archive/
├── inbox.md
└── agenda.md
```

---

## README.md update (operator repo) — implementation step

Update `$OPERATOR_REPO/README.md` now as part of this implementation. Add two sections:

**## Claude Sessions**
- Location: `claude-sessions/YYYY/MM/DD-claude-sessions.md`
- What it captures: session name, directory, timestamp logged
- Trigger: `"hey operator, log my sessions"`

**## Help**
- Location: `HELP_README.md` (full intent reference card)
- Auto-created on first `help` invocation; kept current when new intents are added
- Trigger: `"hey operator, help"`

Commit + push: `"docs: add claude-sessions and help sections to README"`

---

## Files changed

| File | Action | When |
|------|--------|------|
| `claude/skills/operator/SKILL.md` | Add sessions + help intents; update dispatch list + data layout tree + update convention | Implementation |
| `claude/skills/operator/references/help-card.md` | Create — source of truth for help card | Implementation |
| `$OPERATOR_REPO/README.md` | Add Claude Sessions and Help sections | Implementation |
| `$OPERATOR_REPO/HELP_README.md` | Create from help-card.md | Implementation |
