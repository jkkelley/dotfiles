---
name: plan-scaffold
description: Scaffold a new project workspace inside the claude-plans repo. Creates the full directory structure (project-specific CLAUDE.md additions, README, issues.md, sessions-table, CONTEXT_STATE stub, .claudeignore symlink, .claude/settings.local.json, per-subproject dirs), updates the root README.md project tables, then asks whether to commit/push, sync to S3, or both. Optionally chains into project-kickoff. Use when the user says "plan-scaffold", "scaffold a new project", "set up a project workspace", or after brainstorming when ready to lay down the planning structure.
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
- **Root claude-plans/ stays clean.** Only directories live at root — no loose files beyond README.md, CLAUDE.md, .gitignore, .claudeignore.
- **No PII in this skill file.** All paths, usernames, and account values are resolved at runtime (see Step 0) or collected from the user during the interview.
- **No placeholders in generated files.** Every value in every scaffolded file must be real — filled in from Step 0 or the interview. If a value is unknown, ask. Never write `<ACCOUNT_ID>` or `<AWS_PROFILE>` into a file.

---

## Directory Hierarchy — How It Works

The claude-plans repo is a three-level tree. Every Claude session started from inside it automatically inherits context from every level above:

```
claude-plans/                  ← ROOT — CLAUDE.md (12 rules + workflow), .claudeignore, .gitignore
└── <project>/                 ← PROJECT — project-specific CLAUDE.md additions, README, issues, sessions
    └── <subproject>/          ← SUBPROJECT — plan, implementation-plan, sessions-table
```

**CLAUDE.md inheritance:** Claude Code loads CLAUDE.md from ALL parent directories automatically.
- Root `claude-plans/CLAUDE.md` contains the 12 rules + workflow profile — loaded for every session in every project.
- Per-project `CLAUDE.md` starts with the 12 rules copied verbatim, then adds project-specific context (repos, paths, project rules). This makes it self-contained when a session starts from inside the project directory directly.
- Per-subproject has no CLAUDE.md — it inherits from both above.
- **Never symlink the root CLAUDE.md into a project.** Copy the 12 rules content — do not symlink.

**.claudeignore inheritance:** Each project symlinks to the root `.claudeignore`.
- `<project>/.claudeignore` → `../.claudeignore`
- Change the root once, all projects follow.

**settings.local.json scoping:** Each project has its own `.claude/settings.local.json` with permissions scoped to that project's repos and tools. Sessions started from within a project directory pick up only that project's permissions — no bleed from other projects.

---

## Step 0 — Discover Runtime Context

Before asking anything, resolve these values silently by running shell commands.

```bash
# Local root of the claude-plans repo
PLANS_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/Documents/claude-plans")

# GitHub remote URL for the claude-plans repo
GITHUB_REMOTE=$(git -C "$PLANS_ROOT" remote get-url origin 2>/dev/null || echo "unknown")

# GitHub username
GITHUB_USER=$(gh api user --jq .login 2>/dev/null || echo "unknown")

# Today's date
TODAY=$(date +%Y-%m-%d)
```

If `PLANS_ROOT` cannot be resolved (not inside the repo), tell the user:
> "Run this from inside the claude-plans repo: `cd ~/Documents/claude-plans && claude`"
Then stop.

---

## Step 1 — Interview (one question per turn)

Ask these in order. Stop after each and wait for the answer before continuing.

**Q1. Project name**
> "What should we call this project? This becomes the directory name — lowercase, hyphens. Example: `homelab-observability`"

**Q2. One-line description**
> "One sentence: what is this project doing or fixing?"

**Q3. Subprojects / workstreams**
> "Are there multiple independent tracks inside this project that each need their own plan and sessions table? (yes / no)"
- If yes: "List them one per line — each becomes a subdirectory."
- If no: project root is the working dir; no subdirectories.

**Q4. Repos involved**
> "Which GitHub repos will this project touch? List them one per line. 'none yet' is fine."

**Q5. Local paths for each repo**
> (Ask for EACH repo listed in Q4, one at a time)
> "What is the local path to `<repo>` on this machine? Example: `~/projects/homelab-gitops`"
- Skip if Q4 was "none yet".

**Q6. S3 backup**
> "Does this project need S3 backup? The root README has a backup section — should this project also sync to S3? (yes / no)"
- If yes, continue to Q7 and Q8.
- If no, skip to Q9.

**Q7. AWS Account ID** *(only if Q6 = yes)*
> "What is your AWS Account ID? This fills the S3 bucket name in the project README."

**Q8. AWS CLI profile** *(only if Q6 = yes)*
> "What AWS CLI profile should be used for S3 sync? Example: `my-admin-profile`"

