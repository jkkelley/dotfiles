---
{
  "id": "WO-20261016-cc22",
  "slug": "test-pane-look-monitor-queued-stale-and-idle-sta",
  "title": "Test - pane-look monitor: QUEUED-STALE and IDLE-STALE judged from the pane spinner, never agent_status",
  "type": "test",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:04:50+00:00",
  "parent": "WO-20261016-af17",
  "branch": "feat/cc22-test-pane-look-monitor-queued-stale-and-idle-sta",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-cc95"
  ],
  "blocks": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-cc22 - Test - pane-look monitor: QUEUED-STALE and IDLE-STALE judged from the pane spinner, never agent_status

## Contents

- Problem
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

Run the filled test plan of WO-20261016-cc95 - pane-look monitor: QUEUED-STALE and IDLE-STALE judged from the pane spinner, never agent_status exactly as written; dev gate (item 34), no owner notification (item 35).

## Scope

**In**

_none_

**Out - non-goals**

- writing or changing code: a failing case goes back as A2A-003 with its output
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* every case of the plan prints its expected result (proof: the run output pasted by work-order.sh evidence)
  - observed `2026-10-16` TP-1..TP-4 all ok, pass=1/3/1/1 fail=0; output in /home/luna/.local/state/zenith/log/2026/10/20261016-124143-wo-cc22-pane-look-test.log
- [x] `AC-H2` *(human)* the run output is written by script to ~/.local/state/zenith/log/YYYY/MM/ with frontmatter (proof: the path)
  - observed `2026-10-16` /home/luna/.local/state/zenith/log/2026/10/20261016-124143-wo-cc22-pane-look-test.log

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/stuck-watch/pane-look.sh against fixture panes, stub herdr and stub bus

**Cases**

- `TP-1`
  - intent: agent_status lies mid-turn (05:26Z sweep-build); the spinner timer is the truth (ORD-0550 O3)
  - command: `make -C claude/workflow pane-look-test CASE=working`
  - expected: exit 0; prints `ok  working judged from a moving spinner timer while agent_status says idle`
- `TP-2`
  - intent: queued orders older than 5 min are a stalled line
  - command: `make -C claude/workflow pane-look-test CASE=queued`
  - expected: exit 0; prints `ok  QUEUED-STALE after 300s of unchanged queued input`
- `TP-3`
  - intent: an idle seat with no result is stuck
  - command: `make -C claude/workflow pane-look-test CASE=idle`
  - expected: exit 0; prints `ok  IDLE-STALE after 60s idle with no result file`
- `TP-4`
  - intent: a finished seat is not stuck
  - command: `make -C claude/workflow pane-look-test CASE=done`
  - expected: exit 0; prints `ok  no IDLE-STALE when the result file exists`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- shellcheck and the full stuck-watch suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
