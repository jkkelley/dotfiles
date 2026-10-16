---
{
  "id": "WO-20261016-9682",
  "slug": "a2a-guard-dev-and-uat-gates",
  "title": "a2a-guard dev and UAT gates",
  "type": "test",
  "status": "in-progress",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:19:52+00:00",
  "parent": "WO-20261016-916d",
  "branch": "feat/a2a-guard-dev-and-uat-gates",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Claude seat: owner rule bars Lavish for Claude runtimes; brief BR-20261016-a2a-guard from the architect is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-e15b",
    "WO-20261016-2aef"
  ],
  "blocks": []
}
---

# WO-20261016-9682 - a2a-guard dev and UAT gates

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

AC1-AC4 need scripted proof

## Scope

**In**

- claude/workflow/a2a-guard/tests/test_a2a_guard.sh claude/workflow/a2a-guard/tests/fake-herdr claude/workflow/a2a-guard/uat.sh claude/workflow/a2a-guard/a2a-guard.mk Makefile

**Out - non-goals**

- stable promotion by hand

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* every case in the plan passes

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/a2a-guard: a2a-send.sh, a2a-deliver.sh, a2a-lint.sh against a fake herdr and a fake nats

**Cases**

- `TP-1`
  - intent: an ack-only order typed into a seat wastes its turn; it must never be queued (AC2)
  - command: `make a2a-guard-test`
  - expected: exit 0; output line "ok  AC2 ack-only order refused with A2A-ACK-REFUSED (exit 3)"
- `TP-2`
  - intent: two orders in one second overwrote each other (P3); each send must own its own store file (AC3)
  - command: `make a2a-guard-test`
  - expected: exit 0; output line "ok  AC3 two sends in one second, two distinct artifact paths"
- `TP-3`
  - intent: an order typed into a working pane sat queued 18-25 minutes (P1); delivery waits for idle and sends one line (AC1, dev half)
  - command: `make a2a-guard-test`
  - expected: exit 0; "ok  busy seat: nothing typed" and "ok  idle seat: exactly one prompt carrying both pointers"
- `TP-4`
  - intent: a new raw herdr pane send-text bypasses the guard; CI must fail it (AC4)
  - command: `make a2a-guard-test`
  - expected: exit 0; "ok  AC4 lint fails a raw send-text (exit 1)"
- `TP-5`
  - intent: the UAT gate observes AC1 on the real herdr with a test seat, no owner notification
  - command: `make a2a-uat LINE=uat`
  - expected: exit 0; status before working, nothing delivered; status after idle, exactly one delivered line

**Isolation**

- runtime: podman
- image: `localhost/dotfiles-workflow-test@sha256:9628e5d55f7191751d4ce23367dd56bf8de9b57584d84ea1d3e4ed89afba1ef8` (localhost/dotfiles-workflow-test:1, built from debian:bookworm-slim by digest)

**Out of scope - CI covers**

- the full claude/workflow suite and shellcheck of every script

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` Built on feat/a2a-guard, the brief's one branch for this epic; the per-ticket branch start minted was empty and removed.

## Outcome

_Written by `work-order done`. Empty until then._
