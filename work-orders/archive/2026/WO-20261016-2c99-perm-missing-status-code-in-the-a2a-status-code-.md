---
{
  "id": "WO-20261016-2c99",
  "slug": "perm-missing-status-code-in-the-a2a-status-code-",
  "title": "PERM-MISSING status code in the A2A status code map",
  "type": "chore",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:55:50+00:00",
  "parent": null,
  "branch": "feat/perm-missing-status-code-in-the-a2a-status-code-",
  "pr": 161,
  "closed": "2026-10-16",
  "approval": {
    "via": "lavish",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-2c99 - PERM-MISSING status code in the A2A status code map

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

Design principles 101 item 36: a seat blocked on a missing permission emits PERM-MISSING, but the A2A status code map has no row for it

## Scope

**In**

- claude/workflow/templates/a2a/README.md
- claude/workflow/tests/unit/test_a2a_brief.sh

**Out - non-goals**

- PERM-MISSING row in claude/workflow/templates/a2a/README.md

## Degrees of freedom

- [free] none beyond the row text given by the orchestrator

## Acceptance criteria

- [x] `AC-H1` *(human)* the status code map has a PERM-MISSING row; proof: test_a2a_brief.sh in Podman asserts it
  - observed `2026-10-16` podman localhost/dotfiles-workflow-test:1 tests/unit/test_a2a_brief.sh: 'ok the status code map lists A2A-001 to A2A-004 and PERM-MISSING' with the row at claude/workflow/templates/a2a/README.md:35; with the row removed: 'FAIL ... (missing: PERM-MISSING)'

## Test plan

```sh
make -C claude/workflow image; podman run the workflow test image on tests/unit/test_a2a_brief.sh
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
