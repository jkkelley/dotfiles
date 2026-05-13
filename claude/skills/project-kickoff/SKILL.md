---
name: project-kickoff
description: Run at the start of any new project before brainstorming or writing plans. Interviews the user about project infrastructure needs (AWS, K8s, secrets, CI/CD, DNS) and produces a filled-in, project-specific kickoff checklist with exact commands to run. Use when the user says "new project", "starting a project", "project kickoff", or "set up a new project".
---

# Project Kickoff

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
      gh repo create jkkelley/<project-name> --private --clone
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
      Use `jenkins-job-bootstrap` skill with `repo: jkkelley/<project-name>`

### 5. Brainstorm & Plan
- [ ] Run `superpowers:brainstorming` skill
- [ ] Run `superpowers:writing-plans` skill
- [ ] Confirm plan file saved to `~/.claude/plans/<plan-name>.md`

### 6. First Session
- [ ] Run `session-workflow` skill for Session 1
```

Fill in every `<placeholder>` from the interview answers before outputting.
If a section doesn't apply (e.g. no AWS, no K8s), omit it entirely — don't include it with "N/A".

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
