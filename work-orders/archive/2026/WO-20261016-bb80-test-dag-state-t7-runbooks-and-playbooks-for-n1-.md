---
{
  "id": "WO-20261016-bb80",
  "slug": "test-dag-state-t7-runbooks-and-playbooks-for-n1-",
  "title": "Test - dag-state T7 - Runbooks and playbooks for N1 to N10",
  "type": "test",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:07:23+00:00",
  "parent": "WO-20261016-41d0",
  "branch": "feat/bb80-test-dag-state-t7-runbooks-and-playbooks-for-n1-",
  "pr": 365,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-1e26"
  ],
  "blocks": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-bb80 - Test - dag-state T7 - Runbooks and playbooks for N1 to N10

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

Run the filled test plan of WO-20261016-1e26 - dag-state T7 - Runbooks and playbooks for N1 to N10 exactly as written; dev gate (item 34), no owner notification (item 35).

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

- [x] `AC-H1` *(human)* every case of the plan prints its expected result (proof: the run output pasted by work-order.sh evidence)
  - observed `2026-10-16` TP-1 make md-contents-check in podman localhost/dotfiles-workflow-test:1: exit 0, 'md-contents: nothing in scope'
- [x] `AC-H2` *(human)* the run output is written by script to ~/.local/state/zenith/log/YYYY/MM/ with frontmatter (proof: the path)
  - observed `2026-10-16` /home/luna/.local/state/zenith/log/2026/10/20261016-124500-wo-bb80-tp1-md-contents-check.md

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/runbooks/RB-dag-intake.md, claude/workflow/dag/playbooks/PB-intake.md built to <bundles>

**Cases**

- `TP-1`
  - intent: the DAG is the source; a build that drifts from docs/design/dag-state.spec.xml is rejected (item 20)
  - command: `make md-contents-check`
  - expected: exit 0

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full dag and workflow suites

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