**Q9. Pre-allowed permissions**
> "Any tools you know you'll need pre-allowed in `.claude/settings.local.json` for this project? Common ones: `Bash(kubectl *)`, `Bash(terraform *)`, `Bash(docker *)`. List them, or say 'none' to start minimal.
> Note: run the `fewer-permission-prompts` skill after your first session to auto-expand this."

**Q10. Start date**
> "Start date for this project? (confirm today: `<TODAY>`, or enter a different YYYY-MM-DD)"

---

## Step 2 — Scaffold the Directory

Create the following under `$PLANS_ROOT/<project-name>/`.
All values come from Step 0 or the interview — no placeholders, no guessing.

### Directory tree

```
<project-name>/
├── .claudeignore              ← symlink to ../.claudeignore
├── .claude/
│   └── settings.local.json   ← project-scoped permissions
├── CLAUDE.md                  ← project-specific additions ONLY (not the 12 rules)
├── README.md
├── issues.md
├── sessions-table.md
├── CONTEXT_STATE.md
└── <subproject>/              ← one per subproject, if any
    ├── plan.md
    ├── implementation-plan.md
    └── sessions-table.md
```

### File contents

---

#### `.claudeignore` — symlink

```bash
ln -sf ../.claudeignore "$PLANS_ROOT/<project-name>/.claudeignore"
```

Do not create a new file. The root `.claudeignore` is the source of truth.

---

#### `.claude/settings.local.json`

Scaffold with:
- Core always-useful permissions (git, gh, aws s3 sync)
- Any tools the user listed in Q9
- A comment block explaining what this file does and the directory hierarchy it belongs to

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(gh pr *)",
      "Bash(gh repo *)",
      "Bash(aws s3 sync *)"
      <additional entries from Q9>
    ]
  }
}
```

> **Note to Claude**: JSON does not support comments. Do not add comment lines — the hierarchy note goes in the project README and CLAUDE.md instead.

After creating, tell the user:
> "Permissions pre-seeded with git, gh, and aws s3. Run `fewer-permission-prompts` after your first session to auto-expand based on what you actually used."

---

#### `CLAUDE.md` — 12 rules at top, then project-specific additions

Copy the 12 rules verbatim at the top of every project CLAUDE.md. They are inherited automatically via the directory hierarchy, but are also explicitly present here so the file is self-contained when a session starts from inside the project directory directly.

After the 12 rules, append the project-specific context block below.

```markdown
# CLAUDE.md — 12-rule template

These rules apply to every task in this project unless explicitly overridden.
Bias: caution over speed on non-trivial work.

## Rule 1 — Think Before Coding
State assumptions explicitly. Ask rather than guess.
Push back when a simpler approach exists. Stop when confused.

## Rule 2 — Simplicity First
Minimum code that solves the problem. Nothing speculative.
No abstractions for single-use code.

## Rule 3 — Surgical Changes
Touch only what you must. Don't improve adjacent code.
Match existing style. Don't refactor what isn't broken.

## Rule 4 — Goal-Driven Execution
Define success criteria. Loop until verified.
Strong success criteria let Claude loop independently.

## Rule 5 — Use the model only for judgment calls
Use for: classification, drafting, summarization, extraction.
Do NOT use for: routing, retries, deterministic transforms.
If code can answer, code answers.

## Rule 6 — Token budgets are not advisory
Per-task: 4,000 tokens. Per-session: 30,000 tokens.
If approaching budget, summarize and start fresh.
Surface the breach. Do not silently overrun.

## Rule 7 — Surface conflicts, don't average them
If two patterns contradict, pick one (more recent / more tested).
Explain why. Flag the other for cleanup.

## Rule 8 — Read before you write
Before adding code, read exports, immediate callers, shared utilities.
If unsure why existing code is structured a certain way, ask.

## Rule 9 — Tests verify intent, not just behavior
Tests must encode WHY behavior matters, not just WHAT it does.
A test that can't fail when business logic changes is wrong.

## Rule 10 — Checkpoint after every significant step
Summarize what was done, what's verified, what's left.
Don't continue from a state you can't describe back.

## Rule 11 — Match the codebase's conventions, even if you disagree
Conformance > taste inside the codebase.
If you think a convention is harmful, surface it. Don't fork silently.

## Rule 12 — Fail loud
"Completed" is wrong if anything was skipped silently.
"Tests pass" is wrong if any were skipped.
Default to surfacing uncertainty, not hiding it.

---

# Project: <project-name>

> Part of: claude-plans/ at <PLANS_ROOT>
> GitHub: <GITHUB_REMOTE>

## Project Context

**Description:** <one-line description from Q2>
**Started:** <start-date>

## Repos Involved

| Repo | Local Path |
|------|------------|
| <repo> | `<local-path>` |

## Subprojects

| Subproject | Directory | Status |
|------------|-----------|--------|
| <subproject> | `<subproject>/` | not started |

*(If no subprojects, omit this section.)*

