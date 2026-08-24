---
{
  "id": "WO-20260824-0615",
  "slug": "confirm-whether-a-sessionstart-hook-matcher-filt",
  "title": "Confirm whether a SessionStart hook matcher filters by source",
  "type": "spike",
  "status": "draft",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:06-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": null,
  "pr": null,
  "merge_sha": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20260824-bb0d"
  ]
}
---

# WO-20260824-0615 - Confirm whether a SessionStart hook matcher filters by source

## Problem

The design's safety property is that the sync never runs on a compact. That depends entirely on SessionStart matchers accepting a source string, and every hook in settings.json on this machine uses an empty matcher, so there is no working example of the filtered form anywhere. The property is unobservable from a unit test and has to be watched happening.

## Scope

**In**

- a scratch project with a SessionStart hook whose matcher is the literal startup
- starting, resuming, clearing and force-compacting a session and recording which fired

**Out - non-goals**

- writing the real hook, which setup.sh owns
- any change to skill-sync.sh, which only happens if the answer is no

## Acceptance criteria


- [ ] `AC-H1` *(human)* the four sources are each exercised and which of them fired is written down
- [ ] `AC-H2` *(human)* the ticket records the resulting decision: either the matcher form for setup.sh, or that skill-sync.sh must read the source from stdin and exit early itself

## Test plan

```sh
manual, rung 5 of the ladder. A scratch project, a hook that appends its stdin payload to a file, and four real session events
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 3 points. Small work, high fiddliness: forcing a compact costs a real context window, and a no answer adds scope to skill-sync.sh.

## Outcome

_Written by `work-order close`. Empty until then._
