---
{
  "id": "WO-20261016-f8e2",
  "slug": "a2a-004-status-code-map-test",
  "title": "A2A-004 status code map test",
  "type": "test",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:44:57+00:00",
  "parent": "WO-20261016-4e8e",
  "branch": "feat/a2a-004-status-code-map-test",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Claude seat: lavish prohibited for Claude runtime; brief BR-20261016-sop-code is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-f8e2 - A2A-004 status code map test

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

Nothing asserts the a2a status code map lists the SOP-breach code

## Scope

**In**

_none_

**Out - non-goals**

- full workflow suite - CI covers it

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* every case in the plan passes
  - observed `2026-10-16` make -C claude/workflow -f a2a.mk a2a-test: 26 checks, exit 0, incl. 'ok the status code map lists A2A-001 to A2A-004' and 'ok a brief carrying A2A-004 is valid'

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

The a2a status code map in claude/workflow/templates/a2a/README.md and the status_code pattern in claude/workflow/schemas/brief.schema.json.

**Cases**

- `TP-1`
  - intent: an orchestrator recording an SOP breach (Design principles 101 item 31) finds no code for it if A2A-004 is missing from the map, and falls back to prose
  - command: `make -C claude/workflow -f a2a.mk a2a-test`
  - expected: exit 0; output holds "ok  the status code map lists A2A-001 to A2A-004" and "ok  a brief carrying A2A-004 is valid"

**Isolation**

- runtime: podman
- image: `docker.io/library/debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- lint and the full workflow suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
