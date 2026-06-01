---
name: plan-scaffold
description: Scaffold a new project workspace inside the claude-plans repo. Creates the full directory structure (CLAUDE.md, README, issues.md, sessions-table, CONTEXT_STATE stub, per-subproject dirs), updates the root README.md project tables, then asks whether to commit/push, sync to S3, or both. Optionally chains into project-kickoff. Use when the user says "plan-scaffold", "scaffold a new project", "set up a project workspace", or after brainstorming when ready to lay down the planning structure.
---

# plan-scaffold

Scaffold a new project workspace in the claude-plans repo. One question at a time.
Output is a complete directory tree ready for the first session.

## When This Applies

- User says "plan-scaffold", "scaffold a new project", "set up a project workspace"
- User invokes `/plan-scaffold`
- End of a brainstorming session when ready to lay down the planning structure

## Recommended Flow

```
brainstorming → plan-scaffold → (optional) project-kickoff
```

`plan-scaffold` is also fully standalone — it does not require prior brainstorming.

## Hard Rules

- **One question per message.** Never bundle questions.
- **No assumptions.** If an answer implies a follow-up, ask it next turn.
- **Don't scaffold until all questions are answered.**
- **Root claude-plans/ stays clean.** Only directories at root — no loose files beyond README.md, CLAUDE.md, .gitignore, .claudeignore.
- **No PII in this skill file.** Paths and usernames are resolved at runtime (see Step 0).

---

## Step 0 — Discover Runtime Context

Before asking anything, resolve these values silently by running shell commands.
Never hardcode them — they vary per machine and user.

```bash
# Local root of the claude-plans repo
PLANS_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/Documents/claude-plans")

# GitHub remote URL for the claude-plans repo
GITHUB_REMOTE=$(git -C "$PLANS_ROOT" remote get-url origin 2>/dev/null || echo "unknown")

# GitHub username (derived from remote or gh CLI)
GITHUB_USER=$(gh api user --jq .login 2>/dev/null || echo "unknown")
```

If `PLANS_ROOT` cannot be resolved (not inside the repo), tell the user:
> "Run this from inside the claude-plans repo, or cd there first: `cd ~/Documents/claude-plans`"
Then stop.

---

## Step 1 — Interview (one question per turn)

Ask these in order. Stop after each and wait for the answer.

1. **Project name** — becomes the directory name and slug (lowercase, hyphens). Example: `homelab-observability`
2. **One-line description** — what is this project doing or fixing?
3. **Subprojects / workstreams** — are there multiple independent tracks inside this project? (yes / no)
   - If yes: list them one per line. Each becomes a subdirectory with its own plan and sessions table.
   - If no: the project root IS the working directory; no subdirectories created.
4. **Repos involved** — list the GitHub repos this project will touch (e.g. `homelab-gitops`, `prospector-be`). One per line. "none yet" is fine.
5. **Start date** — today's date is shown; confirm or override. Format: YYYY-MM-DD.

---

## Step 2 — Scaffold the Directory

Create the following structure under `$PLANS_ROOT/<project-name>/`.
Use the answers from the interview to fill in every value — no placeholders in generated files.

### Always created

```
<project-name>/
├── CLAUDE.md
├── README.md
├── issues.md
├── sessions-table.md
└── CONTEXT_STATE.md
```

### Per subproject (if subprojects were listed)

```
<project-name>/
└── <subproject-name>/
    ├── plan.md
    ├── implementation-plan.md
    └── sessions-table.md
```

### File contents

**CLAUDE.md** — copy the 12-rule template exactly from `$PLANS_ROOT/CLAUDE.md` (the root one). Do not modify it.

**README.md** — generate with:
- Project name + description at top
- "Local only. Never committed." note (if sensitive) or omit if it's fine to push
- Repos Involved table (from interview answer)
- Standing Rules section (8 rules from the helm-vault-migration README pattern — no hardcoding, restate generically)
- Session Close-Out Sequence section (the 10-step close-out sequence)
- Backup section — S3 sync commands using `$PLANS_ROOT` as the local path and `$GITHUB_REMOTE` as the remote reference note

**issues.md** — empty log with format header:
```markdown
# Issues Log — <project-name>

Read this before starting any session. Newest entries at top.

---

## Format

\`\`\`
## [YYYY-MM-DD] [SUBPROJECT] [SESSION] — short title
**What happened:** ...
**Impact:** ...
**Resolution:** ...
**PR:** <url or "pending">
\`\`\`

---

## PRs

| Date | Session | PR | Status |
|---|---|---|---|

---
```

