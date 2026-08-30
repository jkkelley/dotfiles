---
{
  "id": "WO-20260824-a6cb",
  "slug": "the-hydration-prompt-close-out-acquires-and-rele",
  "title": "The hydration-prompt close-out acquires and releases a treehouse slot",
  "type": "feature",
  "status": "in-progress",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-30",
  "created_at": "2026-08-24T13:19:13-05:00",
  "parent": "WO-20260824-00d5",
  "branch": "feat/the-hydration-prompt-close-out-acquires-and-rele",
  "pr": null,
  "merge_sha": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Reviewed and approved on PR #55 on GitHub, which is where the whole cut was read as one diff. Lavish was offered and declined in favour of the PR.",
    "at": "2026-08-24"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20260824-238b",
    "WO-20260824-c6b0"
  ]
}
---

# WO-20260824-a6cb - The hydration-prompt close-out acquires and releases a treehouse slot

## Problem

The close-out currently runs wherever the session happens to be. It should take a slot keyed by ticket ID so treehouse status becomes the live map of which agent holds which workbench. The gate finding makes the release the load-bearing half: a dirty tree makes treehouse return prompt, take the no-TTY default, abort, leave the slot leased and exit 0.

## Scope

**In**

- acquiring a slot with the ticket ID as --lease-holder
- returning the slot and asserting it is actually free, not reading the exit code
- treehouse status as the live map of holder by ticket ID

**Out - non-goals**

- changing the shape of a hydration entry

## Acceptance criteria


- [ ] `AC-H1` *(human)* a close-out that leaves a dirty tree reports a failure instead of reporting success
- [ ] `AC-H2` *(human)* no slot is left leased after a successful close-out

## Test plan

```sh
bash claude/skills/hydration-prompt/testing/run-tests.sh in Podman, plus the dirty-tree case the gate probe already characterised
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 3 points. Small, and the release half is the load-bearing part.

## Outcome

_Written by `work-order close`. Empty until then._
