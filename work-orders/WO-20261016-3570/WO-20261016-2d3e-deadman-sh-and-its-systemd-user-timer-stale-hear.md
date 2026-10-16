---
{
  "id": "WO-20261016-2d3e",
  "slug": "deadman-sh-and-its-systemd-user-timer-stale-hear",
  "title": "deadman.sh and its systemd --user timer: stale heartbeat or down bus pages 'stuck-watch dead'",
  "type": "feature",
  "status": "ready",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:51:55+00:00",
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
    "WO-20261016-230f"
  ],
  "blocks": [
    "WO-20261016-5597",
    "WO-20261016-2c98"
  ]
}
---

# WO-20261016-2d3e - deadman.sh and its systemd --user timer: stale heartbeat or down bus pages 'stuck-watch dead'

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

A dead watcher is silent.

## Scope

**In**

- claude/workflow/stuck-watch/deadman.sh
- claude/workflow/stuck-watch/systemd/

**Out - non-goals**

- herdr, the watcher process

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* heartbeat older than 3 min -> ntfy priority high
- [ ] `AC-H2` *(human)* bus down -> ntfy priority high
- [ ] `AC-H3` *(human)* started by systemd --user timer only

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
