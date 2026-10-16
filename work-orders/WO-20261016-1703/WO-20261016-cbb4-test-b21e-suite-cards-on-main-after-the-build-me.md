---
{
  "id": "WO-20261016-cbb4",
  "slug": "test-b21e-suite-cards-on-main-after-the-build-me",
  "title": "Test B21e - suite cards on main after the build merges",
  "type": "test",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:46:30+00:00",
  "parent": "WO-20261016-1703",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Architect rulings R3 and R4, 2026-10-16T04:25Z, recorded in design 18 (PR 153); Claude seats never use lavish",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-5b59"
  ],
  "blocks": []
}
---

# WO-20261016-cbb4 - Test B21e - suite cards on main after the build merges

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

The B21e build is proven only by its suite run on main, by a tester who did not write it (Design principles 101 item 30)

## Scope

**In**

_none_

**Out - non-goals**

- changing any code; a failing case is filed as a bug with its output

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* every case in the plan passes on main, output captured to the artifact store (item 31)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

sweep-cards.sh as sole writer of questions.json

**Cases**

- `TP-1`
  - intent: four writers of the owner's card file risk duplicate or lost cards
  - command: `podman run --rm --network=none --userns=keep-id -v "$PWD:/work:ro,Z" -w /work/claude/workflow/inbox-sweep -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/run.sh --suite cards`
  - expected: exit 0; the output ends with `ok  cards` and `ran 1 suite`; the single-writer grep case is ok

**Isolation**

- runtime: podman
- image: `localhost/dotfiles-workflow-test@sha256:0a6832bb348572415fc3b304ed48ece90bcce4bd92b7f3f95a6ebc9d694f18f0` (localhost/dotfiles-workflow-test:1 at cut time, built from claude/workflow/tests/container/Containerfile)

**Out of scope - CI covers**

- lint and every other suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
