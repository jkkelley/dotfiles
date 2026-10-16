---
{
  "id": "WO-20261016-e709",
  "slug": "test-ci-producer-ci-events-sh-publishes-github-a",
  "title": "Test - CI producer: ci-events.sh publishes GitHub Actions run start and end to the bus",
  "type": "test",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:05:04+00:00",
  "parent": "WO-20261016-af17",
  "branch": "feat/test-ci-producer-ci-events-sh-publishes-github-a",
  "pr": 230,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-e832"
  ],
  "blocks": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-e709 - Test - CI producer: ci-events.sh publishes GitHub Actions run start and end to the bus

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

Run the filled test plan of WO-20261016-e832 - CI producer: ci-events.sh publishes GitHub Actions run start and end to the bus exactly as written; dev gate (item 34), no owner notification (item 35).

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
  - observed `2026-10-16` make -C claude/workflow timing-test CASE=ci-events exit 0, pass=4 fail=0: ok a new run publishes ci start once; ok a completed run publishes ci end with duration_s once; ok ci-events is idempotent (plan text has 2 spaces after ok, output has 3; same words)
- [x] `AC-H2` *(human)* the run output is written by script to ~/.local/state/zenith/log/YYYY/MM/ with frontmatter (proof: the path)
  - observed `2026-10-16` run output written by artifact.sh with frontmatter: /home/luna/.local/state/zenith/log/2026/10/20261016-080140-wo-e709-ci-events-test.log

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/timing/ci-events.sh against a stub gh and a stub bus

**Cases**

- `TP-1`
  - intent: CI durations must reach node-timing or slow CI stays invisible (item 1, 37)
  - command: `make -C claude/workflow timing-test CASE=ci-events`
  - expected: exit 0; prints `ok  a new run publishes ci start once`
- `TP-2`
  - intent: the end event carries duration_s for SLOW
  - command: `make -C claude/workflow timing-test CASE=ci-events`
  - expected: exit 0; prints `ok  a completed run publishes ci end with duration_s once`
- `TP-3`
  - intent: a re-run must not double count
  - command: `make -C claude/workflow timing-test CASE=ci-events`
  - expected: exit 0; prints `ok  ci-events is idempotent`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full timing suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
