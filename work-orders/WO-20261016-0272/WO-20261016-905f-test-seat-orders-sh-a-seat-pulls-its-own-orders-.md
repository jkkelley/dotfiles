---
{
  "id": "WO-20261016-905f",
  "slug": "test-seat-orders-sh-a-seat-pulls-its-own-orders-",
  "title": "Test - seat-orders.sh: a seat pulls its own orders from line.<line>.seat.<name> in a Claude Code hook",
  "type": "test",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:19:41+00:00",
  "parent": "WO-20261016-0272",
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
    "WO-20261016-1eac"
  ],
  "blocks": []
}
---

# WO-20261016-905f - Test - seat-orders.sh: a seat pulls its own orders from line.<line>.seat.<name> in a Claude Code hook

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

Run the filled test plan of WO-20261016-1eac - seat-orders.sh: a seat pulls its own orders from line.<line>.seat.<name> in a Claude Code hook exactly as written; dev gate (item 34), no owner notification (item 35).

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

claude/workflow/seat-orders/seat-orders.sh with a stub natscli

**Cases**

- `TP-1`
  - intent: orders typed into panes get lost or interrupt a turn (item 26)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/seat-orders/tests/test_seat_orders.sh'`
  - expected: exit 0; prints `ok  prompt event prints each new order once`
- `TP-2`
  - intent: a redelivered order must not run twice
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/seat-orders/tests/test_seat_orders.sh'`
  - expected: exit 0; prints `ok  a repeated order id is dropped`
- `TP-3`
  - intent: a seat about to stop must take its pending orders first
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/seat-orders/tests/test_seat_orders.sh'`
  - expected: exit 0; prints `ok  stop event with a new order blocks with the order as reason`
- `TP-4`
  - intent: fallback path: a down bus must never break the seat (ORD-0558)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/seat-orders/tests/test_seat_orders.sh'`
  - expected: exit 0; prints `ok  bus down exits 0 with SEAT-ORDERS-BUS-DOWN`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- shellcheck and the full workflow suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
