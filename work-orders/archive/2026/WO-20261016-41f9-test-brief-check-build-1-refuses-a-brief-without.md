---
{
  "id": "WO-20261016-41f9",
  "slug": "test-brief-check-build-1-refuses-a-brief-without",
  "title": "Test - brief-check BUILD=1 refuses a brief without a ready work order id (DESIGN-GAP)",
  "type": "test",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:04:30+00:00",
  "parent": "WO-20261016-4b6c",
  "branch": "feat/test-brief-check-build-1-refuses-a-brief-without",
  "pr": 228,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-8c8c"
  ],
  "blocks": []
}
---

# WO-20261016-41f9 - Test - brief-check BUILD=1 refuses a brief without a ready work order id (DESIGN-GAP)

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

Run the filled test plan of WO-20261016-8c8c - brief-check BUILD=1 refuses a brief without a ready work order id (DESIGN-GAP) exactly as written; dev gate (item 34), no owner notification (item 35).

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
  - observed `2026-10-16` make a2a-test exit 0, 30 checks; ok brief-check --build refuses a brief with no work_order (exit 3, DESIGN-GAP); ok ...refuses a draft work order; ok ...accepts a ready work order; ok AC4 brief-check exits 0 on a valid brief
- [x] `AC-H2` *(human)* the run output is written by script to ~/.local/state/zenith/log/YYYY/MM/ with frontmatter (proof: the path)
  - observed `2026-10-16` log written with frontmatter: /home/luna/.local/state/zenith/log/2026/10/20261016-080500-wo-41f9-a2a-test.log

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/bin/brief.sh check --build and the a2a.mk brief-check BUILD=1 wiring

**Cases**

- `TP-1`
  - intent: a build brief with no work order must be refused, or a build seat starts on prose and invents (ORD-0548)
  - command: `make -C claude/workflow -f a2a.mk a2a-test`
  - expected: exit 0; prints `ok  brief-check --build refuses a brief with no work_order (exit 3, DESIGN-GAP)`
- `TP-2`
  - intent: a draft work order is not ready; the seat must not start on it
  - command: `make -C claude/workflow -f a2a.mk a2a-test`
  - expected: exit 0; prints `ok  brief-check --build refuses a draft work order`
- `TP-3`
  - intent: a ready work order must pass, or the gate blocks the whole line
  - command: `make -C claude/workflow -f a2a.mk a2a-test`
  - expected: exit 0; prints `ok  brief-check --build accepts a ready work order`
- `TP-4`
  - intent: design briefs carry no work order and must keep passing without BUILD
  - command: `make -C claude/workflow -f a2a.mk a2a-test`
  - expected: exit 0; prints `ok  AC4 brief-check exits 0 on a valid brief`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full a2a and workflow suites

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
