---
{
  "id": "WO-20261016-e4b4",
  "slug": "root-makefile-includes-claude-workflow-pre-push-",
  "title": "root Makefile includes claude/workflow/pre-push/pre-push.mk, so make pre-push REPO= runs from the dotfiles root",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:28:15+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design6 cut for ORD-0814 P1 P2; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-5222",
    "WO-20261016-df39"
  ],
  "blocks": [
    "WO-20261016-377c"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -n pre-push REPO=.",
      "exit": 0,
      "expect": "pre-push.sh run --repo"
    },
    {
      "index": 2,
      "command": "make -n tracked-ignored-check md-contents-check spec-check a2a-lint",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "make -s pre-push REPO=.",
      "exit": 0,
      "expect": "PREPUSH-OK"
    },
    {
      "index": 4,
      "command": "bash -c git\\ diff\\ origin/main...HEAD\\ --\\ Makefile\\ \\|\\ grep\\ -c\\ \\'\\^+include\\ claude/workflow/pre-push/pre-push.mk\\$\\'",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 5,
      "command": "bash -c \\!\\ git\\ diff\\ --name-only\\ origin/main...HEAD\\ \\|\\ grep\\ -vE\\ \\'\\^\\(work-orders/\\|Makefile\\)\\$\\'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [
    "make:pre-push"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-e4b4 - root Makefile includes claude/workflow/pre-push/pre-push.mk, so make pre-push REPO= runs from the dotfiles root

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

The order names the command make pre-push in dotfiles; the tooling ticket ships the targets in claude/workflow/pre-push/pre-push.mk. This ticket adds the one include line to the root Makefile.

## Owner words

> ORD-0814 P1: "cut the tooling ticket: make pre-push in dotfiles runs every fast gate on the changed files in under 30 s (rolodex-check, md-contents-check, tracked-ignored-check, bump-gate resolve against the PR body draft, a2a-lint, spec-check); seat-up installs it as a git pre-push hook in every seat worktree, and the work-order template adds it as the last checklist box before submit."

## Context

The root Makefile is touched by the ready chain WO-20261016-1c04, 2ffe, 6630, f5dd, df39 (each depends on the one before), so this ticket waits on df39, the tail, and on the tooling ticket (item 19: never the same file at once).

## Scope

**In**

- touches: Makefile (one line)
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-ebe4/README.md
- step: start only after the tooling ticket and WO-20261016-df39 are done and merged (work-order.sh next lists this ticket only then); branch from origin/main
- step: Makefile: after the line "include claude/workflow/a2a-guard/a2a-guard.mk" add exactly the line "include claude/workflow/pre-push/pre-push.mk"; nothing else changes
- step: run only TP-1, TP-2 and the AC checks; CI runs the rest
- tool: path:claude/workflow/pre-push/pre-push.mk - lands with the tooling ticket; fallback: missing on main: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it

**Out - non-goals**

- any root target other than the include line
- claude/workflow/Makefile: pre-push is a root concern

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* make pre-push resolves from the root
  - check: `make -n pre-push REPO=.` exit 0 expect /pre-push.sh run --repo/
- [ ] `AC-H2` *(human)* the include breaks no existing root target
  - check: `make -n tracked-ignored-check md-contents-check spec-check a2a-lint` exit 0
- [ ] `AC-H3` *(human)* the real gates pass from the root on the host
  - check: `make -s pre-push REPO=.` exit 0 expect /PREPUSH-OK/
- [ ] `AC-H4` *(human)* the include line is added exactly once
  - check: `bash -c git\ diff\ origin/main...HEAD\ --\ Makefile\ \|\ grep\ -c\ \'\^+include\ claude/workflow/pre-push/pre-push.mk\$\'` exit 0 expect /^1$/
- [ ] `AC-H5` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c \!\ git\ diff\ --name-only\ origin/main...HEAD\ \|\ grep\ -vE\ \'\^\(work-orders/\|Makefile\)\$\'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the root Makefile include of claude/workflow/pre-push/pre-push.mk

**Cases**

- `TP-1`
  - intent: `make pre-push` from the dotfiles root is the name every seat, box and hook uses (order ORD-0814 P1)
  - command: `make -n pre-push REPO=.`
  - expected: exit 0; prints a line containing `pre-push.sh run --repo`
- `TP-2`
  - intent: the include breaks no existing root target
  - command: `make -n tracked-ignored-check md-contents-check spec-check a2a-lint`
  - expected: exit 0

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- every root target's own suite: CI runs it

## Assumptions

1. fallback: until this lands, make -f claude/workflow/pre-push/pre-push.mk pre-push REPO= is the same target; the hook calls the .mk by path and never needs this include

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
