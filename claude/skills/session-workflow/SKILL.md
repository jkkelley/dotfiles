---
name: session-workflow
description: Enforces work → test → verify → checkpoint → stop for multi-session implementation. Use when starting a session from a plan, or when the user says "session-mode" / "start session N" / "use session workflow" / "begin session workflow".
version: 1.0.2
---

# Session Workflow

> **This copy is read-only.**
> Skills are vendored into a project as copies, and this may be one.
> Edit this skill upstream, bump its version, then re-pull it - never edit the copy where it landed.
> Upstream is https://raw.githubusercontent.com/jkkelley/dotfiles/refs/heads/main/claude/skills/session-workflow/SKILL.md, and `skill-update.sh` pulls it from there - no dotfiles checkout is needed on this machine.
> `skill-update.sh` replaces the skill's directory rather than merging into it, so a local edit is destroyed by the next update with no conflict and no warning.
> The registry's content hash cannot catch it either, because a project's copy legitimately differs from upstream.

One task. One session. Always ends with test → verify → checkpoint → PR → stop.

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

> **⛔ HOMELAB RULE — No local `terraform apply` against real AWS. Ever.**
>
> Terraform sessions on the homelab have one job: **write correct code and validate it locally**.
> The actual apply always happens via the Jenkins Terraform pipeline (same pattern as `yieldpoint-ai-static-website`).
> If you find yourself about to run `terraform apply` against a real AWS profile — stop. Commit the code, open the PR, let Jenkins run it.
>
> **Terraform state is always S3-backed — never local.** Before writing any Terraform module:
> - Confirm an SSM parameter exists for the state bucket: `/<project>/terraform-state-bucket`
> - If it doesn't exist yet, flag it to the user before proceeding — it must be created first
> - The Jenkins pipeline fetches the bucket name from SSM at init time and writes `backend.hcl` dynamically
> - Never hardcode the bucket name or use `terraform { backend "local" {} }`
>
> **What "testing Terraform" means locally:**
> - `terraform fmt -check` — formatting
> - `terraform validate` — syntax + provider schema
> - Ministack apply (S3-compatible resources only) — confirms resource blocks are well-formed
> - CloudFront, IAM, and other non-S3 resources cannot be tested locally — this is expected and acceptable

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

## Step 4 — Checkpoint (ask gate)

Before opening the PR, ask the user:
> "Ready for context compaction before I open the PR? (yes / no)"

- If **yes**: invoke the `context-compaction` skill now. Captures what was built, what was verified, and what the next session starts with. Then proceed to Step 5.
- If **no**: skip compaction and proceed to Step 5. User can run `context-compaction` manually at any time.

---

## Step 5 — Commit & Push & PR

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

## Step 6 — Close-Out Gate

This step runs after the PR is open. Do not skip any part of it.

### 6a — Hand PR to user for review
Tell the user:
> "PR is open at [URL] and the session is checkpointed. Review the PR on GitHub when you're ready, then come back here."

Wait for the user to confirm they have reviewed the PR.

### 6b — Log gate (ask first, do not log automatically)
Once the user confirms they've reviewed, ask:
> "Ready to log this PR with daily-pr-log? (yes / no)"

- If **yes**: invoke the `daily-pr-log` skill with the PR URL. Confirm once logged.
- If **no**: acknowledge and note they can run `daily-pr-log` manually at any time.

### 6c — Merge confirmation
Tell the user:
> "Merge the PR on GitHub when you're ready, then let me know."

Wait for the user to confirm the PR has been merged.

### 6d — Branch cleanup (ask first, do not run automatically)
Once the user confirms the PR is merged, ask:
> "Ready to clean up the branch and pull main? (yes / no)"

- If **yes**: run the following in order:
  ```bash
  git checkout main
  git branch -d feat/session-<name>
  git pull origin main
  ```
  Confirm: "`feat/session-<name>` deleted, `main` is up to date."
- If **no**: acknowledge and leave the branch in place.

---

## Step 7 — Stop & Hand Off

Output a short summary with these four things, in this order:

1. **Session complete:** what was done and what was verified
2. **PR:** the URL from Step 4
3. **Next session name** and the exact phrase to say to start it, e.g.:
   > **Next:** Session: site-build — say *start session site-build* to begin.
4. **Stop.** Do not begin the next session's work.

If the user explicitly asks to continue into the next session in the same conversation, repeat Steps 1–7 for the new session (including a new feature branch and new PR) before stopping again.

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

