---
{
  "id": "WO-20261016-d572",
  "slug": "test-a2a-deliver-as-fallback-only-dedup-by-order",
  "title": "Test - a2a-deliver as fallback only: dedup by order id, never type into a pane whose spinner is active",
  "type": "test",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:20:01+00:00",
  "parent": "WO-20261016-e9d4",
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
    "WO-20261016-1cd0"
  ],
  "blocks": []
}
---

# WO-20261016-d572 - Test - a2a-deliver as fallback only: dedup by order id, never type into a pane whose spinner is active

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

Run the filled test plan of WO-20261016-1cd0 - a2a-deliver as fallback only: dedup by order id, never type into a pane whose spinner is active exactly as written; dev gate (item 34), no owner notification (item 35).

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

a2a-deliver.sh spinner hold and order-id dedup against fake-herdr

**Cases**

- `TP-1`
  - intent: typing into a working seat interrupts its turn (ORD-0606 D1)
  - command: `make -C claude/workflow a2a-guard-test`
  - expected: exit 0; prints `ok  a pane with an active spinner is held`
- `TP-2`
  - intent: an order delivered by bus and by fallback must run once
  - command: `make -C claude/workflow a2a-guard-test`
  - expected: exit 0; prints `ok  a duplicate order id is never typed`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- a2a-lint and the full workflow suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
