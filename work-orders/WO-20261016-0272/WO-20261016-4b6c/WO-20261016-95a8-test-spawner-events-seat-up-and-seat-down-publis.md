---
{
  "id": "WO-20261016-95a8",
  "slug": "test-spawner-events-seat-up-and-seat-down-publis",
  "title": "Test - Spawner events: seat-up and seat-down publish seat start and end on the bus",
  "type": "test",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:04:39+00:00",
  "parent": "WO-20261016-4b6c",
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
  "depends_on": [
    "WO-20261016-2ca4"
  ],
  "blocks": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-95a8 - Test - Spawner events: seat-up and seat-down publish seat start and end on the bus

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

Run the filled test plan of WO-20261016-2ca4 - Spawner events: seat-up and seat-down publish seat start and end on the bus exactly as written; dev gate (item 34), no owner notification (item 35).

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

- [ ] `AC-H1` *(human)* every case of the plan prints its expected result (proof: the run output pasted by work-order.sh evidence)
- [ ] `AC-H2` *(human)* the run output is written by script to ~/.local/state/zenith/log/YYYY/MM/ with frontmatter (proof: the path)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

herdr-grid.sh seat start/end events via tm_event, bus stubbed with SW_PUB_CMD

**Cases**

- `TP-1`
  - intent: seat durations must reach node-timing, or slow seats stay invisible (item 37)
  - command: `make -C claude/workflow grid`
  - expected: exit 0; prints `ok  seat-up publishes a seat start event`
- `TP-2`
  - intent: the end event carries the duration the SLOW judgement needs
  - command: `make -C claude/workflow grid`
  - expected: exit 0; prints `ok  seat-down publishes a seat end event with duration_s`
- `TP-3`
  - intent: a down bus must never stop a seat from starting
  - command: `make -C claude/workflow grid`
  - expected: exit 0; prints `ok  a down bus does not fail seat-up`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full workflow suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
