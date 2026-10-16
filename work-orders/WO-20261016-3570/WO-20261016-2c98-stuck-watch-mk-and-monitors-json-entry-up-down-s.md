---
{
  "id": "WO-20261016-2c98",
  "slug": "stuck-watch-mk-and-monitors-json-entry-up-down-s",
  "title": "stuck-watch.mk and monitors.json entry: up, down, status, deadman-install, uninstall, clean",
  "type": "feature",
  "status": "ready",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:51:58+00:00",
  "parent": "WO-20261016-3570",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Claude seat: lavish is prohibited outside firstmate (~/AGENTS.md owner interaction surface); brief BR-20261016-stuck-watch from the architect is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-2d3e",
    "WO-20261016-7ce0"
  ],
  "blocks": []
}
---

# WO-20261016-2c98 - stuck-watch.mk and monitors.json entry: up, down, status, deadman-install, uninstall, clean

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

The scripts need Make entry points and one monitors.json entry.

## Scope

**In**

- claude/workflow/stuck-watch/stuck-watch.mk
- claude/workflow/Makefile (one include)
- claude/workflow/config/monitors.json

**Out - non-goals**

- script logic

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* make stuck-watch-up/down/status, deadman-install/uninstall, stuck-watch-clean exist and are idempotent
- [ ] `AC-H2` *(human)* monitors.json has a stuck-watch entry

## Test plan

```sh
make -C claude/workflow stuck-watch-test
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
