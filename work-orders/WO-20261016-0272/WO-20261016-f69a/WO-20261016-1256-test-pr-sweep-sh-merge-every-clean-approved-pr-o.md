---
{
  "id": "WO-20261016-1256",
  "slug": "test-pr-sweep-sh-merge-every-clean-approved-pr-o",
  "title": "Test - pr-sweep.sh: merge every clean approved PR, one fix work order per red one",
  "type": "test",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:06:26+00:00",
  "parent": "WO-20261016-f69a",
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
    "WO-20261016-df39"
  ],
  "blocks": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-1256 - Test - pr-sweep.sh: merge every clean approved PR, one fix work order per red one

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

Run the filled test plan of WO-20261016-df39 - pr-sweep.sh: merge every clean approved PR, one fix work order per red one exactly as written; dev gate (item 34), no owner notification (item 35).

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

scripts/pr-sweep.sh against a fixture latest.json, stub gh and a temp work-order project

**Cases**

- `TP-1`
  - intent: green approved PRs parked under agents are dead code (item 21)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_pr_sweep.sh'`
  - expected: exit 0; prints `ok  a clean seat PR is merged once through timed-run`
- `TP-2`
  - intent: a red PR needs exactly one owner, never a pile of duplicates
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_pr_sweep.sh'`
  - expected: exit 0; prints `ok  a conflicted PR files one fix work order and a rerun files none`
- `TP-3`
  - intent: UAT starts with a dry run on the real account
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_pr_sweep.sh'`
  - expected: exit 0; prints `ok  DRY=1 merges nothing`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full scripts suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
