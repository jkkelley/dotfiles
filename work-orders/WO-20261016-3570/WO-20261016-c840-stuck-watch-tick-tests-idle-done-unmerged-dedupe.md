---
{
  "id": "WO-20261016-c840",
  "slug": "stuck-watch-tick-tests-idle-done-unmerged-dedupe",
  "title": "Stuck-watch tick tests: idle, done-unmerged, dedupe, no-leak",
  "type": "test",
  "status": "ready",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:51:59+00:00",
  "parent": "WO-20261016-3570",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Claude seat: lavish is prohibited outside firstmate (~/AGENTS.md owner interaction surface); brief BR-20261016-stuck-watch from the architect is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-230f"
  ],
  "blocks": []
}
---

# WO-20261016-c840 - Stuck-watch tick tests: idle, done-unmerged, dedupe, no-leak

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

stuck-watch.sh has no plan a tester can run

## Scope

**In**

_none_

**Out - non-goals**

- live herdr

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* every case in the plan passes

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/stuck-watch/stuck-watch.sh tick against stub herdr, stub gh, stub nats and stub ntfy

**Cases**

- `TP-1`
  - intent: an idle seat with no result file must reach the bus and the phone, or the owner never learns a seat stalled (AC1)
  - command: `make -C claude/workflow stuck-watch-test CASE=idle`
  - expected: exit 0; stub nats saw line.t.stuck.STK-001 and stub ntfy saw one POST
- `TP-2`
  - intent: a done claim with an unmerged PR must be coded, not trusted (AC3)
  - command: `make -C claude/workflow stuck-watch-test CASE=done-unmerged`
  - expected: exit 0; STK-005 published with gh state OPEN as evidence
- `TP-3`
  - intent: the same condition twice inside 30 min must ring the phone once, or the owner mutes it (AC4)
  - command: `make -C claude/workflow stuck-watch-test CASE=dedupe`
  - expected: exit 0; two ticks, two bus messages, exactly one ntfy POST
- `TP-4`
  - intent: the topic is a secret and must never appear in output
  - command: `make -C claude/workflow stuck-watch-test CASE=no-leak`
  - expected: exit 0; canary topic absent from stdout, stderr and logs

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
