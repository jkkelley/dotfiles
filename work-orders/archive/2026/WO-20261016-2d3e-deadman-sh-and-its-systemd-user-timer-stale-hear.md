---
{
  "id": "WO-20261016-2d3e",
  "slug": "deadman-sh-and-its-systemd-user-timer-stale-hear",
  "title": "deadman.sh and its systemd --user timer: stale heartbeat or down bus pages 'stuck-watch dead'",
  "type": "feature",
  "status": "done",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:51:55+00:00",
  "parent": "WO-20261016-3570",
  "branch": "feat/deadman-sh-and-its-systemd-user-timer-stale-hear",
  "pr": 170,
  "closed": "2026-10-16",
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

- [x] `AC-H1` *(human)* heartbeat older than 3 min -> ntfy priority high
  - observed `2026-10-16` dev deadman-stale: 240 s old heartbeat -> Title stuck-watch dead, Priority high, ntfy=200; UAT AC2: 205 s after last heartbeat on the test topic (/home/luna/.local/state/zenith/log/2026/10/20261016-051034-stuck-watch-uat-stuck-uat.log)
- [x] `AC-H2` *(human)* bus down -> ntfy priority high
  - observed `2026-10-16` dev deadman-bus-down: unreachable bus -> Title bus down, Priority high
- [x] `AC-H3` *(human)* started by systemd --user timer only
  - observed `2026-10-16` make deadman-install renders stuck-deadman.service/.timer into ~/.config/systemd/user and enables the timer; UAT AC2 fired from that timer

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
