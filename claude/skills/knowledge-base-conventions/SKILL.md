---
name: knowledge-base-conventions
description: Directory structure, conventions, templates, and git workflow for the homelab knowledge base at ~/projects/knowledge-base. Preloaded into the tech-writer agent.
---

# Knowledge Base Conventions

## Repository

```
Local:  ~/projects/knowledge-base
Remote: github.com/<your-github-username>/knowledge-base
Branch: main
```

## Directory Structure

```
knowledge-base/
├── CLAUDE.md                              # Agent orientation — keep short
├── README.md                              # Human overview
└── docs/
    ├── cluster-overview.md                # Live cluster state (update in-place)
    ├── assets/                            # Screenshots, diagrams
    ├── argocd/                            # ArgoCD runbooks and config docs
    ├── compliance/                        # GRC tools — Secureframe, audit notes
    ├── manifests/                         # One doc per deployed project
    │   ├── <project-name>.md
    │   └── <project-name>-session-report.md
    ├── pipeline/                          # CI/CD reference (cross-project)
    │   └── pipeline-shared-lib.md
    ├── runbooks/                          # Repeatable ops procedures
    │   └── <kebab-name>.md
    ├── adr/                               # Architecture decision records
    │   └── NNNN-short-title.md
    └── incidents/                         # Significant outage post-mortems
        └── YYYY-MM-DD-short-title.md
```

## File Placement Rules

| Content type | Directory | Filename |
|-------------|-----------|----------|
| New project or app | `docs/manifests/` | `<project-name>.md` |
| Session work on existing project | Append to existing manifest doc | New `## Session — YYYY-MM-DD` header |
| Repeatable procedure | `docs/runbooks/` | `<kebab-name>.md` |
| Architecture decision | `docs/adr/` | `NNNN-<short-title>.md` (zero-padded) |
| Incident / outage | `docs/incidents/` | `YYYY-MM-DD-<short-title>.md` |
| CI/CD reference (cross-project) | `docs/pipeline/` | topic-based name |
| Cluster state changes | `docs/cluster-overview.md` | update in-place, never append |
| Compliance / GRC | `docs/compliance/` | tool-based name |
| Screenshots / images | `docs/assets/` | descriptive filename with date |

**Never** create files outside `docs/` (except `CLAUDE.md` / `README.md`).
**Never** create a new directory not listed above without a strong reason.

## Current Projects

| Project | Repo | Manifest doc |
|---------|------|--------------|
| Jenkins Security Lab (backend) | `<your-github-username>/jenkins-security-lab` | `docs/manifests/jenkins-security-lab-session-report.md` |
| Jenkins Security Lab (frontend) | `<your-github-username>/jenkins-security-lab-fe` | `docs/manifests/jenkins-security-lab-fe.md` |
| Jenkins Shared Library | `<your-github-username>/jenkins-shared-lib` | `docs/pipeline/pipeline-shared-lib.md` |

## Cluster Quick Reference

| Node | Role | IP | Arch |
|------|------|----|------|
| k8s-control-01 | control-plane | <control-plane-ip> | ARM64 |
| k8s-worker-01 | worker | <worker-1-ip> | ARM64 |
| k8s-worker-02 | worker | <worker-2-ip> | ARM64 |

- **Ingress:** HAProxy (`haproxy` class) + cert-manager (`local-ca-issuer`)
- **Storage:** Longhorn (RWO + RWX), SMB for Jenkins workspace
- **Registry:** `ghcr.io/<your-github-username>`
- **DNS:** `*.<your-homelab-domain>` → <dns-ip>

## Commit Conventions

All repos use semantic-release with Conventional Commits.

| Prefix | Use for | Bump |
|--------|---------|------|
| `docs:` | New or updated documentation | none |
| `fix:` | Correcting wrong information in docs | PATCH |
| `feat:` | New major section or doc type | MINOR |
| `chore:` | Maintenance (rename, move, cleanup) | none |

## Git Workflow

```bash
cd ~/projects/knowledge-base

# 1. Sync first — always
git pull origin main

# 2. Write or edit the doc

# 3. Stage and commit
git add docs/<path/to/file.md>
git commit -m "docs: <concise description>"

# 4. Push
git push origin main
```

## Conventions Checklist

```
[ ] File is in the correct directory (not floating in docs/ root unless it's cluster-overview)
[ ] Using the correct template for the doc type
[ ] Actual YAML/commands embedded — not "see the file" references
[ ] Dates are absolute (2026-04-30), not relative ("last week")
[ ] Problems are numbered sequentially and never renumbered
[ ] Resolved issues marked ✅ Fixed (build N / date) — not deleted
[ ] Commit message uses docs:/fix:/feat: prefix
[ ] Pushed to origin main before reporting done
```

## Document Templates

### Manifest Doc (`docs/manifests/<project-name>.md`)

```markdown
# <Project Name>

**Repo:** `github.com/<your-github-username>/<repo>`
**Namespace:** `<namespace>`
**Image:** `ghcr.io/<your-github-username>/<image>`

## Overview
One paragraph — what this project does.

## Kubernetes Manifests

### Deployment
\`\`\`yaml
# embed actual yaml here
\`\`\`

### Service / Ingress
\`\`\`yaml
# embed actual yaml here
\`\`\`

## Pipeline

| Stage | Step | Notes |
|-------|------|-------|
| SAST | sastSonarQube | project key: `<key>` |
| Build | buildKaniko | image: `ghcr.io/<your-github-username>/<image>` |
| Deploy | deployStaging | deployment: `<name>` |

## Build History

| Build | Date | Result | Notes |
|-------|------|--------|-------|
| 1 | YYYY-MM-DD | ✅ | Initial deploy |

## Problems & Fixes

### 1. <Short description>
**Problem:** <exact error or symptom>
**Fix:** <exact solution>
```

### Runbook (`docs/runbooks/<name>.md`)

```markdown
# <Runbook Title>

**Purpose:** One sentence.
**When to use:** Trigger condition.
**Est. time:** N minutes

## Prerequisites
- <requirement>

## Steps

1. <exact command or action>
   \`\`\`bash
   command here
   \`\`\`

2. <next step>

## Verification
\`\`\`bash
# command that confirms success
\`\`\`
Expected output: `<what success looks like>`

## Rollback
\`\`\`bash
# how to undo
\`\`\`
```

### ADR (`docs/adr/NNNN-<title>.md`)

```markdown
# ADR-NNNN: <Title>

**Date:** YYYY-MM-DD
**Status:** Accepted | Superseded by ADR-XXXX | Deprecated

## Context
Why a decision was needed. What problem we were solving.

## Decision
What we decided to do.

## Consequences
**Positive:** What this enables.
**Negative / trade-offs:** What we give up or take on.
```

### Incident Report (`docs/incidents/YYYY-MM-DD-<title>.md`)

```markdown
# Incident: <Title>

**Date:** YYYY-MM-DD
**Duration:** N hours
**Severity:** P1 / P2 / P3
**Status:** Resolved

## Timeline
| Time | Event |
|------|-------|
| HH:MM | <what happened> |

## Root Cause
<exact cause>

## Fix
<what resolved it, with commands>

## Follow-up
- [ ] <action item>
```
