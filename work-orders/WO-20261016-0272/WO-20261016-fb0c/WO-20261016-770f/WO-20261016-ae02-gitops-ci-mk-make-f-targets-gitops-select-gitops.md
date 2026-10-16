---
{
  "id": "WO-20261016-ae02",
  "slug": "gitops-ci-mk-make-f-targets-gitops-select-gitops",
  "title": "gitops-ci.mk: make -f targets gitops-select, gitops-check, gitops-gate, gitops-ci-test, gitops-ci-clean, timed by timed-run.sh, plus the gitops-ci README",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:52:08+00:00",
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
    "WO-20261016-b7ee",
    "WO-20261016-d1be",
    "WO-20261016-3201"
  ],
  "blocks": [
    "WO-20261016-21b4"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "grep -c -E '^(gitops-select|gitops-check|gitops-gate|gitops-ci-test|gitops-ci-clean):' claude/workflow/gitops-ci/gitops-ci.mk",
      "exit": 0,
      "expect": "^5$"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'make -f claude/workflow/gitops-ci/gitops-ci.mk gitops-select REPO=jkkelley/homelab-gitops REPO_DIR=$PWD BASE=HEAD SELECT=/tmp/gc-s.json && jq -c .deploy /tmp/gc-s.json'",
      "exit": 0,
      "expect": "^false$"
    },
    {
      "index": 3,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'make -f claude/workflow/gitops-ci/gitops-ci.mk gitops-gate REPO=jkkelley/homelab-gitops REPO_DIR=$PWD BASE=HEAD SELECT=/tmp/gc-s.json'",
      "exit": 0,
      "expect": "GATE-SKIP no-deploy-path"
    },
    {
      "index": 4,
      "command": "make md-contents-check",
      "exit": 0,
      "expect": null
    },
    {
      "index": 5,
      "command": "grep -c -E '^(GOOD|NEVER):' claude/workflow/gitops-ci/README.md",
      "exit": 0,
      "expect": "^([3-9]|[1-9][0-9])"
    },
    {
      "index": 6,
      "command": "grep -c -i 'fallback' claude/workflow/gitops-ci/README.md",
      "exit": 0,
      "expect": "^[1-9]"
    },
    {
      "index": 7,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/gitops-ci/gitops-ci\\.mk|claude/workflow/gitops-ci/README\\.md)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "make -f claude/workflow/gitops-ci/gitops-ci.mk gitops-select gitops-check gitops-gate gitops-ci-test gitops-ci-clean"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-ae02 - gitops-ci.mk: make -f targets gitops-select, gitops-check, gitops-gate, gitops-ci-test, gitops-ci-clean, timed by timed-run.sh, plus the gitops-ci README

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

The three gitops-ci scripts have no Make entry point, so a GitOps repo CI cannot call them as make targets with VAR=value (item 3, item 17), and nothing documents how to add a repo.

## Owner words

> ORD-1128 K1 gitops CI tooling: tooling ticket first (rule 30): homelab-gitops CI, diff-selected and fast: yamllint and kubeconform on changed manifests, helm template plus kubeconform for changed charts, kustomize build for changed overlays, tracked-ignored-check, md-contents; plus the merge-on-green Action ported (one config entry if the template allows). A gitops merge is a deploy, so merge-on-green there also requires the PR dev and UAT gate evidence named in its ticket (rule 34). (orchestrator brief BR-20261016-infra-design19)

> makefiles with scripts driving automation, NEVER by hand! (Design principles 101 item 3)

> time out everything logically, you will ID the bottlenecks (Design principles 101 item 37)

## Context

Epic WO-20261016-770f holds the design. Inputs on main: claude/workflow/gitops-ci/bin/gitops-changed.sh (WO-20261016-b7ee), bin/gitops-check.sh (WO-20261016-d1be), bin/gitops-gate-evidence.sh (WO-20261016-3201), config/gitops-ci.json, and claude/workflow/bin/timed-run.sh (usage: timed-run.sh --node N [--kind K] -- command). It is a standalone make -f file, not included from claude/workflow/Makefile, because open tickets (WO-20261016-e271, WO-20261016-8e05, WO-20261016-f82b) edit that Makefile, and a GitOps repo calls it from a dotfiles clone by path.

New file claude/workflow/gitops-ci/gitops-ci.mk, exactly: line 1 "# claude/workflow/gitops-ci/gitops-ci.mk - diff-selected CI for a GitOps repository (ticket THIS-TICKET-ID, ORD-1128 K1)." line 2 "# Called as: make -f <dotfiles>/claude/workflow/gitops-ci/gitops-ci.mk <target> REPO=owner/name REPO_DIR=<checkout> BASE=<ref>; every input is VAR=value (item 17), every recipe is timed by bin/timed-run.sh (item 37)." then "GC := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))", "TIMED = bash $(GC)/../bin/timed-run.sh --node $@ --kind make --", "REPO_DIR ?= $(CURDIR)", "BASE ?=", "SELECT ?= $(or $(TMPDIR),/tmp)/gitops-ci-select-$(subst /,_,$(REPO)).json", ".PHONY: gitops-select gitops-check gitops-gate gitops-ci-test gitops-ci-clean"; targets, each recipe line starting with one tab: "gitops-select: ## write the diff selection JSON to SELECT" recipes "@test -n \"$(REPO)\" || { echo \"gitops-select needs REPO=\"; exit 2; }" and "@$(TIMED) bash $(GC)/bin/gitops-changed.sh --repo $(REPO) --repo-dir $(REPO_DIR) --base \"$(BASE)\" > $(SELECT)"; "gitops-check: gitops-select ## yamllint, kubeconform, helm template and kustomize build on the selection" recipe "@$(TIMED) bash $(GC)/bin/gitops-check.sh --repo $(REPO) --repo-dir $(REPO_DIR) --select $(SELECT)"; "gitops-gate: gitops-select ## dev and UAT gate evidence on a PR touching a deploy path" recipe "@$(TIMED) bash $(GC)/bin/gitops-gate-evidence.sh --repo $(REPO) --select $(SELECT) $(if $(BODY),--body-file $(BODY))"; "gitops-ci-test: ## the gitops-ci tests in the pinned workflow test image" recipe "@$(MAKE) --no-print-directory -C $(GC)/.. image && $(TIMED) podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$(abspath $(GC)/../../..):/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash claude/workflow/gitops-ci/tests/gitops-ci.test.sh"; "gitops-ci-clean: ## remove the selection files" recipe "@rm -f $(or $(TMPDIR),/tmp)/gitops-ci-select-*.json && echo \"gitops-ci: clean\"".

