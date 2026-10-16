---
{
  "id": "WO-20261016-218b",
  "slug": "stuck-audit-test-rows-from-a-stream-dump",
  "title": "Stuck-audit test: rows from a stream dump",
  "type": "test",
  "status": "done",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:52:02+00:00",
  "parent": "WO-20261016-3570",
  "branch": "feat/stuck-audit-test-rows-from-a-stream-dump",
  "pr": 170,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Claude seat: lavish is prohibited outside firstmate (~/AGENTS.md owner interaction surface); brief BR-20261016-stuck-watch from the architect is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-7ce0"
  ],
  "blocks": []
}
---

# WO-20261016-218b - Stuck-audit test: rows from a stream dump

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

stuck-audit.sh has no plan a tester can run

## Scope

**In**

_none_

**Out - non-goals**

- live NATS

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* every case in the plan passes
  - observed `2026-10-16` make stuck-watch-test CASE=audit in podman --network=none: pass=2 fail=0 (2026-10-16)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/stuck-watch/stuck-audit.sh against a stub nats stream dump

**Cases**

- `TP-1`
  - intent: the morning audit must list every stuck node with duration and evidence, or the night is unaccounted for
  - command: `make -C claude/workflow stuck-watch-test CASE=audit`
  - expected: exit 0; one row per seat+code with first, last, duration and evidence path

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