**MANDATORY — before starting any cluster app session, read the canonical workflow doc:**
```
# Local (primary)
~/Documents/local-k8s-docs/runbooks/cluster-app-workflow/cluster_app_workflow.md

# DR fallback (machine wiped / local-k8s-docs not cloned)
gh api repos/jkkelley/local-k8s-docs/contents/runbooks/cluster-app-workflow/cluster_app_workflow.md \
  --jq '.content' | base64 -d
```
This is the authoritative reference for the full SSM → Vault → AVP → ArgoCD → ESO → K8s → Jenkins stack. Do not start session work without reading it.

**Standing rules that apply to every session in a multi-session cluster project:**
1. No hardcoded AWS account IDs, role ARNs, bucket names, region strings, SA names, store names, resource limits, or hostnames in any git file — all values come from Vault via AVP placeholders at `<path:secret/data/homelab/...#key>`
2. `imageTag` in `values.yaml` is the **one exception** — Jenkins `yq` writes it directly. Never make imageTag a placeholder.
3. Every app on the homelab cluster uses `plugin: { name: argocd-vault-plugin }` as the ArgoCD Application source — not `helm: { releaseName: ... }`
4. ghcr-pull-secret comes from a Vault-backed ESO ExternalSecret — never seeded by the pipeline
5. IAM roles (Terraform) are created before any cluster work that depends on them
6. Any new infrastructure component deployed to the cluster gets a runbook committed to your cluster runbook repo under `runbooks/<component>/` with a `README.md` and the runbook `.md` file
7. Last session of any multi-session project produces an architecture diagram and a Project Brief handoff document
8. **SSM-first rule:** Every value seeded into Vault (secret OR config) must first exist as an SSM parameter. vault-seed.sh reads from SSM — never hardcodes values. This covers region names, SA names, resource limits, ports, hostnames, ARNs — everything without exception.
9. **vault-seed.sh update is part of every vault-seed session:** Any session that creates or modifies Vault paths must update `vault-seed.sh` with `ssm_get()` calls for every new key, and update the SSM Parameter Inventory in `vault_seed.md`. The local-k8s-docs PR must be opened before or alongside the app PR — never left as a follow-up.
   - Local:  `~/Documents/local-k8s-docs/runbooks/vault-seed/vault-seed.sh`
   - Remote (DR fallback): `https://github.com/jkkelley/local-k8s-docs/blob/main/runbooks/vault-seed/vault-seed.sh`
10. **Terraform state is always S3-backed, never local.** Every Terraform module needs a `/<project>/terraform-state-bucket` SSM param. The Jenkins pipeline fetches it at init time. No `terraform apply` runs locally — Ministack for validation, Jenkins for real apply. See `local-k8s-docs/runbooks/k8s-jenkins/jenkins-pipeline-irsa.md` for the full Jenkins Terraform pipeline pattern.
11. **Jenkins pipelines use IRSA — never static AWS credentials.** No `aws-access-key-id` or `aws-secret-access-key` in Vault for pipeline use. Every pipeline type gets a dedicated ServiceAccount (`jenkins-{project}-sa`) and a scoped IAM role (`jenkins-{project}-role`). See `local-k8s-docs/runbooks/k8s-jenkins/jenkins-pipeline-irsa.md`.

---

## Hard Rules

- **One session = one task.** If the task feels small, that's fine. Don't expand scope.
- **No verification, no done.** Running the code/tests is mandatory.
- **Checkpoint before PR — always ask first.** Before opening the PR, ask: "Ready for context compaction? (yes / no)". If yes, run `context-compaction` then open the PR. If no, open the PR and skip. Never open the PR before asking.
- **Never commit to `main`.** Every session runs on `feat/session-<name>`. No exceptions.
- **Every session gets a PR.** Open it at the end of every session, not just the last one.
- **Always give the PR URL.** The user must receive the link before the session stops.
- **Never log automatically.** Always ask the user before invoking `daily-pr-log`. This is a gate, not an assumption.
- **Never clean up the branch automatically.** Always ask the user before running `git checkout main && git branch -d && git pull`. This is a gate, not an assumption.
- **Always name the next session.** Tell the user the next session name and the exact phrase to start it.
- **Stop after hand-off.** Do not continue into the next session unprompted.
- **Never `terraform apply` against real AWS locally.** Ministack validates code. Jenkins applies it. No exceptions.
- **Never use static AWS credentials in Jenkins pipelines.** IRSA only. No `aws-access-key-id` or `aws-secret-access-key` in Vault for pipeline use. See `local-k8s-docs/runbooks/k8s-jenkins/jenkins-pipeline-irsa.md`.
- **Terraform state is always S3-backed.** Confirm `/<project>/terraform-state-bucket` SSM param exists before writing any Terraform module. Never use local state.
