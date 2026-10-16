---
{
  "id": "WO-20261016-7ea5",
  "slug": "test-plan-template-a-podman-command-that-runs-gi",
  "title": "test-plan template: a podman command that runs git mounts the git common dir read-only, so plans pass from a worktree",
  "type": "chore",
  "status": "ready",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T12:51:36+00:00",
  "parent": "WO-20261016-0272",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow test-plan 2>&1 | grep -F 'ok  test-plan: template, parser and schema agree'",
      "exit": 0,
      "expect": null
    },
    {
      "index": 2,
      "command": "grep -cF -- '--git-common-dir):$(git rev-parse --path-format=absolute --git-common-dir):ro' claude/workflow/templates/test-plan.md",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 3,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/templates/test-plan\\.md)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-7ea5 - test-plan template: a podman command that runs git mounts the git common dir read-only, so plans pass from a worktree

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

Design seats copy claude/workflow/templates/test-plan.md and write podman commands with -v "$PWD:/work:Z" only. From a git worktree .git is a file pointing at the primary clone's git common dir, which is not mounted, so any git call in the container fails with 'fatal: not a git repository'; WO-20261016-436e's TP-1 failed this way and its tester stopped with DESIGN-GAP. The template that writes the plans is where the fix belongs, so the next plan does not repeat it.

## Owner words

> cut every item as ready work orders with work-order.sh, fixing the generator or template that writes the scope AC (orchestrator brief BR-20261016-infra-design23)

> everything portable, generic, templated out so everybody gets it, NEVER REINVENT THE WHEEL (Design principles 101 item 4)

## Context

Proven by infra-design23 on origin/main 93dcff5: with the edit below, make -C claude/workflow test-plan exits 0 and ends 'ok test-plan: template, parser and schema agree; unfilled, unpinned and caseless plans refused' (edit reverted). The mount itself was proven on the WO-20261016-436e command: with it, false and exit 0 from a worktree; without it, exit 2 and 'fatal: not a git repository'.

Edit: in claude/workflow/templates/test-plan.md, directly after the line that starts '_A locally built image uses' under **Isolation**, insert one blank line and then this one line verbatim:

_A command that runs git inside the container also mounts the git common dir at its own path, read-only: `-v "$(git rev-parse --path-format=absolute --git-common-dir):$(git rev-parse --path-format=absolute --git-common-dir):ro"`. In a worktree `.git` is a file pointing there, so `-v "$PWD:/work:Z"` alone fails with `fatal: not a git repository` (WO-20261016-436e, DESIGN-GAP)._

## Scope

**In**

- touches: claude/workflow/templates/test-plan.md (one inserted line under **Isolation**, and its blank line)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone; bash claude/skills/work-order/scripts/work-order.sh start --id THIS-TICKET-ID
- step: apply the Edit from Context verbatim; run TP-1 and TP-2; then bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID
- step: commit 'docs(workflow): test-plan template mounts the git common dir' with this ticket id; no Bump trailer; push, gh pr create, submit --pr <N>, done on the branch, push, leave
- tool: make:claude/workflow/Makefile:test-plan - on main; fallback: the image fails to build: stop with ENV-MISSING podman
- tool: cmd:git, cmd:gh, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- rewriting existing tickets' test plans: each is recut by a design seat when it fails
- claude/workflow/templates/scope-ac.md, close-successor.md or any other file: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* template, parser and schema still agree
  - check: `make -C claude/workflow test-plan 2>&1 | grep -F 'ok test-plan: template, parser and schema agree'` exit 0
- [ ] `AC-H2` *(human)* the template names the git common dir mount once
  - check: `grep -cF -- '--git-common-dir):$(git rev-parse --path-format=absolute --git-common-dir):ro' claude/workflow/templates/test-plan.md` exit 0 expect /^1$/
- [ ] `AC-H3` *(human)* the diff holds only the template and work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/templates/test-plan\.md)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/templates/test-plan.md, the Isolation guidance line for git inside the container

**Cases**

- `TP-1`
  - intent: the new guidance line must not break the template-parser-schema agreement every test ticket relies on
  - command: `make -C claude/workflow test-plan`
  - expected: exit 0; last ok line `ok  test-plan: template, parser and schema agree; unfilled, unpinned and caseless plans refused`
- `TP-2`
  - intent: the guidance names the exact mount, so a design seat copies it instead of rediscovering it
  - command: `grep -cF -- '--git-common-dir):$(git rev-parse --path-format=absolute --git-common-dir):ro' claude/workflow/templates/test-plan.md`
  - expected: exit 0 and 1

**Isolation**

_A locally built image uses `- image: localhost/<name>:<tag>` plus `- build: <command>` and `- containerfile: <path>` lines, never a localhost digest (RR-orch-18)._

- runtime: podman
- image: `localhost/dotfiles-workflow-test:1`
- build: `make -C claude/workflow image`
- containerfile: claude/workflow/tests/container/Containerfile

**Out of scope - CI covers**

- markdown lint, contents check and the full workflow suite (Design principles 101 item 6)

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
