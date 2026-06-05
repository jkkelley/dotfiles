# Operator Skill — Sessions & Help Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two new intents to the operator skill — `sessions` (log Claude sessions for the day) and `help` (display a capability reference card) — and update both the dotfiles skill and the private operator repo to reflect the new functionality.

**Architecture:** All skill logic lives in `claude/skills/operator/SKILL.md`. The help card source of truth is `references/help-card.md` (read at runtime, written to `$OPERATOR_REPO/HELP_README.md`). Session logs land in a `claude-sessions/YYYY/MM/` directory tree inside `$OPERATOR_REPO`. Both repos (dotfiles + operator) get updated as part of this implementation.

**Tech Stack:** Markdown, Bash (git, date), Claude Code skill system, two git repos (`~/dotfiles`, `$OPERATOR_REPO`)

---

## Repos touched

| Repo | Path | How changes land |
|------|------|-----------------|
| dotfiles | `~/dotfiles` | Feature branch → PR → merge |
| operator (private) | `~/projects/operator` | Direct commit + push (private data repo) |

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `claude/skills/operator/SKILL.md` | Modify | Add sessions intent, help intent, update header count, data layout tree, dispatch list, push-on-write list, update convention |
| `claude/skills/operator/references/help-card.md` | Create | Source of truth for operator help card |
| `~/projects/operator/README.md` | Modify | Document claude-sessions dir + HELP_README.md |
| `~/projects/operator/HELP_README.md` | Create | User-facing copy of help card |

---

## Task 1: Create feature branch

- [ ] **Step 1: Branch from main**

```bash
git -C ~/dotfiles checkout -b feat/operator-sessions-help
```

Expected: `Switched to a new branch 'feat/operator-sessions-help'`

---

## Task 2: Create `references/help-card.md`

**Files:**
- Create: `claude/skills/operator/references/help-card.md`

- [ ] **Step 1: Write the file**

Write `/home/luna/dotfiles/claude/skills/operator/references/help-card.md` with this exact content:

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

- [ ] **Step 2: Verify file exists with correct content**

```bash
head -5 ~/dotfiles/claude/skills/operator/references/help-card.md
```

Expected first line: `# Operator — Help`

---

## Task 3: Update SKILL.md — header, data layout, dispatch list, push-on-write, update convention

**Files:**
- Modify: `claude/skills/operator/SKILL.md`

Four targeted edits in this task. Do them in order.

- [ ] **Step 1: Update intent count in the intro paragraph**

Find and replace in `SKILL.md`:

Old:
```
- **Intent** — one of the 10 intents documented below.
```

New:
```
- **Intent** — one of the 12 intents documented below.
```

- [ ] **Step 2: Update the data layout tree**

Find and replace:

Old:
```
$OPERATOR_REPO/
├── README.md
├── domains/
│   └── <domain>/
│       ├── north-star.md
│       ├── projects/
│       │   └── <slug>.md
│       └── archive/
├── inbox.md
└── agenda.md
```

New:
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

- [ ] **Step 3: Update the intent dispatch list**

Find and replace:

Old:
```
Intents documented below: (a) capture, (b) plan, (c) status, (d) new-project, (e) close, (f) new-domain, (g) edit north-star, (h) agenda, (i) triage. Bootstrap is implicit and runs before any of these on first use.
```

New:
```
Intents documented below: (a) capture, (b) plan, (c) status, (d) new-project, (e) close, (f) new-domain, (g) edit north-star, (h) agenda, (i) triage, (j) backlog, (k) sessions, help. Bootstrap is implicit and runs before any of these on first use.
```

- [ ] **Step 4: Update the push-on-write list in the Configuration section**

Find and replace:

Old:
```
  - **Push-on-write:** after any write intent (capture, new-project, close, edit-north-star, new-domain), commit and `git -C "$OPERATOR_REPO" push`. On push failure, commit locally and tell the user to retry.
```

New:
```
  - **Push-on-write:** after any write intent (capture, new-project, close, edit-north-star, new-domain, backlog, sessions), commit and `git -C "$OPERATOR_REPO" push`. On push failure, commit locally and tell the user to retry.
```

- [ ] **Step 5: Append the skill update convention before the Homelab section**

