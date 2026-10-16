---
{
  "id": "WO-20261016-4814",
  "slug": "test-ord-0814-p1-pre-push-gates-refuse-a-red-pus",
  "title": "Test - ORD-0814 P1: pre-push gates refuse a red push end to end, seat-up installs the hook, the Before submit box renders",
  "type": "test",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:28:44+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-5222",
    "WO-20261016-b0ed",
    "WO-20261016-377c"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash -c make\\ -f\\ claude/workflow/pre-push/pre-push.mk\\ pre-push-test\\ \\&\\&\\ make\\ -C\\ claude/workflow\\ lease\\ \\&\\&\\ bash\\ claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "ok  treehouse-lease"
    },
    {
      "index": 2,
      "command": "make -f claude/workflow/pre-push/pre-push.mk pre-push-e2e",
      "exit": 0,
      "expect": "E2E-OK"
    }
  ],
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-4814 - Test - ORD-0814 P1: pre-push gates refuse a red push end to end, seat-up installs the hook, the Before submit box renders

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

The P1 units are proved on main after all three merged: each unit suite, then an end-to-end push in podman against the real dotfiles gate list that reproduces the tracked-ignored failure and shows the hook refusing it.

## Owner words

> ORD-0814 P1: "cut the tooling ticket: make pre-push in dotfiles runs every fast gate on the changed files in under 30 s (rolodex-check, md-contents-check, tracked-ignored-check, bump-gate resolve against the PR body draft, a2a-lint, spec-check); seat-up installs it as a git pre-push hook in every seat worktree, and the work-order template adds it as the last checklist box before submit."

## Context

Evidence 2026-10-16 08:00-08:15Z: PRs 216, 219, 225, 234 red on headers or tracked-ignored-check; 213, 219, 210 red on bump intent. Each red costs a CI round and a seat; every one of those gates is local and fast.

## Scope

**In**

- touches: none in the repository; the tester writes evidence by script to the artifact store only
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-ebe4/README.md
- step: start only after the tooling, seat-up and template box tickets are done and merged; run from a worktree of origin/main
- step: run TP-1 and TP-2 exactly, capture each command and its output to the artifact store by script, then work-order.sh check ticks the criteria
- tool: localhost/dotfiles-workflow-test:1 built from claude/workflow/tests/container/Containerfile - fallback: missing: make -C claude/workflow image builds it
- tool: make:claude/workflow/pre-push/pre-push.mk:pre-push-test and pre-push-e2e - land with the tooling ticket; fallback: missing on main: stop with DESIGN-GAP
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it

**Out - non-goals**

- changing any file: a failing case is a bug ticket with its reproduction, handed to infra-design (item 22)
- UAT and stable gates: listed in the plan under Out of scope; the line runs them
- any owner notification (item 35)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* each P1 unit suite passes on main
  - check: `bash -c make\ -f\ claude/workflow/pre-push/pre-push.mk\ pre-push-test\ \&\&\ make\ -C\ claude/workflow\ lease\ \&\&\ bash\ claude/skills/work-order/testing/run-tests.sh` exit 0 expect /ok treehouse-lease/
- [ ] `AC-H2` *(human)* the real gate list refuses a tracked-ignored push and passes the fixed one
  - check: `make -f claude/workflow/pre-push/pre-push.mk pre-push-e2e` exit 0 expect /E2E-OK/

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the P1 pre-push gates as merged on main: pre-push.sh with the real dotfiles config, the seat-up hook install and the ticket Before submit box

**Cases**

- `TP-1`
  - intent: each P1 unit's own suite holds on main after all three merged
  - command: `make -f claude/workflow/pre-push/pre-push.mk pre-push-test && make -C claude/workflow lease && bash claude/skills/work-order/testing/run-tests.sh 300-before-submit-box`
  - expected: exit 0; `pre-push: pass=N fail=0`, `ok  treehouse-lease`, case 300 passes
- `TP-2`
  - intent: the real dotfiles gate list refuses the exact failure that turned PRs 216, 219, 225 and 234 red: a tracked path .gitignore excludes
  - command: `make -f claude/workflow/pre-push/pre-push.mk pre-push-e2e`
  - expected: exit 0; last line `E2E-OK`; the red push is refused naming tracked-ignored-check; md-contents-check prints PREPUSH-SKIP ENV-MISSING (no npx in the image) and does not block the green push

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- UAT gate: the next seat the line spawns has the hook (`cat $(git -C <seat worktree> rev-parse --path-format=absolute --git-path hooks/pre-push)` shows the managed-by line) and its first push prints PREPUSH-OK in its pane; proof is the pane read, written by script to the artifact store; no owner notification (item 35)
- stable gate: 24 h of seat pushes; the scripted rollback is `make pre-push-uninstall REPO=<worktree>` per seat and a git revert of the spawn step

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` draft by design: approve refuses tool_missing (pre-push-test, pre-push-e2e) until WO-20261016-5222 merges; then work-order.sh approve --id WO-20261016-4814 --no-lavish --reason 'tools on main'

## Outcome

_Written by `work-order done`. Empty until then._
