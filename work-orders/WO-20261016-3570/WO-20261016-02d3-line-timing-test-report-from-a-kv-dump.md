---
{
  "id": "WO-20261016-02d3",
  "slug": "line-timing-test-report-from-a-kv-dump",
  "title": "line-timing test: report from a KV dump",
  "type": "test",
  "status": "ready",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:20:16+00:00",
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

# WO-20261016-02d3 - line-timing test: report from a KV dump

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

line-timing.sh has no plan a tester can run

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

claude/workflow/timing/line-timing.sh against a stub KV dump

**Cases**

- `TP-1`
  - intent: the morning report must show durations against budgets and the top 5 bottlenecks (AC8)
  - command: `make -C claude/workflow timing-test CASE=report`
  - expected: exit 0; report artifact path printed, top 5 sorted by overrun

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
