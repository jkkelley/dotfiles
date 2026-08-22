---
name: project-kickoff
description: Run at the start of any new project before brainstorming or writing plans. Interviews the user about project infrastructure needs (AWS, K8s, secrets, CI/CD, DNS) and produces a filled-in, project-specific kickoff checklist with exact commands to run. Use when the user says "new project", "starting a project", "project kickoff", or "set up a new project".
version: 1.0.2
---

# Project Kickoff

> **This copy is read-only.**
> Skills are vendored into a project as copies, and this may be one.
> Edit this skill upstream, bump its version, then re-pull it - never edit the copy where it landed.
> Upstream is https://raw.githubusercontent.com/jkkelley/dotfiles/refs/heads/main/claude/skills/project-kickoff/SKILL.md, and `skill-update.sh` pulls it from there - no dotfiles checkout is needed on this machine.
> `skill-update.sh` replaces the skill's directory rather than merging into it, so a local edit is destroyed by the next update with no conflict and no warning.
> The registry's content hash cannot catch it either, because a project's copy legitimately differs from upstream.

Capture infrastructure requirements before any code is written. One question at a time.
Output is a concrete, copy-paste-ready checklist specific to this project.

## When This Applies

- User says "new project", "starting a project", "project kickoff", "set up a new project"
- User invokes `/project-kickoff`
- Invoked as a prerequisite before `superpowers:brainstorming` on a greenfield project

## Hard Rules

- **One question per message.** Never bundle multiple questions.
- **No assumptions.** If the answer implies a follow-up, ask it next turn.
- **Don't start the checklist until all questions are answered.**
- **No placeholders in the output checklist.** Every value must be filled in from the interview.

---

## Step 0 — Read Context

Before asking anything, check for an existing `CONTEXT_STATE.md` or open plan file. If found, extract what's already known and skip those questions.

---

## Step 1 — Interview (one question per turn)

Ask these in order. Skip any that are already answered by context.

### Q1 — Project identity
> "What's the project name? (This becomes the repo name, K8s namespace, AWS path prefix, and CLI profile name.)"

### Q2 — AWS needed?
> "Does this project need AWS? (SSM secrets, S3, RDS, Lambda, or anything else)"

If yes → Q2a, Q2b. If no → skip to Q3.

#### Q2a — Which AWS services?
> "Which AWS services? (e.g. SSM for secrets, S3 for storage, RDS for managed DB — list what you know, we can add more later)"

#### Q2b — Dedicated IAM user?
> "Do you want a dedicated IAM ops user for this project? (Recommended — keeps credentials isolated per project, CLI-only, no console access)"

### Q3 — Kubernetes?
> "Is this deploying to Kubernetes? Which cluster? (e.g. homelab, a new cluster, or not K8s at all)"

If yes → Q3a. If no → skip to Q4.

#### Q3a — Namespace + ESO?
> "Will it get its own namespace? And does it need External Secrets Operator to pull from SSM?"

### Q4 — Database?
> "Does it need a database? (Postgres StatefulSet, managed RDS, SQLite, none)"

### Q5 — Message bus?
> "Does it need a message bus? (NATS JetStream, Kafka, Redis Streams, none)"

### Q6 — CI/CD?
> "Does it need a Jenkins pipeline? (Or GitHub Actions, or manual for now)"

### Q7 — DNS / Ingress?
> "Does it need a public or internal DNS entry / ingress? (e.g. https://project.homelab.local)"

### Q8 — Knowledge base entry?
> "Should I create a knowledge base entry for this project under ~/projects/knowledge-base/docs/projects/<name>/?"

---

## Step 2 — Generate the Kickoff Checklist

Once all questions are answered, output a single filled-in markdown checklist.
Format: `## Project Kickoff — <project-name>` followed by ordered sections.

### Template

```markdown
## Project Kickoff — <project-name>

### 1. AWS Setup
- [ ] Create IAM ops user
      ```bash
      cd ~/projects/knowledge-base/docs/projects/<name>/aws/iam
      bash 01-create-ops-user.sh
      # When prompted:
      #   Account ID:    <account-id>
      #   Project name:  <project-name>
      #   SSM prefix:    /<project-name>
      #   Profile name:  <project-name>
      ```
- [ ] Create ESO IRSA role (if K8s + ESO)
      ```bash
      bash 02-create-eso-role.sh
      # When prompted:
      #   Role name:     <project-name>-eso-role
      #   SA name:       <project-name>-eso-sa
      #   Namespace:     <project-name>
      ```
- [ ] Put initial SSM parameters
      ```bash
      # For each secret needed at deploy time:
      aws ssm put-parameter \
        --name "/<project-name>/<param-name>" \
        --value "<value>" \
        --type SecureString \
        --profile <project-name> \
        --region us-east-2
      ```

### 2. Repository
- [ ] Create GitHub repo
      ```bash
      gh repo create <your-org>/<project-name> --private --clone
      cd ~/projects/<project-name>
      ```
- [ ] Initialize CLAUDE.md
      ```
      /init
      ```
- [ ] Create knowledge base entry
      ```bash
      mkdir -p ~/projects/knowledge-base/docs/projects/<project-name>/{plans,mockups,aws/iam}
      ```

### 3. Kubernetes Namespace (if applicable)
- [ ] Create namespace
      ```bash
      kubectl create namespace <project-name>
      ```
- [ ] Verify ESO ServiceAccount annotation (after GitOps manifests exist)
      ```bash
      kubectl get sa <project-name>-eso-sa -n <project-name> -o yaml | grep role-arn
      ```

### 4. CI/CD (if applicable)
- [ ] Add Jenkins multibranch pipeline
      Use `jenkins-job-bootstrap` skill with `repo: <your-org>/<project-name>`

### 5. Brainstorm & Plan
- [ ] Run `superpowers:brainstorming` skill
- [ ] Run `superpowers:writing-plans` skill
- [ ] Confirm plan file saved to `~/.claude/plans/<plan-name>.md`
- [ ] If the plan has 2 or more tasks: invoke `task-router` skill to coordinate execution

### 6. First Session
- [ ] If single task: use `session-workflow` skill
- [ ] If 2+ tasks: use `task-router` skill
```

