---
{
  "id": "WO-20261016-2342",
  "slug": "test-dag-author-edit-move-rm-step-add-and-prio-t",
  "title": "Test - dag-author edit, move, rm, step-add and prio: the rest of the authoring verbs",
  "type": "test",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:08:20+00:00",
  "parent": "WO-20261016-41d0",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-6082"
  ],
  "blocks": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-2342 - Test - dag-author edit, move, rm, step-add and prio: the rest of the authoring verbs

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

Run the filled test plan of WO-20261016-6082 - dag-author edit, move, rm, step-add and prio: the rest of the authoring verbs exactly as written; dev gate (item 34), no owner notification (item 35).

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

dag-author.sh node-edit node-move node-rm step-add node-prio on a temp copy

**Cases**

- `TP-1`
  - intent: every authoring change migrates live runs and rolls back (item 40)
  - command: `make -C claude/workflow dag-test CASE=author-verbs`
  - expected: exit 0; five `ok  <verb> plan, apply, migrate and rollback` lines
- `TP-2`
  - intent: a cycle makes next permanently empty
  - command: `make -C claude/workflow dag-test CASE=author-verbs`
  - expected: exit 0; prints `ok  node-move into a cycle is refused DG-CYCLE`
- `TP-3`
  - intent: reprioritised nodes must run first
  - command: `make -C claude/workflow dag-test CASE=author-verbs`
  - expected: exit 0; prints `ok  node-prio reorders the ready set from dag-plan`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full dag suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
