---
{
  "id": "WO-20260824-efb0",
  "slug": "skill-sync-sh-part-two-build-swap-receipt-and-se",
  "title": "skill-sync.sh part two: build, swap, receipt, and self-update",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:07-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": "feat/skill-sync-sh-part-two-build-swap-receipt-and-se",
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
  "depends_on": [
    "WO-20260824-5b89"
  ],
  "blocks": [
    "WO-20260824-2ad1",
    "WO-20260824-360d",
    "WO-20260824-bb0d"
  ]
}
---

# WO-20260824-efb0 - skill-sync.sh part two: build, swap, receipt, and self-update

## Problem

With the owned set resolved, the sync has to apply it without ever being able to destroy a hand-authored skill sitting beside a managed one. Every destructive decision is receipt-driven, the parent directory is never removed wholesale, and the script has to be able to replace itself while it is running - which is only safe because bash reads a script lazily by byte offset.

## Scope

**In**

- sweeping stale .claude/cache/.sync.* older than an hour before starting
- building into a temp directory, rendering the notice, and swapping each owned directory individually
- removing a dropped directory only when the receipt says the sync installed it
- writing the receipt with owned and status, and the stamp
- self-update by mv to .bak, forking with SKILL_SYNC_CHILD=1, rolling back on failure
- locking with mkdir, not flock, per Rule 17

**Out - non-goals**

- the resolution half, delivered by part one
- any use of flock, cmp or diff, none of which are portable

## Acceptance criteria


- [ ] `AC-H1` *(human)* a hand-authored skill beside a managed one is untouched, unread and unreported across a full sync
- [ ] `AC-H2` *(human)* a skill dropped from the manifest is removed when the receipt claims it, and orphaned rather than deleted when the receipt is missing
- [ ] `AC-H3` *(human)* the sync always exits 0, and every failure path prints loudly
- [ ] `AC-H4` *(human)* the comment explaining why self-update is mv and not cp is present in the script

## Test plan

```sh
bash claude/tools/testing/run-tests.sh in Podman per Rule 14, covering the ownership matrix and the four failure modes named in the plan
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 8 points. The destructive half. Sized above part one for the ownership matrix, the four failure modes and the self-update path.

## Outcome

_Written by `work-order close`. Empty until then._
