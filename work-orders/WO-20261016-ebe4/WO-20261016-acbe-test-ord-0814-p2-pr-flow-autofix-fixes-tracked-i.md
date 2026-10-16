---
{
  "id": "WO-20261016-acbe",
  "slug": "test-ord-0814-p2-pr-flow-autofix-fixes-tracked-i",
  "title": "Test - ORD-0814 P2: pr-flow autofix fixes tracked-ignored and contents lists once per head, leaves content failures to the fix seat",
  "type": "test",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:28:49+00:00",
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
    "WO-20261016-aa46"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow pr-flow-test CASES=\"autofix consume regen-index rerun-stale-red records\"",
      "exit": 0,
      "expect": "ok  autofix"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow pr-flow-lint",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": []
}
---

# WO-20261016-acbe - Test - ORD-0814 P2: pr-flow autofix fixes tracked-ignored and contents lists once per head, leaves content failures to the fix seat

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

The P2 autofix verb is proved on main after its ticket merged.

## Owner words

> ORD-0814 P2: "merge-loop autofix verb for the mechanical ones: md-contents regenerate, tracked-ignored git rm --cached, commit and push to the PR branch, code AUTOFIX on the bus. Headers and Bump lines need content, so those go to a fix seat."

## Context

Evidence 2026-10-16 08:00-08:15Z: PRs 216, 219, 225, 234 red on headers or tracked-ignored-check; 213, 219, 210 red on bump intent. Each red costs a CI round and a seat; every one of those gates is local and fast.

## Scope

**In**

- touches: none in the repository; the tester writes evidence by script to the artifact store only
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-ebe4/README.md
- step: start only after the autofix ticket is done and merged; run from a worktree of origin/main
- step: run TP-1 and TP-2 exactly, capture each command and its output to the artifact store by script, then work-order.sh check ticks the criteria
- tool: make:claude/workflow/Makefile:pr-flow-test and pr-flow-lint - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it

**Out - non-goals**

- changing any file: a failing case is a bug ticket with its reproduction, handed to infra-design (item 22)
- UAT and stable gates: listed in the plan under Out of scope; the line runs them
- any owner notification (item 35)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* autofix and every sweep case beside it pass on main
  - check: `make -C claude/workflow pr-flow-test CASES="autofix consume regen-index rerun-stale-red records"` exit 0 expect /ok autofix/
- [ ] `AC-H2` *(human)* pr-flow scripts stay shellcheck clean on main
  - check: `make -C claude/workflow pr-flow-lint` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the P2 pr-flow sweep autofix verb as merged on main

**Cases**

- `TP-1`
  - intent: the autofix verb and every sweep case beside it hold on main after merge
  - command: `make -C claude/workflow pr-flow-test CASES="autofix consume regen-index rerun-stale-red records"`
  - expected: exit 0; ok for all five, no line matching /^FAIL/
- `TP-2`
  - intent: scripts stay shellcheck clean on main
  - command: `make -C claude/workflow pr-flow-lint`
  - expected: exit 0

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- UAT gate: a throwaway dotfiles PR (branch test/autofix-uat) that force-adds work-orders/INDEX.md goes red on headers; within one sweep interval (60 s) the pr-flow pane prints `jkkelley/dotfiles PR <N> autofix`, the branch gains one commit untracking the path, CI reruns green, and the stream line.pr-flow.event.ci.autofix holds one AUTOFIX record; proof `gh pr view <N> --json commits,statusCheckRollup` and the stream read, written by script to the artifact store; the PR is then closed and its branch deleted by script (item 11); no owner notification (item 35)
- stable gate: the pr-flow pane runs the sweep with autofix for 24 h; rollback is config autofix.mode off, or a git revert of the squash commit

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