Find and replace (the `---` separator just before the Homelab section):

Old:
```
---

## Homelab K8s Project Context
```

New:
```
---

## Skill Update Convention

When a new intent is added to the operator skill:

1. Update `claude/skills/operator/references/help-card.md` with the new intent row in both the Intents table and the Intent Categories table.
2. Update `SKILL.md` with the new intent behavior section.
3. Update the intent dispatch list in the `## Intent dispatch` section of `SKILL.md`.
4. Write the updated `references/help-card.md` content to `$OPERATOR_REPO/HELP_README.md`.
5. Commit + push the operator repo: `"help: add <intent-name> intent"`
6. Announce to the user:
   ```
   New capability added: <intent-name>
   <one-line description>
   Try it: "<example trigger phrase>"
   ```

---

## Homelab K8s Project Context
```

- [ ] **Step 6: Verify all four edits landed**

```bash
grep -n "12 intents\|HELP_README\|claude-sessions\|backlog, (k) sessions\|push-on-write\|Skill Update Convention" ~/dotfiles/claude/skills/operator/SKILL.md
```

Expected: 6 matching lines, one for each change.

---

## Task 4: Add sessions intent to SKILL.md

**Files:**
- Modify: `claude/skills/operator/SKILL.md`

- [ ] **Step 1: Append sessions intent after the backlog intent (before the Homelab section separator)**

Find and replace:

Old:
```
---

## Skill Update Convention
```

New:
```
---

## Intent (k): log Claude sessions

**Trigger phrasing:** "log my sessions", "log a few sessions", "operator capture claude sessions", "I need to log my session", "I need to log a few sessions".

Example invocations:
- *"hey operator, log my sessions"*
- *"hey operator, log a few sessions"*
- *"hey operator, operator capture claude sessions"*

### Behavior

1. Run pull-on-read: `git -C "$OPERATOR_REPO" pull --rebase` (warn but continue on failure).
2. Determine input mode from the prompt:
   - **Bulk** — prompt contains lines with ` @ ` (name @ directory format): parse all pairs immediately.
   - **Interactive** — no ` @ ` in prompt: ask *"How many sessions are we logging?"*, then for each session ask *"Session N — name?"* followed by *"Session N — directory?"*.
3. **Bulk parsing rule:** split each line on the **last** `@` — everything before it is the session name, everything after is the directory. This handles `@` characters in session names.
4. Capture timestamp: `date +"%Y%m%d %H:%M:%S"`.
5. Resolve file path:
   ```bash
   FILE="$OPERATOR_REPO/claude-sessions/$(date +%Y)/$(date +%m)/$(date +%d)-claude-sessions.md"
   ```
6. Create missing directories: `mkdir -p "$(dirname "$FILE")"`.
7. If file does not exist, create it with this header:
   ```markdown
   # Claude Sessions — YYYY-MM-DD

   | Time Logged | Session Name | Directory |
   |-------------|-------------|-----------|
   ```
   Then append the new rows. If file already exists, append rows only (no new header).
8. Each row format:
   ```
   | YYYYMMDD HH:MM:SS | <session name> | <directory> |
   ```
9. Stage, commit, and push:
   ```bash
   git -C "$OPERATOR_REPO" add claude-sessions/
   git -C "$OPERATOR_REPO" commit -m "sessions: $(date +%Y-%m-%d) — N session(s) logged"
   git -C "$OPERATOR_REPO" push
   ```
   On push failure: tell the user *"Logged locally but push failed. Run `git -C $OPERATOR_REPO push` to retry."*
10. Print: `Logged N session(s) to claude-sessions/YYYY/MM/DD-claude-sessions.md and pushed to remote.`
11. On a new line: `Happy Claud'ing`

---

## Skill Update Convention
```

- [ ] **Step 2: Verify sessions intent is present**

```bash
grep -n "Intent (k)" ~/dotfiles/claude/skills/operator/SKILL.md
```

Expected: one match with `## Intent (k): log Claude sessions`

---

## Task 5: Add help intent to SKILL.md

**Files:**
- Modify: `claude/skills/operator/SKILL.md`

- [ ] **Step 1: Append help intent after the sessions intent (before Skill Update Convention)**

Find and replace:

Old:
```
---

## Skill Update Convention
```

