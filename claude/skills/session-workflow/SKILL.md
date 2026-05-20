---
name: session-workflow
description: Enforces work → test → verify → checkpoint → stop for multi-session implementation. Use when starting a session from a plan, or when the user says "session-mode" / "start session N" / "use session workflow" / "begin session workflow".
---

# Session Workflow

One task. One session. Always ends with test → verify → commit → checkpoint → stop.

## When This Applies

- User says "session-mode", "use session workflow", "begin session workflow"
- User says "start session N" or "session N"
- User invokes `/session-workflow`
- Used by sessions dispatched from **task-router** via handoff documents — each handoff doc represents one session governed by this skill

## Red Flags

| Thought | Reality |
|---|---|
| "I'll just do one more thing while I'm here" | Scope creep. Stop at the session boundary. |
| "I'll test it next session" | No. Test now or it didn't happen. |
| "The verification is close enough" | Run the actual command. Approximate is not verified. |
| "I'll checkpoint at the start of the next session" | Checkpoint happens at the END of this session. |
| "This is too simple to need a checkpoint" | Simple sessions compound into complex drift. Always checkpoint. |

---

## Step 0 — Orient

1. Read the current plan file. Look in `~/.claude/plans/` or ask the user for the path if ambiguous.
2. Identify which session/task is next. Confirm with the user if unclear.
3. State in one sentence what this session will accomplish. Nothing more.

Do not begin work until the scope is confirmed.

---

## Step 1 — Work

- Implement **only** the current session's task.
- Do not touch anything scoped to a future session.
- Read relevant files before writing — follow existing patterns.
- The session's scope must be fully complete. No half-finished implementations.

---

## Step 2 — Test

- Run the test/verification commands defined in the plan for this session.
- If the plan specifies no commands, run whatever is appropriate for the language/framework.
- Do not skip this step. Do not claim success without running something.

---

## Step 3 — Verify

- Confirm the output matches the expected result from the plan.
- If it doesn't match: diagnose and fix before proceeding.
- Only proceed to Step 4 when verification passes.

---

## Step 4 — Commit & Push

1. Stage the files changed in this session (specific files, not `git add .`).
2. Write a commit message scoped to this session's work.
3. Push the branch.
4. If the plan marks this session as the last one: open a PR.

---

## Step 5 — Checkpoint

Invoke the `context-compaction` skill to distill the session into `CONTEXT_STATE.md`.

The checkpoint must capture:
- What was built
- What was verified
- What the next session starts with

---

## Step 6 — Stop & Hand Off

Output a short "Session N complete" summary:
- What was done
- What was verified
- What the next session will work on (exact task from the plan)

**Stop. Do not begin the next session's work.**

If the user explicitly asks to continue into the next session in the same conversation, repeat Steps 2–6 for the new session before stopping again.

---

## Hard Rules

- **One session = one task.** If the task feels small, that's fine. Don't expand scope.
- **No verification, no done.** Running the code/tests is mandatory.
- **Checkpoint is not optional.** `context-compaction` runs at the end of every session.
- **Stop after hand-off.** Do not continue into the next session unprompted.