## Project-Specific Rules

*Add any rules that override or extend the root 12-rule set for this project specifically.*
```

---

#### `README.md`

```markdown
# <project-name>

<one-line description>

**Parent workspace:** claude-plans/ at <PLANS_ROOT>
**GitHub:** <GITHUB_REMOTE>/tree/main/<project-name>

---

## Repos Involved

| Repo | GitHub | Local Path |
|------|--------|------------|
| <repo> | `github.com/<GITHUB_USER>/<repo>` | `<local-path>` |

---

## Subprojects

| Subproject | Directory | Status |
|------------|-----------|--------|
| <subproject> | `<subproject>/` | not started |

*(If no subprojects, omit this section.)*

---

## Standing Rules

Every session in this project enforces these without exception:

1. No hardcoded values in git — credentials, ARNs, tokens go to Vault or secrets manager.
2. Every session runs on a feature branch — nothing merges to main without a reviewed PR.
3. New session starts with `git pull origin main` — after previous PR is merged.
4. PR URL logged to `issues.md` immediately when opened.
5. Verify success criteria before closing a session.
6. Every non-obvious decision or deviation gets logged to `issues.md`.
7. Read `issues.md` before starting work each session.
8. Run context-compaction at the end of each session to update CONTEXT_STATE.md.

---

## Session Close-Out Sequence

Runs at the end of every session — no exceptions:

\`\`\`
1. Open PR → give URL to user → log URL to issues.md
2. Run context-compaction skill → update CONTEXT_STATE.md
3. Commit + push changes to claude-plans repo
4. Tell user: "Review the PR on GitHub when ready, then come back."
5. Wait for review confirmation
6. Ask: "Ready to log this PR with daily-pr-log? (yes / no)"  ← GATE
7. Tell user: "Merge the PR when ready and let me know."
8. Wait for merge confirmation
9. Run post-merge cleanup (ask first):
   git checkout main
   git pull origin main
   git branch -d <branch>
10. Ask: "Ready to push the updated CONTEXT_STATE.md to claude-plans? (yes / no)"  ← GATE
11. Confirm: "main is up to date, branch deleted, context saved — ready for next session."
\`\`\`

---

## Backup (S3)

*(Include only if Q6 = yes)*

Bucket: `claude-plans-<ACCOUNT_ID>-us-east-2-an`
Profile: `<AWS_PROFILE>`

\`\`\`bash
# Pull before starting a session
aws s3 sync s3://claude-plans-<ACCOUNT_ID>-us-east-2-an/<project-name>/ \
  $PLANS_ROOT/<project-name>/ --profile <AWS_PROFILE>

# Push after closing a session
aws s3 sync $PLANS_ROOT/<project-name>/ \
  s3://claude-plans-<ACCOUNT_ID>-us-east-2-an/<project-name>/ --profile <AWS_PROFILE>
\`\`\`
```

---

#### `issues.md`

```markdown
# Issues Log — <project-name>

> Part of: claude-plans/<project-name>/
> Read this before starting any session. Newest entries at top.

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

---

#### `sessions-table.md`

```markdown
# Sessions Table — <project-name>

> Part of: claude-plans/<project-name>/
> Subproject-specific files live in each subproject directory.

---

## Subprojects

| Subproject | Sessions File |
|---|---|
| <subproject> | `<subproject>/sessions-table.md` |

*(If no subprojects, put the sessions table directly here instead.)*

---

## How to Start a Session

\`\`\`bash
cd <PLANS_ROOT>
claude -n "Session: <branch>"
\`\`\`

Paste CONTEXT_STATE.md as the opening prompt, then say the kick phrase from the subproject sessions table.
```

---

#### `CONTEXT_STATE.md`

```markdown
# CONTEXT_STATE.md

> Feed this as the opening prompt of any new session.
> **After your first session: run the `context-compaction` skill to populate this file.**
> Do not edit manually unless re-validating against live infrastructure.

## Meta

| Field | Value |
|-------|-------|
| last_updated | <start-date> |
| updated_by | plan-scaffold |
| project | <project-name> |
| local_root | <PLANS_ROOT>/<project-name> |
| github | <GITHUB_REMOTE>/tree/main/<project-name> |

## Active Tasks

_Populate after first session using context-compaction skill._

## Hydration Prompt

_Populate after first session using context-compaction skill._
```

---

#### Per-subproject `plan.md`

```markdown
# Plan — <subproject-name>

> Subproject of: <project-name>
> Project root: <PLANS_ROOT>/<project-name>/
> Sessions table: ./sessions-table.md

## Goal

_Fill in after brainstorming._

## Sessions

_Fill in before first session._

## Success Criteria

_Fill in before first session._
```

---

#### Per-subproject `implementation-plan.md`

```markdown
# Implementation Plan — <subproject-name>

> Subproject of: <project-name>

_Fill in during or after brainstorming._
```

