---
{
  "id": "WO-20261016-2ca4",
  "slug": "spawner-events-seat-up-and-seat-down-publish-sea",
  "title": "Spawner events: seat-up and seat-down publish seat start and end on the bus",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:04:37+00:00",
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
    "WO-20261016-ec34"
  ],
  "blocks": [
    "WO-20261016-95a8",
    "WO-20261016-c2b3"
  ]
}
---

# WO-20261016-2ca4 - Spawner events: seat-up and seat-down publish seat start and end on the bus

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

Owner, 2026-10-16 UTC (item 37): "Remember never hand automation and identitify bottlenecks when things take too long or when any process takes. We need to track time to keep the process from getting stuck. It builds justification". stuck-watch result RS-20261016-stuck-watch left A2A-003: producer work orders for the spawner. herdr-grid.sh publishes nothing, so node-timing cannot see seat durations.

## Scope

**In**

- touches: claude/workflow/bin/herdr-grid.sh
- touches: claude/workflow/tests/unit/test_herdr_grid.sh
- step: source claude/workflow/timing/lib.sh (on main since PR 170) in herdr-grid.sh
- step: cmd_seat_up: after the agent-seen stamp, `tm_event "$line" "$seat" seat "$run" start '{}'` where run is the agent-seen timestamp with ':' and '-' removed; write run into the agent-seen file's second line
- step: seat-down: before closing the pane, `tm_event "$line" "$seat" seat "$run" end '{"rc":0,"duration_s":<now minus agent-seen>,"budget_s":<tm_limit budget_s seat $seat>}'`
- step: a bus that is down only warns (tm_event already does); seat-up and seat-down exit codes do not change
- step: test_herdr_grid.sh: set SW_PUB_CMD to a stub that appends `<subject> <json>` to $T/bus; cases: seat-up publishes line.<line>.event.node.start with kind seat; seat-down publishes .end with duration_s; SW_PUB_CMD=false still exits 0
- step: run `make -C claude/workflow grid`
- tool: make:claude/workflow/Makefile:grid - on main; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute
- tool: path:claude/workflow/timing/lib.sh - on main; fallback: bus down: tm_event warns `WARN bus unreachable` and continues; covered by the down-bus case

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow grid` exits 0 and prints `ok seat-up publishes a seat start event` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* the same run prints `ok seat-down publishes a seat end event with duration_s` and `ok a down bus does not fail seat-up` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

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
