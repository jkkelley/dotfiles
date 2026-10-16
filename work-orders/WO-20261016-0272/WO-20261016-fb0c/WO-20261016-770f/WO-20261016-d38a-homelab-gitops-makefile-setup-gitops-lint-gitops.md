---
{
  "id": "WO-20261016-d38a",
  "slug": "homelab-gitops-makefile-setup-gitops-lint-gitops",
  "title": "homelab-gitops Makefile: setup, gitops-lint, gitops-lint-all, deploy-gate, tracked-ignored-check and md-contents-check call the dotfiles gitops-ci tool",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:51:31+00:00",
  "parent": "WO-20261016-770f",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design19 cut ORD-1128 K1 and ORD-1140 S3 (brief BR-20261016-infra-design19); design approvals ruled done, ORD-0550 O4; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-6147"
  ],
  "blocks": [
    "WO-20261016-9a0f"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "grep -c -E '^(setup|gitops-lint|gitops-lint-all|deploy-gate|tracked-ignored-check|md-contents-check):' Makefile",
      "exit": 0,
      "expect": "^6$"
    },
    {
      "index": 2,
      "command": "grep -c -F 'claude/workflow/gitops-ci/gitops-ci.mk' Makefile",
      "exit": 0,
      "expect": "^[1-9]"
    },
    {
      "index": 3,
      "command": "make tracked-ignored-check",
      "exit": 0,
      "expect": "tracked-ignored-check: ok"
    },
    {
      "index": 4,
      "command": "grep -cx '\\.ci/' .gitignore",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 5,
      "command": "grep -c -P '^\\t' Makefile",
      "exit": 0,
      "expect": "^[6-9]"
    },
    {
      "index": 6,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(Makefile|\\.gitignore)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "make:setup",
    "make:gitops-lint",
    "make:gitops-lint-all",
    "make:deploy-gate",
    "make:tracked-ignored-check",
    "make:md-contents-check"
  ],
  "labels": [
    "line:inbox-triage"
  ],
  "repo": "jkkelley/homelab-gitops"
}
---

# WO-20261016-d38a - homelab-gitops Makefile: setup, gitops-lint, gitops-lint-all, deploy-gate, tracked-ignored-check and md-contents-check call the dotfiles gitops-ci tool

## Contents

- Problem
- Owner words
- Context
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

homelab-gitops has no Makefile, and the pr-flow ci.yml template runs make <target> per matrix entry, so the repo has no CI entry points to install.

## Owner words

> ORD-1128 K1 gitops CI tooling: tooling ticket first (rule 30): homelab-gitops CI, diff-selected and fast: yamllint and kubeconform on changed manifests, helm template plus kubeconform for changed charts, kustomize build for changed overlays, tracked-ignored-check, md-contents; plus the merge-on-green Action ported (one config entry if the template allows). A gitops merge is a deploy, so merge-on-green there also requires the PR dev and UAT gate evidence named in its ticket (rule 34). (orchestrator brief BR-20261016-infra-design19)

> makefiles with scripts driving automation, NEVER by hand! (Design principles 101 item 3)

## Context

Epic WO-20261016-770f holds the design. Code repo jkkelley/homelab-gitops (local clone ~/projects/homelab-gitops); the ticket file lives in dotfiles. Open homelab-gitops PRs 104, 105 and 106 (line-ops pr-sweep, seat lo-ddf1) touch apps/line-ops and docs only; this ticket touches only Makefile (new) and .gitignore, so they are disjoint. The Makefile only wires: the work is in dotfiles claude/workflow/gitops-ci (tickets WO-20261016-b7ee, WO-20261016-d1be, WO-20261016-3201 and the gitops-ci.mk ticket); it does not run until those are on dotfiles main, and its checks here are structural.

