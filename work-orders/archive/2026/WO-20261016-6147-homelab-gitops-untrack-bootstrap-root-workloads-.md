---
{
  "id": "WO-20261016-6147",
  "slug": "homelab-gitops-untrack-bootstrap-root-workloads-",
  "title": "homelab-gitops: untrack bootstrap/.root-workloads.yaml.un~, a vim undo file tracked since 66123b9 and ignored by .gitignore *.un~",
  "type": "chore",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T12:20:18+00:00",
  "parent": "WO-20261016-770f",
  "branch": "feat/6147-homelab-gitops-untrack-bootstrap-root-workloads-",
  "pr": 107,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design21 cut DESIGN-GAP d38a and ORD-1140 S3 (brief BR-20261016-infra-design21); design approvals ruled done, ORD-0550 O4; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-d38a"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "git ls-files -ci --exclude-standard | grep -c .",
      "exit": 1,
      "expect": "^0$"
    },
    {
      "index": 2,
      "command": "git ls-files 'bootstrap/.root-workloads.yaml.un~' | grep -c .",
      "exit": 1,
      "expect": "^0$"
    },
    {
      "index": 3,
      "command": "git ls-files bootstrap/root-application.yaml | grep -c .",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vxF 'bootstrap/.root-workloads.yaml.un~'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ],
  "repo": "jkkelley/homelab-gitops"
}
---

# WO-20261016-6147 - homelab-gitops: untrack bootstrap/.root-workloads.yaml.un~, a vim undo file tracked since 66123b9 and ignored by .gitignore *.un~

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

homelab-gitops tracks bootstrap/.root-workloads.yaml.un~ (commit 66123b9) while its .gitignore line 1 *.un~ ignores it, so git ls-files -ci --exclude-standard is not empty and WO-20261016-d38a AC-H3 make tracked-ignored-check can never pass.

## Owner words

> DESIGN-GAP d38a: homelab-gitops tracks bootstrap/.root-workloads.yaml.un~ (commit 66123b9), matched by .gitignore *.un~, so AC-H3 tracked-ignored-check fails. Cut the untrack leaf (or amend d38a In) so d38a can pass, and order d38a after it. (orchestrator brief BR-20261016-infra-design21)

> see a bug, isolate it, and get it fixed as asap (Design principles 101 item 22)

## Context

Reproduced by infra-design21 in ~/projects/homelab-gitops at origin/main: git ls-files -ci --exclude-standard prints exactly bootstrap/.root-workloads.yaml.un~; git show origin/main:.gitignore line 1 is *.un~. The file is a vim undo file, not a manifest: Argo CD directory sources read only yaml, yml and json, so deleting it deploys nothing. It is its own leaf, not folded into d38a, so d38a keeps its two-file scope (Makefile, .gitignore) and the deletion is reviewed alone. Open homelab-gitops PRs 97, 104, 105, 106 touch argocd-apps, helm, apps/line-ops and docs only: disjoint. d38a depends on this ticket and branches from origin/main after it merges.

## Scope

**In**

- touches: bootstrap/.root-workloads.yaml.un~ (deleted, in jkkelley/homelab-gitops)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path in dotfiles; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: in ~/projects/homelab-gitops, git fetch origin and git worktree add -b fix/THIS-HEX-untrack-un-file <mktemp dir> origin/main (fallback: worktree add fails: fresh git clone into a mktemp dir), never the primary clone working tree
- step: git rm -q -- 'bootstrap/.root-workloads.yaml.un~'; run TP-1 to TP-3 in that worktree; any red case: stop with DESIGN-GAP and its output
- step: commit 'chore: untrack bootstrap/.root-workloads.yaml.un~, ignored by *.un~ (THIS-TICKET-ID)'; push; gh pr create -R jkkelley/homelab-gitops; in dotfiles run work-order.sh check --id THIS-TICKET-ID --code-dir <the worktree>, submit --pr <N>; remove the mktemp worktree with git worktree remove; leave
- tool: cmd:git, cmd:gh, cmd:grep - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any other file in homelab-gitops, .gitignore included: WO-20261016-d38a owns it
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave; a Bump trailer

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* no tracked path is ignored
  - observed `2026-10-16` check: git ls-files -ci --exclude-standard | grep -c . exit 1 output: 0
  - check: `git ls-files -ci --exclude-standard | grep -c .` exit 1 expect /^0$/
- [x] `AC-H2` *(human)* the undo file is out of the index
  - observed `2026-10-16` check: git ls-files 'bootstrap/.root-workloads.yaml.un~' | grep -c . exit 1 output: 0
  - check: `git ls-files 'bootstrap/.root-workloads.yaml.un~' | grep -c .` exit 1 expect /^0$/
- [x] `AC-H3` *(human)* the root app manifest stays tracked
  - observed `2026-10-16` check: git ls-files bootstrap/root-application.yaml | grep -c . exit 0 output: 1
  - check: `git ls-files bootstrap/root-application.yaml | grep -c .` exit 0 expect /^1$/
- [x] `AC-H4` *(human)* the diff holds only the undo file
  - observed `2026-10-16` check: git diff --name-only origin/main...HEAD | grep -vxF 'bootstrap/.root-workloads.yaml.un~' exit 1 output:
  - check: `git diff --name-only origin/main...HEAD | grep -vxF 'bootstrap/.root-workloads.yaml.un~'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the jkkelley/homelab-gitops index on the untrack branch: no tracked path matches .gitignore

**Cases**

- `TP-1`
  - intent: a tracked ignored file makes WO-20261016-d38a AC-H3 make tracked-ignored-check fail, so d38a can never pass
  - command: `git ls-files -ci --exclude-standard | grep -c .`
  - expected: exit 1 and 0
- `TP-2`
  - intent: the vim undo file is gone from the index, not only from the working tree
  - command: `git ls-files bootstrap/.root-workloads.yaml.un~ | grep -c .`
  - expected: exit 1 and 0
- `TP-3`
  - intent: the real Argo CD root app bootstrap/root-application.yaml stays tracked, so the change deploys nothing
  - command: `git ls-files bootstrap/root-application.yaml | grep -c .`
  - expected: exit 0 and 1

**Isolation**

- runtime: podman
- image: `localhost/dotfiles-workflow-test:1`
- build: `make -C claude/workflow image`
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