Fill in every `<placeholder>` from the interview answers before outputting.
If a section doesn't apply (e.g. no AWS, no K8s), omit it entirely — don't include it with "N/A".

---

## Homelab Standing Rules (always apply)

**MANDATORY — before proceeding with any cluster project, read the canonical workflow doc:**
```
# Local (primary)
~/Documents/local-k8s-docs/runbooks/cluster-app-workflow/cluster_app_workflow.md

# DR fallback (machine wiped / local-k8s-docs not cloned)
gh api repos/jkkelley/local-k8s-docs/contents/runbooks/cluster-app-workflow/cluster_app_workflow.md \
  --jq '.content' | base64 -d
```
This is the authoritative reference for the full SSM → Vault → AVP → ArgoCD → ESO → K8s → Jenkins stack. The checklist below is derived from it — if there is any conflict, the canonical doc wins.

Every new project on the cluster is Vault-first from day one:

**Secret handling (AVP + ESO — mandatory for ALL cluster apps):**
- Nothing hardcoded in git: no ARNs, regions, SA names, store names, resource limits, hostnames, ports
- All config values come from Vault via AVP placeholders: `<path:secret/data/homelab/apps/<app>#<key>>`
- All runtime secrets (GHCR token, API keys, DB passwords) come from ESO ExternalSecrets pointing at Vault
- ArgoCD Applications use `plugin: { name: argocd-vault-plugin }` — never `helm: { releaseName: ... }`
- `imageTag` in `values.yaml` is the **one literal exception** — Jenkins `yq` writes it on every build
- GHCR pull secret always via Vault-backed ESO (Vault `secret/homelab/github#pat`) — never SSM, never hardcoded
- Pipelines use `withVaultSecrets()` from your Jenkins shared library for build-time secrets
- Vault path hierarchy: `secret/homelab/apps/<project>/`, `secret/homelab/roles/`, `secret/homelab/github/`, `secret/homelab/aws/`, `secret/homelab/services/`

**SSM-first rule (mandatory — no exceptions):**
- Every value going into Vault (secret OR config) must first be stored as an SSM parameter
- This includes: region names, SA names, store names, resource limits, ports, hostnames, ARNs — everything
- `vault-seed.sh` reads all values from SSM — never hardcodes them
  - Local:  `~/Documents/local-k8s-docs/runbooks/vault-seed/vault-seed.sh`
  - Remote: `https://github.com/jkkelley/local-k8s-docs/blob/main/runbooks/vault-seed/vault-seed.sh`
- Kickoff checklist must include: (a) SSM parameters created for all planned Vault keys, (b) vault-seed.sh updated with `ssm_get()` calls for every new key, (c) PR opened to `local-k8s-docs`

**IAM prereqs:**
- If a new component needs AWS IAM permissions, create the IAM role in Terraform *before* deploying the component to the cluster

**Runbook rule:**
- Every new infrastructure component deployed to the cluster gets a runbook in your cluster runbook repo under `runbooks/<component-name>/` with a `README.md` (what it covers, when to use it) and `<component>_runbook.md` (the runbook). Feature branch, PR to main.

Add these three items to the kickoff checklist output whenever the project targets a Kubernetes cluster:

```markdown
### 0. Cluster Prereqs
- [ ] IAM role(s) created in Terraform before any cluster deployment
- [ ] Vault paths planned: `secret/<cluster-prefix>/<project>/` keys identified
- [ ] SSM parameters created for every planned Vault key (secret AND config) before any vault kv put/patch
- [ ] `vault-seed.sh` updated with `ssm_get()` calls for every new key, SSM Parameter Inventory in `vault_seed.md` updated, PR opened to `local-k8s-docs`
      Local: `~/Documents/local-k8s-docs/runbooks/vault-seed/vault-seed.sh`
      Remote (DR fallback): `https://github.com/jkkelley/local-k8s-docs/blob/main/runbooks/vault-seed/vault-seed.sh`
- [ ] Runbook stub created in runbook repo under runbooks/<component>/ (can be filled in post-deploy)
```

---

## Step 3 — Save to Knowledge Base

After outputting the checklist, ask:

> "Want me to save this checklist to `~/projects/knowledge-base/docs/projects/<name>/kickoff-checklist.md` and commit it?"

If yes: write the file, `git add`, `git commit -m "docs(<name>): add project kickoff checklist"`, `git push`.

---

## Step 4 — Hand Off

End with one line:

> "Kickoff checklist ready. Complete the checked items in order, then start brainstorming."

Do not proceed into brainstorming, planning, or implementation. This skill's job is setup, not execution.
