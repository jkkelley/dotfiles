---
{
  "id": "WO-20261016-b639",
  "slug": "test-line-watch-flags-a-seat-looping-sleep-plus-",
  "title": "Test - line-watch flags a seat looping sleep plus gh pr or gh run as LW-ALERT-BLOCKED code CI-POLL",
  "type": "test",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:33:25+00:00",
  "parent": "WO-20261016-4b6c",
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
    "WO-20261016-8d26"
  ],
  "blocks": []
}
---

# WO-20261016-b639 - Test - line-watch flags a seat looping sleep plus gh pr or gh run as LW-ALERT-BLOCKED code CI-POLL

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

Run the filled test plan of WO-20261016-8d26 - line-watch flags a seat looping sleep plus gh pr or gh run as LW-ALERT-BLOCKED code CI-POLL exactly as written; dev gate (item 34), no owner notification (item 35).

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

line-watch.sh CI-POLL process check against ps fixtures and a fake proc root

**Cases**

- `TP-1`
  - intent: a seat polling CI blocks the line and breaks ORD-0542 O2 (ORD-0628 P1)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
  - expected: exit 0; prints `ok  a sleep plus gh pr loop raises LW-ALERT-BLOCKED CI-POLL`
- `TP-2`
  - intent: gh run in the loop is caught the same way
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
  - expected: exit 0; prints `ok  a sleep plus gh run loop raises LW-ALERT-BLOCKED CI-POLL`
- `TP-3`
  - intent: a plain sleep is not a CI poll, or every short wait pages the orchestrator
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
  - expected: exit 0; prints `ok  a plain sleep raises no CI-POLL`
- `TP-4`
  - intent: fallback path: ps or /proc unreadable leaves the seat unflagged and the sweep running
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
  - expected: exit 0; prints `ok  unreadable proc raises no CI-POLL and the sweep continues`

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

_Written by `work-order done`. Empty until then._