Makefile content, exactly these lines; every recipe line starts with one tab character: line 1 "# homelab-gitops CI entry points (dotfiles ticket THIS-TICKET-ID, ORD-1128 K1). The work lives in dotfiles claude/workflow/gitops-ci; this file only wires it." line 2 "# Breadcrumb: setup clones dotfiles into .ci/dotfiles (ignored) because the gitops tooling is generic and shared (Design principles 101 item 4). Rejected: a vendored copy, which drifts from main. Cost: one shallow clone per CI job." then "DOTFILES_REPO ?= https://github.com/jkkelley/dotfiles", "DOTFILES_REF ?= main", "DOTFILES ?= .ci/dotfiles", "GC_MK = $(DOTFILES)/claude/workflow/gitops-ci/gitops-ci.mk", "GC_ARGS = REPO=jkkelley/homelab-gitops REPO_DIR=$(CURDIR)", ".PHONY: setup gitops-lint gitops-lint-all deploy-gate tracked-ignored-check md-contents-check", then targets: "setup: ## clone the dotfiles gitops-ci tooling into .ci/dotfiles (idempotent)" recipe "@test -d $(DOTFILES)/.git || git clone -q --depth 1 --branch $(DOTFILES_REF) $(DOTFILES_REPO) $(DOTFILES)"; "gitops-lint: setup ## yamllint, kubeconform, helm template and kustomize build on files changed vs BASE_REF" recipe "@$(MAKE) --no-print-directory -f $(GC_MK) gitops-check $(GC_ARGS) BASE=$(BASE_REF)"; "gitops-lint-all: setup ## the same on every tracked file (push to main)" recipe "@$(MAKE) --no-print-directory -f $(GC_MK) gitops-check $(GC_ARGS) BASE="; "deploy-gate: setup ## a PR touching a deploy path names its ticket and its dev and UAT gate evidence (rule 34)" recipe "@$(MAKE) --no-print-directory -f $(GC_MK) gitops-gate $(GC_ARGS) BASE=$(BASE_REF) $(if $(BODY),BODY=$(BODY))"; "tracked-ignored-check: ## fail when git tracks a path .gitignore excludes" recipe "@bad=\"$$(git ls-files -ci --exclude-standard)\"; if [ -n \"$$bad\" ]; then echo \"tracked-ignored-check: tracked but ignored:\"; echo \"$$bad\"; exit 1; fi; echo \"tracked-ignored-check: ok\"" (the dotfiles root Makefile recipe, ported as business did in PR 244); "md-contents-check: setup ## changed Markdown opens with a contents list" recipe "@BASE=$(or $(BASE_REF),origin/main) bash $(DOTFILES)/scripts/md-contents.sh check". Append one line ".ci/" to .gitignore.

## Scope

**In**

- touches: Makefile (new, in jkkelley/homelab-gitops)
- touches: .gitignore (one appended line .ci/, in jkkelley/homelab-gitops)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: in ~/projects/homelab-gitops, git fetch origin and git worktree add a branch feat/THIS-HEX-gitops-ci-makefile from origin/main (fallback: worktree add fails: fresh git clone into a mktemp dir), never the primary clone working tree
- step: write Makefile and the .gitignore line exactly as in Context, then from dotfiles run bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID --code-dir <the homelab-gitops worktree>
- step: commit 'ci: Makefile entry points for the dotfiles gitops-ci tool' with the ticket id in homelab-gitops; push, open the PR there with gh pr create -R jkkelley/homelab-gitops; submit --pr <N> in dotfiles; leave
- tool: cmd:git, cmd:make, cmd:gh, cmd:grep - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any file under apps/, argocd-apps/, bootstrap/, helm/ or docs/: a merge there is a deploy, and PRs 104-106 own docs/line-ops
- .github/workflows: the pr-flow install ticket renders them
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* all six targets exist
  - check: `grep -c -E '^(setup|gitops-lint|gitops-lint-all|deploy-gate|tracked-ignored-check|md-contents-check):' Makefile` exit 0 expect /^6$/
- [ ] `AC-H2` *(human)* the Makefile calls the dotfiles gitops-ci.mk
  - check: `grep -c -F 'claude/workflow/gitops-ci/gitops-ci.mk' Makefile` exit 0 expect /^[1-9]/
- [ ] `AC-H3` *(human)* tracked-ignored-check passes on the branch
  - check: `make tracked-ignored-check` exit 0 expect /tracked-ignored-check: ok/
- [ ] `AC-H4` *(human)* .ci/ is ignored
  - check: `grep -cx '\.ci/' .gitignore` exit 0 expect /^1$/
- [ ] `AC-H5` *(human)* recipes are tab-indented
  - check: `grep -c -P '^\t' Makefile` exit 0 expect /^[6-9]/
- [ ] `AC-H6` *(human)* the diff holds only the In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(Makefile|\.gitignore)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

homelab-gitops Makefile, the CI entry points that call the dotfiles gitops-ci targets

**Cases**

- `TP-1`
  - intent: every target the pr-flow ci.yml matrix calls exists, so CI never fails on a missing target
  - command: `grep -c -E '^(setup|gitops-lint|gitops-lint-all|deploy-gate|tracked-ignored-check|md-contents-check):' Makefile`
  - expected: exit 0 and 6
- `TP-2`
  - intent: the Makefile calls the shared dotfiles tool, never a vendored copy (item 4)
  - command: `grep -c -F 'claude/workflow/gitops-ci/gitops-ci.mk' Makefile`
  - expected: exit 0 and a count of 1 or more
- `TP-3`
  - intent: the cloned tool dir is ignored, so it can never be committed into the deploy repo
  - command: `grep -cx '\.ci/' .gitignore`
  - expected: exit 0 and 1

**Isolation**

- runtime: podman
- image: localhost/dotfiles-workflow-test:1
- build: make -C claude/workflow image
- containerfile: claude/workflow/tests/container/Containerfile

**Out of scope - CI covers**

- lint and the full suite: CI runs them (Design principles 101 item 6)

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