New:
```
---

## Intent: help

**Trigger phrasing:** "help", "what can you do", "operator commands", "what are your intents".

Example invocations:
- *"hey operator, help"*
- *"hey operator, what can you do"*
- *"hey operator, operator commands"*

### Behavior

1. Read `references/help-card.md` from this skill's directory (use the Read tool to fetch it).
2. Print the full contents to chat.
3. Check whether `$OPERATOR_REPO/HELP_README.md` exists:
   ```bash
   test -f "$OPERATOR_REPO/HELP_README.md"
   ```
   If it does not exist: write it from `references/help-card.md`, then commit + push silently:
   ```bash
   git -C "$OPERATOR_REPO" add HELP_README.md
   git -C "$OPERATOR_REPO" commit -m "help: create HELP_README.md"
   git -C "$OPERATOR_REPO" push
   ```
4. No other git changes — read-only intent.

---

## Skill Update Convention
```

- [ ] **Step 2: Verify help intent is present**

```bash
grep -n "Intent: help" ~/dotfiles/claude/skills/operator/SKILL.md
```

Expected: one match.

---

## Task 6: Commit dotfiles changes and open PR

- [ ] **Step 1: Stage all changes**

```bash
git -C ~/dotfiles add claude/skills/operator/SKILL.md claude/skills/operator/references/help-card.md
```

- [ ] **Step 2: Verify staged files**

```bash
git -C ~/dotfiles diff --staged --stat
```

Expected: 2 files changed — `SKILL.md` (modified) and `references/help-card.md` (new file).

- [ ] **Step 3: Commit**

```bash
git -C ~/dotfiles commit -m "feat(operator): add sessions + help intents, introduce references/help-card.md"
```

- [ ] **Step 4: Push branch**

```bash
git -C ~/dotfiles push -u origin feat/operator-sessions-help
```

- [ ] **Step 5: Open PR**

```bash
gh -C ~/dotfiles pr create \
  --title "feat(operator): add sessions + help intents" \
  --body "$(cat <<'EOF'
## Summary

- Adds **sessions** intent (k): logs Claude sessions for the day to \`claude-sessions/YYYY/MM/DD-claude-sessions.md\` in the operator repo. Supports interactive (one-at-a-time) and bulk (\`name @ directory\`) input. Appends to existing day file or creates new one.
- Adds **help** intent: reads \`references/help-card.md\` and displays a full capability reference card. Auto-creates \`HELP_README.md\` in operator repo on first run.
- Introduces \`references/help-card.md\` as the single source of truth for the help card.
- Updates data layout tree, intent dispatch list, push-on-write list, and intent count in SKILL.md.
- Documents skill update convention so new intents always stay in sync between SKILL.md and HELP_README.md.

## Test plan

- [ ] Invoke \`hey operator, help\` — confirm help card prints and HELP_README.md is created in operator repo
- [ ] Invoke \`hey operator, log my sessions\` interactively — confirm file created at correct path with correct table format
- [ ] Invoke bulk sessions — confirm all rows appended with last-\`@\` parsing
- [ ] Invoke sessions twice same day — confirm second call appends rows, does not recreate header
- [ ] Invoke sessions on a new day — confirm new file created under correct YYYY/MM/ path

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Note the PR URL — you will need it after the operator repo tasks are done.

---

## Task 7: Update `$OPERATOR_REPO/README.md`

**Files:**
- Modify: `~/projects/operator/README.md`

- [ ] **Step 1: Pull latest**

```bash
git -C ~/projects/operator pull --rebase
```

- [ ] **Step 2: Read the current README**

Read `~/projects/operator/README.md` in full before editing.

- [ ] **Step 3: Replace the layout block and common operations section**

Find and replace the layout block to add claude-sessions and HELP_README.md:

Old:
```
```
domains/<domain>/north-star.md     # the goal of this domain
domains/<domain>/projects/<slug>.md # active project cards
domains/<domain>/archive/<slug>.md  # closed project cards (done/abandoned)
inbox.md                           # raw idea captures awaiting triage
agenda.md                          # last planner output (overwritten each plan)
```
```

New:
```
```
domains/<domain>/north-star.md          # the goal of this domain
domains/<domain>/projects/<slug>.md     # active project cards
domains/<domain>/archive/<slug>.md      # closed project cards (done/abandoned)
domains/<domain>/backlog/               # bug/task backlog items
inbox.md                                # raw idea captures awaiting triage
agenda.md                               # last planner output (overwritten each plan)
claude-sessions/YYYY/MM/DD-claude-sessions.md  # daily Claude session log
HELP_README.md                          # operator capability reference card
```
```

- [ ] **Step 4: Append two new sections before the end of the file**

Append after `See the skill source for the full intent list.`:

```markdown

