---
{
  "id": "WO-20261016-7d69",
  "slug": "node-timing-tests-slow-and-fast",
  "title": "node-timing tests: slow and fast",
  "type": "test",
  "status": "ready",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:20:15+00:00",
  "parent": "WO-20261016-3570",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Claude seat: lavish prohibited outside firstmate; brief BR-20261016-stuck-watch v2 is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-7d69 - node-timing tests: slow and fast

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

node-timing.sh has no plan a tester can run

## Scope

**In**

_none_

**Out - non-goals**

- live bus

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* every case in the plan passes

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/timing/node-timing.sh against a stub bus, stub KV and stub work-order

**Cases**

- `TP-1`
  - intent: a node over its budget must yield SLOW and a work order, or bottlenecks stay invisible (AC7)
  - command: `make -C claude/workflow timing-test CASE=slow`
  - expected: exit 0; line.t.timing.SLOW with budget and duration, one work order, KV put
- `TP-2`
  - intent: a node inside its budget must stay quiet
  - command: `make -C claude/workflow timing-test CASE=fast`
  - expected: exit 0; KV put, no SLOW, no work order

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- shellcheck of the whole workflow tree and the full workflow suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
