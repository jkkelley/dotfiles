---
{
  "id": "WO-20261016-17dc",
  "slug": "test-pr-process-uat-on-dotfiles-then-stable-on-t",
  "title": "test: PR process UAT on dotfiles then stable on three repos (T10)",
  "type": "test",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:39:17+00:00",
  "parent": "WO-20261016-ebe4",
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
  "depends_on": [
    "WO-20261016-2447",
    "WO-20261016-83fb"
  ],
  "blocks": []
}
---

# WO-20261016-17dc - test: PR process UAT on dotfiles then stable on three repos (T10)

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

Build ticket from claude/workflow/docs/pr-process/pr-process.md section 13; files: none

## Scope

**In**

- none

**Out - non-goals**

- any file not listed in Scope
- a review gate or gh pr merge --auto

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the named test cases pass in podman
- [ ] `AC-H2` *(human)* files touched equal the Scope list

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the pr-flow PR process end to end: merge-on-green on dotfiles (UAT), then the rendered workflows on business and ypconsult-01-src (stable)

**Cases**

- `TP-1`
  - intent: the sweep's records and timing are right, or the AC2 number read off the bus is wrong for every repository
  - command: `make -C claude/workflow pr-flow-test CASES=consume`
  - expected: exit 0, consume: pass=10 fail=0
- `TP-2`
  - intent: a green dotfiles PR merges within 120 s of its last check with no review step (UAT, AC2); fails if the Action holds a green head
  - command: `make -C claude/workflow pr-flow-sweep REPO=jkkelley/dotfiles`
  - expected: exit 0, each merged 200 line for a PR merged by github-actions[bot] carries ci_to_merge_s under 120
- `TP-3`
  - intent: each repository's CI on a one-file PR finishes under 180 s (AC5); fails if a template change made CI serial or uncached
  - command: `make -C claude/workflow pr-flow-test CASES=ci-template`
  - expected: exit 0, ci-template: pass=26 fail=0; the stable PRs' run wall times (ypconsult-01-src #55, business #73) are recorded in the ticket evidence

**Isolation**

- runtime: podman
- image: `docker.io/library/debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full pr-flow suite (make test in claude/workflow runs pr-flow-lint and pr-flow-test on every PR)

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
