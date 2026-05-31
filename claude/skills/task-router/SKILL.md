---
name: task-router
description: Multi-task project coordinator. Holds the master plan, dispatches tasks as subagents or handoff documents, manages the PR gate (announce URL → stop → wait → merge → log → cleanup). Use when the user says "task-router", "use the task router", "we need the task router here", or invokes /task-router.
---

# Task Router

Coordinate multi-task projects. One Claude session holds the plan and routes work — either dispatching subagents directly or generating handoff documents for separate Claude sessions to pick up. Every task ends at a PR gate. The router does not merge; the user does.

## When This Applies

- User says "task-router", "use the task router", "we need the task router here"
- User invokes `/task-router`
- Invoked by `project-kickoff` when the plan has 3 or more tasks

## Relationship to Other Skills

- **session-workflow** governs each *dispatched* session (work → test → verify → commit → checkpoint → stop). The task-router governs the *coordinator* session. They are complementary — reference session-workflow in every handoff doc you generate.
- **subagent-driven-development** is used when dispatching tasks directly within this session (direct execution mode).
- **daily-pr-log** is called at every PR gate to log the URL.
- **container-sandbox** is required for any task that installs dependencies or runs builds — reference it in every handoff doc.

---

## Session Plan Routing

When a user says `start plan feat/<name>` or `start session feat/<name>`:
1. Read `claude-plans/<name>.md` in the current project directory
2. Load the Session Map from the plan header — this tells you where you are in the overall project
3. Begin executing the tasks in that plan file from the first unchecked `- [ ]` item
4. Apply the cluster standing rules: Vault-first, IAM-prereqs-first, runbook-for-every-component (see `project-kickoff` skill for the full rules)

---

## Step 0 — Orient

1. Read the master plan file. Confirm its location with the user if unclear.
2. List all tasks and their current status (pending / in-progress / complete).
3. Confirm with the user which task is next before doing anything.

Do not begin work until scope is confirmed.

---

## Step 1 — Choose Dispatch Mode

For each pending task, choose one:

### Direct Execution Mode
Dispatch a subagent within this session. Use when:
- The task is self-contained and you can hold it in context
- You want spec + quality review loops in this session
- The user has not indicated they want to hand off to another session

→ Follow **subagent-driven-development** skill for dispatch, review, and iteration.

### Handoff Doc Mode
Generate a briefing document the task. Use when:
- The user wants to hand the task to a separate Claude session
- The task is in a different repo requiring a context switch
- The user explicitly says "make a handoff doc" or "I'll give this to another Claude"

→ Generate the doc using the **Standard Handoff Doc Template** below.
→ Save it to the working repo root as: `feat_<short-name>_<YYYYMMDD>_task_<N>.md`

---

## Step 2 — Standard Handoff Doc Template

Every handoff doc you generate must follow this structure exactly. No exceptions.

```markdown
# Task N: <title>

**Session name:** `feat/<branch-name>`
**Branch:** `feat/<branch-name>`
**Repo:** `~/projects/<repo-name>`

---

## Context

<2-3 sentences: what's done so far, what this task covers, why it matters>

---

## Workflow rules (non-negotiable)

1. **Work on `feat/<branch>` only** — never commit to main
2. **No real values** — all placeholder fields use `PLACEHOLDER_*`. No real account IDs, ARNs, domains, or credentials
3. **Open PR when done** — use `gh pr create`, print the URL, then **STOP**. Do not proceed further
4. **Wait for user to merge** — the user reviews and merges. Do nothing until told
5. **Post-merge cleanup** — when told it's merged: `git checkout main && git pull`, then ask the user if they want the local branch deleted
6. **Testing via container-sandbox** — use the container-sandbox skill for any installs or builds. No bare host installs

---

## Step 1: Create branch

    cd ~/projects/<repo>
    git checkout main
    git pull
    git checkout -b feat/<branch>

## Step N: <action>

<complete content — no placeholders, no "implement this", full code/YAML/HCL inline>

---

## Step N+1: Commit

    git add <specific files>
    git commit -m "<message>"

---

## Step N+2: Push and open PR

    git push -u origin feat/<branch>

    gh pr create \
      --repo <owner>/<repo> \
      --head feat/<branch> \
      --base main \
      --title "<title>" \
      --body "..."

Print the PR URL, then **STOP. Do not proceed to the next task.**

---

## Step N+3: Post-merge (after user confirms merged)

    git checkout main
    git pull

Ask the user: "Delete local branch `feat/<branch>`?"
If yes: `git branch -d feat/<branch>`

---

## Bugs found during this task

List each issue encountered and how it was resolved:

- [issue description] → [what fixed it]
- [issue description] → [what fixed it]

At PR handoff, present this list to the user:
"I found these issues during this task — which do you want me to log?"
If none: omit this section.
```

---

## Step 3 — PR Gate

At the PR open moment, do all of the following before stopping:

1. Announce: `"PR #N is open — <title> — <url>. Please review and merge when ready."`
2. Call the **daily-pr-log** skill to append the URL to today's log
3. If the handoff doc has a non-empty "Bugs found" section, surface it:
   ```
   Issues found during this task:
   - [issue] → [fix]
   - [issue] → [fix]
   Which of these do you want me to log?
   ```
4. **STOP.** Do not proceed to the next task.

---

## Step 4 — Post-Merge Cleanup

When the user confirms the PR is merged:

```bash
git checkout main
git pull
```

Ask: "Delete local branch `feat/<branch>`?"
If yes: `git branch -d feat/<branch>`

**Mark the task complete in the master plan file** — flip the task's checkbox from `- [ ]` to `- [x]` and save. This is the durable state record. `TaskUpdate` handles in-session tracking; the plan file checkbox handles cross-session persistence so any future router session can read the plan and know exactly which tasks are done.

Then move to the next unchecked task in the plan and repeat from Step 1.

---

## Step 5 — Task Tracking

**Two layers, both required:**

**In-session (TaskCreate / TaskUpdate):**
- At session start: `TaskCreate` one entry per task in the plan
- Before starting a task: `TaskUpdate` → `in_progress`
- After PR merges and branch is deleted: `TaskUpdate` → `completed`
- This drives the in-session task list UI and keeps the current session oriented

**Cross-session (plan file checkboxes):**
- Plan files use `- [ ]` / `- [x]` checkbox syntax
- After each merge, flip the completed task's checkbox to `- [x]` in the plan file and save
- This is the source of truth across sessions — if a new router session starts mid-project, it reads the plan file checkboxes to know what's done, not the task list (which is gone)
- Never rely on memory or TaskList alone to determine which tasks are complete

---

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll just do the next task while I'm here" | No. Stop at the PR gate every time. |
| "The handoff doc doesn't need the full workflow rules block" | It does. Every handoff doc. Every time. |
| "I know what broke, I'll skip the bug report section" | No. Surface it at PR time. The user decides what gets logged. |
| "The user will remember to tell me the branch is merged" | Wait for explicit confirmation before pulling main. |
| "This task is small, I can skip the handoff doc structure" | Small tasks still need the PR gate and bug section. |
| "I'll put real values in to make it easier" | Never. PLACEHOLDER_* always. The real values incident will repeat. |
