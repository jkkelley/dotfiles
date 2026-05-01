---
title: README.md Design
date: 2026-05-01
status: approved
---

# README.md Design

## Overview

A public-facing README for the dotfiles repo on GitHub. Serves two audiences simultaneously: developers new to Claude Code agents/skills (needs the concept explained) and experienced Claude Code users browsing for a curated library (wants to get to the install fast). Tone: warm but not chatty, confident without being corporate.

## Approach

Approach B — the Reference README. Tight hero, short concept explanation, high-level inventory with a domain table, then quickstart. Scannable with headers and code blocks throughout.

## Sections

### 1. Hero

One-line tagline naming what it is and the value prop. No badges.

```
# dotfiles

A library of Claude Code agents and skills for engineering teams.
Clone it, run setup.sh, and drop domain experts into any project in minutes.
```

### 2. How It Works

Two short paragraphs explaining agents vs. skills in plain language. Avoids jargon like "subagents." Aimed at newcomers but fast enough that experienced users won't skip.

- **Agents**: domain specialists, pre-configured sub-models, spin up automatically on relevant tasks
- **Skills**: knowledge bases (runbooks, checklists, patterns) that load on demand; most paired with an agent, some standalone

### 3. What's In Here

Short paragraph conveying breadth ("full engineering stack"), then a domain table mapping agent(s) and skills per domain. No exhaustive enumeration — communicates range, not inventory.

| Domain | Agent | Skills |
|---|---|---|
| Backend & APIs | `backend-dev`, `api-designer` | backend-patterns, api-design-checklist |
| Frontend | `frontend-guru`, `cypress-tester` | frontend-checklist, cypress-patterns |
| Infrastructure | `k8s-master`, `terraform-master`, `networking-guru` | kubectl-runbook, terraform-patterns, networking-runbook |
| Cloud & Architecture | `solutions-architect` | cloud-arch-patterns |
| CI/CD & GitOps | `jenkins-ci`, `argocd-gitops` | jenkinsfile-snippets, argocd-runbook |
| Code Review | `polyglot-code-reviewer`, `git-code-reviewer` | code-review-checklist, git-review-checklist |
| Tooling | `sandbox-orchestrator`, `tech-writer` | container-design, container-sandbox, context-compaction, test-writer |

### 4. Getting Started

Comes after the concept explanation. Covers:
- `git clone` + `./setup.sh` as the primary entry point
- The three installer prompts (symlink vs copy, selection mode, confirm)
- `--dest` flag for per-project installs

### 5. Contributing

Short bullet list of rules referencing CLAUDE.md for full policy. Closes with a "Built for Claude Code" one-liner linking to claude.ai/code.

## Constraints

- No PII, real usernames, hostnames, or registry paths anywhere in the README
- All environment-specific values use `<placeholder>` format
- The clone URL must use a placeholder, not a real GitHub handle
