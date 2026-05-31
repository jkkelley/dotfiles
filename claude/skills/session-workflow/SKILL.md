---
name: session-workflow
description: Enforces work → test → verify → checkpoint → stop for multi-session implementation. Use when starting a session from a plan, or when the user says "session-mode" / "start session N" / "use session workflow" / "begin session workflow".
---

# Session Workflow

One task. One session. Always ends with test → verify → commit → PR → checkpoint → stop.

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
| "I'll just commit to main for now" | No. Every session has its own feature branch. No exceptions. |
| "I'll open the PR at the end of the project" | No. A PR is opened at the end of every session. |

---

## Step 0 — Orient

1. Read the current plan file. Look first in `<project-root>/claude-plans/<branch-name>.md`, then `~/.claude/plans/`, or ask the user for the path if ambiguous.
2. Identify which session/task is next. Confirm with the user if unclear.
3. **Create the session feature branch** — never work on `main`:
   ```bash
   git checkout -b feat/session-<name>
   # e.g., feat/session-infra, feat/session-site-build, feat/session-jenkins
   ```
   If the branch already exists, check it out: `git checkout feat/session-<name>`
4. State in one sentence what this session will accomplish. Tell the user:
   - The session name (e.g., **Session: infra**)
   - The feature branch it will run on (e.g., `feat/session-infra`)
   - Nothing more.

Do not begin work until the scope is confirmed.

---

## Step 1 — Work

- Implement **only** the current session's task.
- Do not touch anything scoped to a future session.
- Read relevant files before writing — follow existing patterns.
- The session's scope must be fully complete. No half-finished implementations.
- All commits go on the session feature branch. **Never commit directly to `main`.**

---

## Step 2 — Test

- Run the test/verification commands defined in the plan for this session.
- If the plan specifies no commands, run whatever is appropriate for the language/framework.
- Do not skip this step. Do not claim success without running something.

**If the session involves Terraform files** (any `.tf` file added or modified):

1. Check `.gitignore` for required entries before running anything — add any that are missing:
   ```
   test/
   **/.terraform/
   *.tfvars
   *.tfstate.backup
   **/.terraform.lock.hcl
   ```
2. Detect a free port in 30000-65000 and start Ministack on it — never hardcode 4566, multiple sessions may be running simultaneously:
   ```bash
   MINISTACK_PORT=$(python3 -c "
   import socket, random
   for p in random.sample(range(30000, 65001), 200):
       try:
           with socket.socket() as s:
               s.bind(('127.0.0.1', p))
               print(p)
               break
       except OSError:
           continue
   ")
   [ -z "$MINISTACK_PORT" ] && { echo "ERROR: No free port in 30000-65000"; exit 1; }
   podman run -d \
     --name ministack_${MINISTACK_PORT} \
     -p ${MINISTACK_PORT}:4566 \
     -v $XDG_RUNTIME_DIR/podman/podman.sock:/var/run/docker.sock:Z \
     ministackorg/ministack:full
   export AWS_ACCESS_KEY_ID=test
   export AWS_SECRET_ACCESS_KEY=test
   export AWS_DEFAULT_REGION=us-east-1
   export AWS_ENDPOINT_URL=http://localhost:${MINISTACK_PORT}
   ```
3. Verify it is up (`podman ps --filter name=ministack_${MINISTACK_PORT}`) before continuing.
4. If Ministack fails to start or Terraform errors against it, **stop and report the exact error to the user**. Do not proceed, do not imply success.
5. After testing completes (pass or fail), tear down Ministack — leaving it running holds the port open and consumes system resources:
   ```bash
   podman stop ministack_${MINISTACK_PORT} && podman rm ministack_${MINISTACK_PORT}
   ```

---

## Step 3 — Verify

- Confirm the output matches the expected result from the plan.
- If it doesn't match: diagnose and fix before proceeding.
- Only proceed to Step 4 when verification passes.

---

## Step 4 — Commit & Push & PR

Every session ends with a PR — not just the last one.

1. Stage the files changed in this session (specific files, not `git add .`).
2. Write a commit message scoped to this session's work.
3. Push the feature branch:
   ```bash
   git push -u origin feat/session-<name>
   ```
4. Open a PR from `feat/session-<name>` → `main`:
   ```bash
   gh pr create \
     --title "feat(<scope>): Session: <name> — <one-line summary>" \
     --head feat/session-<name> \
     --base main \
     --body "..."
   ```
5. Give the PR URL to the user. This is mandatory — do not skip.

---

## Step 5 — Checkpoint

Invoke the `context-compaction` skill to distill the session into `CONTEXT_STATE.md`.

The checkpoint must capture:
- What was built
- What was verified
- What the next session starts with

---

## Step 6 — Stop & Hand Off

Output a short summary with these four things, in this order:

1. **Session complete:** what was done and what was verified
2. **PR:** the URL from Step 4
3. **Next session name** and the exact phrase to say to start it, e.g.:
   > **Next:** Session: site-build — say *start session site-build* to begin.
4. **Stop.** Do not begin the next session's work.

If the user explicitly asks to continue into the next session in the same conversation, repeat Steps 1–6 for the new session (including a new feature branch and new PR) before stopping again.

---

## Session-Based Planning Convention

When a project spans multiple sessions, each session gets its own plan file:

**Naming:**
- Plan file: `<branch-name>.md` saved to the project's `claude-plans/` directory
- Feature branch: `feat/<branch>` — all work goes here, never directly to main

**Structure:**
- Every plan starts with the full Session Map table (all sessions listed)
- Plan ends with an "Output for Session N+1" section stating what the next session expects
- Session ends with: PR opened, context-compaction run, CONTEXT_STATE.md updated

**Standing rules that apply to every session in a multi-session cluster project:**
1. No hardcoded AWS account IDs, role ARNs, bucket names, or credentials in any git file — all values come from Vault at `secret/<cluster-prefix>/`
2. IAM roles (Terraform) are created before any cluster work that depends on them
3. Any new infrastructure component deployed to the cluster gets a runbook committed to your cluster runbook repo under `runbooks/<component>/` with a `README.md` and the runbook `.md` file
4. Last session of any multi-session project produces an architecture diagram and a Project Brief handoff document

---

## Hard Rules

- **One session = one task.** If the task feels small, that's fine. Don't expand scope.
- **No verification, no done.** Running the code/tests is mandatory.
- **Checkpoint is not optional.** `context-compaction` runs at the end of every session.
- **Never commit to `main`.** Every session runs on `feat/session-<name>`. No exceptions.
- **Every session gets a PR.** Open it at the end of every session, not just the last one.
- **Always give the PR URL.** The user must receive the link before the session stops.
- **Always name the next session.** Tell the user the next session name and the exact phrase to start it.
- **Stop after hand-off.** Do not continue into the next session unprompted.