---

#### Per-subproject `sessions-table.md`

```markdown
# Sessions Table — <subproject-name>

> Subproject of: <project-name>
> Parent sessions table: ../sessions-table.md
> Project root: <PLANS_ROOT>/<project-name>/

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

Open `$PLANS_ROOT/README.md` and update both project tables.

### Add to In-Progress table

```markdown
| <project-name> | `<project-name>/` | <start-date> | in progress |
| ↳ <subproject> | `<project-name>/<subproject>/` | <start-date> | not started |
```

### Ensure Completed table exists

If it doesn't exist, create it as an empty section. Do not add rows to it now.

### Moving rows to Completed

Only do this when the user explicitly confirms the project is fully done.
1. Remove parent row and all `↳` rows from In-Progress
2. Add one row to Completed: project name, directory, start date, today as completed date, one-line note

### Updating subproject status day-to-day

When a user says a subproject is starting, in progress, or complete — update its `↳` row in the In-Progress table. Do not wait to be asked. Prompt the user at the end of each session:
> "Should I update the status for `↳ <subproject>` in the root README? Current: `<status>`. New status?"

---

## Step 4 — Persist

Ask the user:
> "Workspace scaffolded. How do you want to save this?
> 1. Commit + push to GitHub (`$GITHUB_REMOTE`)
> 2. Sync to S3 only
> 3. Both
> 4. Neither — I'll do it manually"

**Commit + push:**
```bash
git -C "$PLANS_ROOT" add <project-name>/ README.md
git -C "$PLANS_ROOT" commit -m "feat: scaffold <project-name> project workspace"
git -C "$PLANS_ROOT" push origin main
```

**S3 sync** — use the exact bucket and profile values collected in Q7 and Q8. If Q6 was "no", skip S3 option entirely.

---

## Step 5 — Session Close-Out Gates

These gates run at the END of every working session (not just during scaffolding).
Scaffold puts them in the project README — but also enforce them here when a session wraps up.

**After PR is open:**
1. Ask: "Ready to log this PR with daily-pr-log? (yes / no)" — never log automatically.

**After user confirms PR is merged:**
2. Ask: "Ready to run context-compaction to update CONTEXT_STATE.md? (yes / no)"
3. Ask: "Ready to clean up the branch and pull main? (yes / no)"
   If yes:
   ```bash
   git checkout main
   git pull origin main
   git branch -d <branch-name>
   ```
   Confirm: "`<branch>` deleted, main is up to date."
4. Ask: "Ready to commit + push the updated CONTEXT_STATE.md and any plan changes to claude-plans? (yes / no)"

---

## Step 6 — project-kickoff Gate

After Step 4, ask:
> "Do you want to run project-kickoff to wire up infrastructure (AWS, K8s, secrets, CI/CD)? Skip this for cleanup, docs, or non-infra projects. (yes / no)"

- If **yes**: invoke the `project-kickoff` skill.
- If **no**: wrap up with:
  > "Your workspace is at `$PLANS_ROOT/<project-name>/`. First session:
  > 1. `cd $PLANS_ROOT && claude`
  > 2. Paste `<project-name>/CONTEXT_STATE.md` as your opening prompt
  > 3. At end of session: run `context-compaction` to populate CONTEXT_STATE.md"

---

## Anti-patterns

| Temptation | Rule |
|---|---|
| "I'll put the username/path directly in the skill" | Never. Resolve at runtime via git/gh commands. |
| "I'll write `<ACCOUNT_ID>` into a scaffolded file" | Never. Collect the real value in Q7 or skip S3. |
| "I'll symlink the root CLAUDE.md into the project" | Never. Symlinks create one shared file — changes bleed across projects. Copy the 12 rules verbatim instead. |
| "I'll create a new .claudeignore file for the project" | Never. Symlink to `../.claudeignore`. One source of truth. |
| "I'll create a loose file at claude-plans root" | Never. Root stays clean — dirs only. |
| "I'll skip the Completed table if there's nothing in it" | Always create the section, even if empty. |
| "project-kickoff is probably needed, I'll just run it" | Always ask. It's optional. |
| "I'll move the row to Completed when the last PR merges" | Only move when the user explicitly confirms the project is done. |
| "I'll log the PR automatically" | Never. Always ask first. |
| "I'll clean up the branch after merge without asking" | Never. Always ask before `git branch -d`. |

---

## FLAG — Workflow Profile (future work)

The user's workflow preferences, always-used skills, and session conventions currently live in:
- Root `claude-plans/CLAUDE.md` (Workflow & Skills section)
- This skill file (gates and close-out sequence)

A future `workflow-profile` skill or document should consolidate all of this so any Claude session — even outside claude-plans — loads the user's working style automatically. Flag this as a standalone project when the current work settles.
