---
{
  "id": "WO-20261016-e77c",
  "slug": "test-line-sweep-raises-lw-alert-discovery-for-an",
  "title": "Test - line-sweep raises LW-ALERT-DISCOVERY for an unlabelled claude pane in a line workspace",
  "type": "test",
  "status": "cancelled",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:23:15+00:00",
  "parent": "WO-20261016-4b6c",
  "branch": null,
  "pr": null,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-9b54"
  ],
  "blocks": [],
  "superseded_by": "WO-20261016-d358"
}
---

# WO-20261016-e77c - Test - line-sweep raises LW-ALERT-DISCOVERY for an unlabelled claude pane in a line workspace

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

Run the filled test plan of WO-20261016-9b54 - line-sweep raises LW-ALERT-DISCOVERY for an unlabelled claude pane in a line workspace exactly as written; dev gate (item 34), no owner notification (item 35).

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

line-watch.sh discovery alert against the stub herdr

**Cases**

- `TP-1`
  - intent: a seat outside the grid is unwatched and unpaid-for (ORD-0606 D4)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
  - expected: exit 0; prints `ok  an unlabelled claude pane raises LW-ALERT-DISCOVERY once`
- `TP-2`
  - intent: fallback path: a labelled or named pane raises nothing
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
  - expected: exit 0; prints `ok  a labelled seat raises no discovery alert`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full workflow suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

Cancelled `2026-10-16` - nothing shipped.

- reason: superseded by the combined ticket's test sibling
- superseded by: `WO-20261016-d358`

No branch, no PR and no merge commit exist for this work order.