## Claude Sessions

Daily log of Claude Code sessions — what they were working on and where.

- **Location:** `claude-sessions/YYYY/MM/DD-claude-sessions.md`
- **Captures:** session name, local directory, timestamp logged
- **Format:** markdown table — `| Time Logged | Session Name | Directory |`
- **Invoke:** *"hey operator, log my sessions"* or *"hey operator, log a few sessions"*

New files are created per day under `claude-sessions/YYYY/MM/`. Entries for the same day are appended to the existing file.

## Help

Full reference card for all operator intents and categories.

- **Location:** `HELP_README.md`
- **Auto-created:** on first `help` invocation; kept current when new intents are added
- **Invoke:** *"hey operator, help"* or *"hey operator, what can you do"*
```

- [ ] **Step 5: Commit and push**

```bash
git -C ~/projects/operator add README.md
git -C ~/projects/operator commit -m "docs: add claude-sessions and help sections to README"
git -C ~/projects/operator push
```

---

## Task 8: Create `$OPERATOR_REPO/HELP_README.md`

**Files:**
- Create: `~/projects/operator/HELP_README.md`

- [ ] **Step 1: Write HELP_README.md from help-card.md content**

Write `~/projects/operator/HELP_README.md` with this exact content (identical to `references/help-card.md`):

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

- [ ] **Step 2: Commit and push**

```bash
git -C ~/projects/operator add HELP_README.md
git -C ~/projects/operator commit -m "help: create HELP_README.md"
git -C ~/projects/operator push
```

- [ ] **Step 3: Verify both operator repo changes are on remote**

```bash
git -C ~/projects/operator log --oneline -3
```

Expected: top two commits are `help: create HELP_README.md` and `docs: add claude-sessions and help sections to README`.

---

## Task 9: Merge the dotfiles PR

- [ ] **Step 1: Confirm PR checks pass (if any)**

```bash
gh -C ~/dotfiles pr checks
```

If no CI is configured, this will say no checks — that's fine.

- [ ] **Step 2: Merge**

```bash
gh -C ~/dotfiles pr merge feat/operator-sessions-help --squash --delete-branch
```

- [ ] **Step 3: Pull main**

```bash
git -C ~/dotfiles checkout main && git -C ~/dotfiles pull
```

- [ ] **Step 4: Verify the new files are on main**

```bash
git -C ~/dotfiles log --oneline -3
ls ~/dotfiles/claude/skills/operator/references/
```

Expected: `help-card.md` appears in the references listing.

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task that covers it |
|-----------------|-------------------|
| sessions intent with pull-on-read | Task 4 step 1 (behavior step 1) |
| sessions bulk `@` parsing with last-`@` rule | Task 4 step 1 (behavior step 3) |
| sessions append vs create logic | Task 4 step 1 (behavior steps 7–8) |
| sessions push failure handling | Task 4 step 1 (behavior step 9) |
| sessions commit + push + "Happy Claud'ing" | Task 4 step 1 (behavior steps 9–11) |
| help reads from references/help-card.md | Task 5 step 1 (behavior step 1) |
| help creates HELP_README.md if missing | Task 5 step 1 (behavior step 3) |
| references/help-card.md created | Task 2 |
| SKILL.md data layout tree updated | Task 3 step 2 |
| SKILL.md dispatch list updated | Task 3 step 3 |
| SKILL.md intent count updated | Task 3 step 1 |
| SKILL.md push-on-write list updated | Task 3 step 4 |
| Skill update convention documented | Task 3 step 5 |
| $OPERATOR_REPO/README.md updated (implementation step) | Task 7 |
| $OPERATOR_REPO/HELP_README.md created (implementation step) | Task 8 |
