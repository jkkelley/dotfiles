---
{
  "id": "WO-20261016-e832",
  "slug": "ci-producer-ci-events-sh-publishes-github-action",
  "title": "CI producer: ci-events.sh publishes GitHub Actions run start and end to the bus",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:05:01+00:00",
  "parent": "WO-20261016-af17",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-e709",
    "WO-20261016-ff68"
  ]
}
---

# WO-20261016-e832 - CI producer: ci-events.sh publishes GitHub Actions run start and end to the bus

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

Item 37: every CI run records its start and end on the bus. GitHub runners cannot reach the local NATS, so a local poller turns `gh run list` into events. stuck-watch result A2A-003: producer work order for CI.

## Scope

**In**

- touches: claude/workflow/timing/ci-events.sh
- touches: claude/workflow/timing/tests/test_ci_events.sh
- touches: claude/workflow/timing/timing.mk
- touches: claude/workflow/config/time-budgets.json
- step: time-budgets.json: add `ci_events: {repos: ["jkkelley/dotfiles"], limit: 50, state: "~/.local/state/zenith/timing/ci-events.json"}`
- step: ci-events.sh [--once]: for each repo `gh run list -R <repo> --limit <limit> --json databaseId,name,status,conclusion,createdAt,updatedAt,headBranch`; a run first seen not completed -> `tm_event all ci-<repo name>-<databaseId> ci <databaseId> start '{"workflow":<name>,"branch":<headBranch>}'`; a run seen completed and not yet ended -> `.end` with rc 0 for success else 1, duration_s = updatedAt - createdAt, budget_s from tm_limit; state file dedupes; idempotent
- step: timing.mk: `ci-events ONCE=1` target, and node-timing-loop runs `bash timing/ci-events.sh --once` before each tick
- step: test with a stub gh returning fixture JSON for a queued then a completed run
- step: run `make -C claude/workflow timing-test CASE=ci-events`
- tool: make:claude/workflow/timing/timing.mk:timing-test - on main; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute
- tool: cmd:gh - on main; fallback: gh or GitHub down: retry 3 times, then stop with A2A-003 and the gh error in the result blockers
- provides: path:claude/workflow/timing/ci-events.sh (created by this ticket)

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow timing-test CASE=ci-events` exits 0 and prints `ok a new run publishes ci start once` and `ok a completed run publishes ci end with duration_s once` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* a second --once with the same fixture publishes nothing (`ok ci-events is idempotent`) (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

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
