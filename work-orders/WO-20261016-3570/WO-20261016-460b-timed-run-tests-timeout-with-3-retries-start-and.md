---
{
  "id": "WO-20261016-460b",
  "slug": "timed-run-tests-timeout-with-3-retries-start-and",
  "title": "timed-run tests: timeout with 3 retries, start and end",
  "type": "test",
  "status": "in-progress",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:20:13+00:00",
  "parent": "WO-20261016-3570",
  "branch": "feat/timed-run-tests-timeout-with-3-retries-start-and",
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

# WO-20261016-460b - timed-run tests: timeout with 3 retries, start and end

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

timed-run.sh has no plan a tester can run

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

claude/workflow/bin/timed-run.sh against a stub bus and a stub work-order

**Cases**

- `TP-1`
  - intent: a step past its timeout must be stopped, retried 3 times and coded, or a hung step stalls the line forever (AC9)
  - command: `make -C claude/workflow timing-test CASE=timeout`
  - expected: exit 0; 3 attempts, line.t.timing.TIMEOUT on the bus, one work order filed
- `TP-2`
  - intent: every run must emit start and end, or durations cannot be measured (item 37)
  - command: `make -C claude/workflow timing-test CASE=start-end`
  - expected: exit 0; line.t.event.node.start and .end with duration_s

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