**sessions-table.md** — template shell:
```markdown
# Sessions Table — <project-name>

---

## Subprojects

| Subproject | File |
|---|---|
| <subproject> | `<subproject>/sessions-table.md` |

---

## How to Start a Session

\`\`\`
cd <repo-local-path>
git checkout main && git pull origin main
claude -n "Session: <branch>"
\`\`\`

Then say the kick phrase listed in the subproject's sessions table.
```

(If no subprojects, the sessions table lives here directly instead of routing to subdirs.)

**CONTEXT_STATE.md** — stub only:
```markdown
# CONTEXT_STATE.md

> Feed this as the opening prompt of any new session.
> Populate after the first session using the context-compaction skill.

## Meta

| Field | Value |
|-------|-------|
| last_updated | <start-date> |
| updated_by | plan-scaffold |
| project | <project-name> |
| repo | <PLANS_ROOT>/<project-name> |

## Active Tasks

_Populate after first session._

## Hydration Prompt

_Populate after first session using context-compaction skill._
```

**Per-subproject plan.md** — stub:
```markdown
# Plan — <subproject-name>

> Part of project: <project-name>

## Goal

_Fill in after brainstorming._

## Sessions

_Fill in before first session._

## Success Criteria

_Fill in before first session._
```

**Per-subproject implementation-plan.md** — stub:
```markdown
# Implementation Plan — <subproject-name>

_Fill in during or after brainstorming._
```

**Per-subproject sessions-table.md**:
```markdown
# Sessions Table — <subproject-name>

**Project-specific file. Generic template lives at `../sessions-table.md`.**

---

## Sessions

| # | Branch | Repo | Local Path | Start Command | Kick Phrase | Plan File | Depends On |
|---|---|---|---|---|---|---|---|

---

## PR Log

| Session | PR URL | Status |
|---|---|---|
```

---

## Step 3 — Update Root README.md

Open `$PLANS_ROOT/README.md` and update the two project tables.

### In-Progress table

Add a parent row for the new project, plus one `↳` row per subproject (if any):

```markdown
## In-Progress Projects

| Project | Directory | Started | Status |
|---------|-----------|---------|--------|
| <project-name> | `<project-name>/` | <start-date> | in progress |
| ↳ <subproject> | `<project-name>/<subproject>/` | <start-date> | not started |
```

### Completed table

Ensure this section exists (create it if missing). Do not add anything to it now.

```markdown
## Completed Projects

| Project | Directory | Started | Completed | Notes |
|---------|-----------|---------|-----------|-------|
```

### Moving rows to Completed

When the user indicates a project is fully done (all `↳` rows are `complete`, or a solo project is `complete`):
1. Remove the parent row and all its `↳` rows from In-Progress
2. Add a single row to Completed with the start date, today's date as Completed, and a one-line note

---

## Step 4 — Persist

Ask the user:
> "Workspace scaffolded. How do you want to save this?
> 1. Commit + push to GitHub (`$GITHUB_REMOTE`)
> 2. Sync to S3 only
> 3. Both
> 4. Neither — I'll do it manually"

Execute whichever they choose.

**Commit + push:**
```bash
git -C "$PLANS_ROOT" add <project-name>/ README.md
git -C "$PLANS_ROOT" commit -m "feat: scaffold <project-name> project workspace"
git -C "$PLANS_ROOT" push origin main
```

**S3 sync** — read the bucket name and profile from the Backup section of `$PLANS_ROOT/README.md`. Do not hardcode them.

---

## Step 5 — project-kickoff Gate

After persisting, ask:
> "Do you want to run project-kickoff to wire up infrastructure (AWS, K8s, secrets, CI/CD)? This is optional — skip it for cleanup, docs, or non-infra projects. (yes / no)"

- If **yes**: invoke the `project-kickoff` skill.
- If **no**: tell the user the workspace is ready and give them the start-of-session instructions:
  > "Your workspace is at `$PLANS_ROOT/<project-name>/`. To start your first session:
  > 1. Open the claude-plans repo: `claude` (from `$PLANS_ROOT`)
  > 2. Paste the contents of `<project-name>/CONTEXT_STATE.md` to hydrate context
  > 3. Update `CONTEXT_STATE.md` after the session using the context-compaction skill"

---

## Anti-patterns

| Temptation | Rule |
|---|---|
| "I'll put the username/path directly in the skill" | Never. Resolve at runtime via git/gh commands. |
| "I'll create a loose file at claude-plans root" | Never. Root stays clean — dirs only. |
| "I'll skip the Completed table if there's nothing in it" | Always create the section, even if empty. |
| "project-kickoff is probably needed, I'll just run it" | Always ask. It's optional. |
| "I'll move the row to Completed when the last PR merges" | Only move when the user confirms the project is done. |
