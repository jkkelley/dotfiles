---
{
  "id": "WO-20261016-5597",
  "slug": "deadman-tests-stale-heartbeat-bus-down-fresh",
  "title": "Deadman tests: stale heartbeat, bus down, fresh",
  "type": "test",
  "status": "in-progress",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:52:01+00:00",
  "parent": "WO-20261016-3570",
  "branch": "feat/deadman-tests-stale-heartbeat-bus-down-fresh",
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
    "WO-20261016-2d3e"
  ],
  "blocks": []
}
---

# WO-20261016-5597 - Deadman tests: stale heartbeat, bus down, fresh

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

deadman.sh has no plan a tester can run

## Scope

**In**

_none_

**Out - non-goals**

- live systemd

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* every case in the plan passes

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/stuck-watch/deadman.sh against a stub nats and stub ntfy

**Cases**

- `TP-1`
  - intent: a dead stuck-watch must still reach the phone, or a silent watcher reads as a healthy line (AC2)
  - command: `make -C claude/workflow stuck-watch-test CASE=deadman-stale`
  - expected: exit 0; heartbeat 4 min old gives one priority high POST titled stuck-watch dead
- `TP-2`
  - intent: a down bus must also page, since the watcher cannot publish through it
  - command: `make -C claude/workflow stuck-watch-test CASE=deadman-bus-down`
  - expected: exit 0; unreachable nats gives one priority high POST
- `TP-3`
  - intent: a fresh heartbeat must stay silent
  - command: `make -C claude/workflow stuck-watch-test CASE=deadman-fresh`
  - expected: exit 0; zero POSTs

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
