---
{
  "id": "WO-20261016-c399",
  "slug": "test-dag-author-node-new-one-verb-writes-node-bu",
  "title": "Test - dag-author node-new: one verb writes node, bundle stubs, mermaid, spec node list and a migration plan",
  "type": "test",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:08:12+00:00",
  "parent": "WO-20261016-41d0",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-a215"
  ],
  "blocks": []
}
---

# WO-20261016-c399 - Test - dag-author node-new: one verb writes node, bundle stubs, mermaid, spec node list and a migration plan

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

Run the filled test plan of WO-20261016-a215 - dag-author node-new: one verb writes node, bundle stubs, mermaid, spec node list and a migration plan exactly as written; dev gate (item 34), no owner notification (item 35).

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

claude/workflow/dag/bin/dag-author.sh node-new and its regeneration, on a temp copy

**Cases**

- `TP-1`
  - intent: a plan must be shown before apply (item 40)
  - command: `make -C claude/workflow dag-test CASE=author-new`
  - expected: exit 0; prints `ok  node-new without APPLY writes nothing and prints the plan`
- `TP-2`
  - intent: one verb, the whole nine yards
  - command: `make -C claude/workflow dag-test CASE=author-new`
  - expected: exit 0; prints `ok  node-new APPLY writes node, bundle stubs, mermaid, spec list, manifest and migration plan in one run`
- `TP-3`
  - intent: migration is the test of the design (item 16)
  - command: `make -C claude/workflow dag-test CASE=author-new`
  - expected: exit 0; prints `ok  a 1.0.0 run reaches 1.1.0 by dag-migrate and back by rollback`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full dag suite and spec-check

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
