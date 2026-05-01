# dotfiles

A library of Claude Code agents and skills — clone it, run `setup.sh`, and drop domain experts into any project in minutes.

## How it works

**Agents** are domain specialists — pre-configured sub-models with a focused description and the right tools for their domain. When Claude Code sees a relevant task, it can spin one up automatically. You get a 10-year Kubernetes veteran, an API design reviewer, a Terraform expert — without configuring any of that yourself.

**Skills** are knowledge bases that load into context on demand — reference patterns, runbooks, checklists, and recipes. Most skills ship paired with their agent, but many are standalone and work directly in your main session.

## What's in here

The library covers the full engineering stack — from low-level infrastructure to frontend UI, from CI/CD pipelines to API design and security review.

| Domain | Agents | Skills |
|---|---|---|
| Backend & APIs | `backend-dev`, `api-designer` | backend-patterns, api-design-checklist |
| Frontend | `frontend-guru`, `cypress-tester` | frontend-checklist, cypress-patterns |
| Infrastructure | `k8s-master`, `terraform-master`, `networking-guru` | kubectl-runbook, terraform-patterns, networking-runbook |
| Cloud & Architecture | `solutions-architect` | cloud-arch-patterns |
| CI/CD & GitOps | `jenkins-ci`, `argocd-gitops` | jenkinsfile-snippets, argocd-runbook |
| Code Review | `polyglot-code-reviewer`, `git-code-reviewer` | code-review-checklist, git-review-checklist |
| Tooling | `sandbox-orchestrator`, `tech-writer` | container-design, container-sandbox, context-compaction, test-writer |

## Getting started

Clone the repo, then run the interactive installer:

```bash
git clone https://github.com/<your-github-username>/dotfiles.git
cd dotfiles
./setup.sh
```

The installer will ask you to:
1. Choose **symlink** (live — changes here reflect instantly) or **copy** (portable, safe to commit into your project)
2. Pick what to install — full suite, from a config file, or manually
3. Confirm before anything is written

By default it installs into `~/.claude/`. Pass `--dest` to target a specific project instead:

```bash
./setup.sh --dest /path/to/your/project/.claude
```

## Contributing

PRs welcome. A few rules:
- No PII, real usernames, hostnames, IPs, or credentials — use `<placeholder>` format for anything environment-specific
- Agents and skills should be generic enough to work in any project
- See `CLAUDE.md` for the full policy

---

Built for [Claude Code](https://claude.ai/code).
