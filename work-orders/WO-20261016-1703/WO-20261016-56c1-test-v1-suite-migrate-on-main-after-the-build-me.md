---
{
  "id": "WO-20261016-56c1",
  "slug": "test-v1-suite-migrate-on-main-after-the-build-me",
  "title": "Test V1 - suite migrate on main after the build merges",
  "type": "test",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:46:53+00:00",
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
    "WO-20261016-5f8d"
  ],
  "blocks": []
}
---

# WO-20261016-56c1 - Test V1 - suite migrate on main after the build merges

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

The V1 build is proven only by its suite run on main, by a tester who did not write it (Design principles 101 item 30)

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

run.json v1 to v2 migration

**Cases**

- `TP-1`
  - intent: a record version with no migration strands every open run
  - command: `podman run --rm --network=none --userns=keep-id -v "$PWD:/work:ro,Z" -w /work/claude/workflow/inbox-sweep -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/run.sh --suite migrate`
  - expected: exit 0; the output ends with `ok  migrate` and `ran 1 suite`; the run upgrade case is ok

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
