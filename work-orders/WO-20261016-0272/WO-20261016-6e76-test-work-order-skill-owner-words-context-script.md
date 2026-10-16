---
{
  "id": "WO-20261016-6e76",
  "slug": "test-work-order-skill-owner-words-context-script",
  "title": "Test - work-order skill: owner words, context, scripted AC checks, check verb, approve resolves tools",
  "type": "test",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:05:09+00:00",
  "parent": "WO-20261016-0272",
  "branch": "feat/test-work-order-skill-owner-words-context-script",
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
    "WO-20261016-6ef4"
  ],
  "blocks": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-6e76 - Test - work-order skill: owner words, context, scripted AC checks, check verb, approve resolves tools

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

Run the filled test plan of WO-20261016-0e3a - work-order skill: owner words, context, scripted AC checks, check verb, approve resolves tools exactly as written; dev gate (item 34), no owner notification (item 35).

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
  - observed `2026-10-16` TP-1..TP-3: run-tests.sh printed ok for cases 260, 270 (25 checks), 280 (9 checks); all cases passed: 372 checks across 28 case files; TP-4 make timing-test pass=24 fail=0. Output: /home/luna/.local/state/zenith/log/2026/10/20261016-091500-wo-6e76-testplan.md
- [x] `AC-H2` *(human)* the run output is written by script to ~/.local/state/zenith/log/YYYY/MM/ with frontmatter (proof: the path)
  - observed `2026-10-16` run output written by script with frontmatter at /home/luna/.local/state/zenith/log/2026/10/20261016-091500-wo-6e76-testplan.md

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/skills/work-order: new flags, check verb, done gate, approve tool resolution

**Cases**

- `TP-1`
  - intent: a ticket without the owner's words loses ideas between design and build (item 30)
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0; case 260 prints ok: new without --owner-words exits 3 missing_owner_words
- `TP-2`
  - intent: an AC ticked by hand is a claim, not a proof
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0; case 270 prints ok: check ticks a passing AC with command, exit code and output and done refuses a failing one
- `TP-3`
  - intent: a ready ticket naming a tool that is not on main sends a seat to invent it (ORD-0555)
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0; case 280 prints ok: approve exits 3 tool_missing for an unresolved make target and passes one listed in --provides
- `TP-4`
  - intent: the bottleneck filer must keep filing after the flags become required
  - command: `make -C claude/workflow timing-test`
  - expected: exit 0; fail=0

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- skill-pr-gate runs the full work-order suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