New file claude/workflow/gitops-ci/README.md, one sentence per line: doctoc START and END comment lines at the top (filled by make md-contents, never by hand), "# gitops-ci", then sections "## What it does" (diff-selected yamllint, kubeconform, helm template and kustomize build, and the dev and UAT evidence gate, for any GitOps repo), "## Targets" (a table: target, inputs, what it runs, exit codes 0 ok, 1 check failed or gate held, 2 usage, 4 runtime or image missing), "## Add a repository" (one entry under repos in config/gitops-ci.json, then a Makefile in the repo as in homelab-gitops, then one entry in claude/workflow/pr-flow/config/pr-flow.json and make -C claude/workflow pr-flow-ci-install REPO=owner/name), "## Gate evidence" (the PR body lines Ticket, Gate-Dev: GATE-PASS dev ..., Gate-UAT: GATE-PASS uat ...; a body edited after the event needs a pushed commit), "## Fallbacks" (a table: podman missing: docker; no runtime: exit 4 ENV-MISSING; image pull fails 3 times: exit 4 IMAGE-PULL, CI red, merge-on-green holds; bus down: timed-run.sh warns and the step keeps its exit code; merge-on-green refused: make -C claude/workflow pr-merge REPO= PR=), then "GOOD: a PR changing apps/line-ops/base/deadman.yaml builds the line-ops base and both overlays and nothing else." and "NEVER: a deploy PR merged with no Gate-Dev and Gate-UAT lines." and "NEVER: a repo-specific copy of these scripts."

## Scope

**In**

- touches: claude/workflow/gitops-ci/gitops-ci.mk (new)
- touches: claude/workflow/gitops-ci/README.md (new)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone
- step: write both files exactly as in Context, then make md-contents to fill the README contents list, then run checks 1-7 with bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID
- step: commit 'feat(workflow): gitops-ci.mk entry points and README' with the ticket id; no Bump trailer; push, open the PR, leave
- tool: make:claude/workflow/Makefile:image - on main; fallback: image build fails: retry 3 times, then stop with ENV-MISSING and the podman output
- tool: make:Makefile:md-contents, make:Makefile:md-contents-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- claude/workflow/gitops-ci/tests/gitops-ci.test.sh: the test ticket writes it
- an include line in claude/workflow/Makefile
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the five targets exist
  - check: `grep -c -E '^(gitops-select|gitops-check|gitops-gate|gitops-ci-test|gitops-ci-clean):' claude/workflow/gitops-ci/gitops-ci.mk` exit 0 expect /^5$/
- [ ] `AC-H2` *(human)* gitops-select on an empty diff marks no deploy
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'make -f claude/workflow/gitops-ci/gitops-ci.mk gitops-select REPO=jkkelley/homelab-gitops REPO_DIR=$PWD BASE=HEAD SELECT=/tmp/gc-s.json && jq -c .deploy /tmp/gc-s.json'` exit 0 expect /^false$/
- [ ] `AC-H3` *(human)* gitops-gate on an empty diff skips
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'make -f claude/workflow/gitops-ci/gitops-ci.mk gitops-gate REPO=jkkelley/homelab-gitops REPO_DIR=$PWD BASE=HEAD SELECT=/tmp/gc-s.json'` exit 0 expect /GATE-SKIP no-deploy-path/
- [ ] `AC-H4` *(human)* the README contents list is present and fresh
  - check: `make md-contents-check` exit 0
- [ ] `AC-H5` *(human)* the README carries GOOD and NEVER examples
  - check: `grep -c -E '^(GOOD|NEVER):' claude/workflow/gitops-ci/README.md` exit 0 expect /^([3-9]|[1-9][0-9])/
- [ ] `AC-H6` *(human)* the README carries the fallbacks
  - check: `grep -c -i 'fallback' claude/workflow/gitops-ci/README.md` exit 0 expect /^[1-9]/
- [ ] `AC-H7` *(human)* the diff holds only the In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/gitops-ci/gitops-ci\.mk|claude/workflow/gitops-ci/README\.md)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/gitops-ci/gitops-ci.mk, the Make entry points, and its README

**Cases**

- `TP-1`
  - intent: a diff with no changes selects nothing and marks no deploy, so an empty PR is fast and never held
  - command: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'make -f claude/workflow/gitops-ci/gitops-ci.mk gitops-select REPO=jkkelley/homelab-gitops REPO_DIR=$PWD BASE=HEAD SELECT=/tmp/gc-s.json && jq -c .deploy /tmp/gc-s.json'`
  - expected: exit 0 and false
- `TP-2`
  - intent: the gate target wires the selection into the evidence gate
  - command: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'make -f claude/workflow/gitops-ci/gitops-ci.mk gitops-gate REPO=jkkelley/homelab-gitops REPO_DIR=$PWD BASE=HEAD SELECT=/tmp/gc-s.json'`
  - expected: exit 0 and GATE-SKIP no-deploy-path

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
