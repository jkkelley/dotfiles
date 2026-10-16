---
{
  "id": "WO-20261016-dc6b",
  "slug": "test-b25-suite-reply-look-on-main-after-the-buil",
  "title": "Test B25 - suite reply-look on main after the build merges",
  "type": "test",
  "status": "draft",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T07:56:25+00:00",
  "parent": "WO-20261016-1703",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-93d3"
  ],
  "blocks": []
}
---

# WO-20261016-dc6b - Test B25 - suite reply-look on main after the build merges

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

B25 needs its own scripted test run on main (item 30).

## Scope

**In**

_none_

**Out - non-goals**

- posting or sending anything - never from a test (item 35)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* every case in the plan passes

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

reply-cards.sh and lead-followup.sh run every draft through the shared ypli style lint and approval preview before a card

**Cases**

- `TP-1`
  - intent: a draft that breaks the style spec must never reach the owner's card
  - command: `bash claude/workflow/inbox-sweep/tests/run.sh --suite reply-look`
  - expected: exit 0; with the stub lint failing, no card is added and the ledger gets RP-STYLE-FAILED

- `TP-2`
  - intent: the owner approves what the preview shows, the same as the content engine
  - command: `bash claude/workflow/inbox-sweep/tests/run.sh --suite reply-look`
  - expected: exit 0; the card body equals the stub ypli preview output byte for byte

**Isolation**

- runtime: podman
- image: `localhost/dotfiles-workflow-test@sha256:0a6832bb348572415fc3b304ed48ece90bcce4bd92b7f3f95a6ebc9d694f18f0` (localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- every other inbox-sweep suite and lint, run by the claude/workflow CI job

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
