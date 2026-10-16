---
{
  "id": "WO-20261016-dd1f",
  "slug": "test-land-pr-182-a2a-deliver-confirms-the-submit",
  "title": "Test - Land PR 182: a2a-deliver confirms the submit, lowercase enter retried once",
  "type": "test",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:04:45+00:00",
  "parent": "WO-20261016-e9d4",
  "branch": "feat/test-land-pr-182-a2a-deliver-confirms-the-submit",
  "pr": 182,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-590b"
  ],
  "blocks": []
}
---

# WO-20261016-dd1f - Test - Land PR 182: a2a-deliver confirms the submit, lowercase enter retried once

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

Run the filled test plan of WO-20261016-590b - Land PR 182: a2a-deliver confirms the submit, lowercase enter retried once exactly as written; dev gate (item 34), no owner notification (item 35).

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
  - observed `2026-10-16` make -C claude/workflow a2a-guard-test on origin/main 2b57f8f: all cases ok incl. A2A-DELIVERED-RETRIED and A2A-UNCONFIRMED; full output in /home/luna/.local/state/zenith/log/2026/10/20261016-093504-wo-dd1f-a2a-guard-test-run.txt
- [x] `AC-H2` *(human)* the run output is written by script to ~/.local/state/zenith/log/YYYY/MM/ with frontmatter (proof: the path)
  - observed `2026-10-16` run output written by artifact.sh with frontmatter: /home/luna/.local/state/zenith/log/2026/10/20261016-093504-wo-dd1f-a2a-guard-test-run.txt

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/a2a-guard/a2a-deliver.sh submit confirmation against tests/fake-herdr

**Cases**

- `TP-1`
  - intent: an Enter that is not taken leaves the order unsubmitted forever (06:12Z)
  - command: `make -C claude/workflow a2a-guard-test`
  - expected: exit 0; the case where the first Enter is not taken prints ok with code A2A-DELIVERED-RETRIED
- `TP-2`
  - intent: an input box that stays full after the retry must report, never claim delivery
  - command: `make -C claude/workflow a2a-guard-test`
  - expected: exit 0; the case printing A2A-UNCONFIRMED is ok

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- a2a-lint and the full workflow suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
