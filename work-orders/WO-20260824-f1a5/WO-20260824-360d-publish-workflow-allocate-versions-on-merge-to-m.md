---
{
  "id": "WO-20260824-360d",
  "slug": "publish-workflow-allocate-versions-on-merge-to-m",
  "title": "Publish workflow: allocate versions on merge to main and regenerate the registry",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-25",
  "created_at": "2026-08-24T13:19:08-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": "feat/publish-workflow-allocate-versions-on-merge-to-m",
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
    "WO-20260824-cc71",
    "WO-20260824-efb0"
  ],
  "blocks": [
    "WO-20260824-316d"
  ]
}
---

# WO-20260824-360d - Publish workflow: allocate versions on merge to main and regenerate the registry

## Problem

This is the one thing permitted to write to main directly, and it is where a version is finally allocated - at the moment ordering is actually known. It has to survive two PRs merging back to back, it must never guess a level, and a run that finds nothing to do has to be free rather than a loop.

## Scope

**In**

- on push to main, with a concurrency group that does not cancel in progress
- actions/checkout at ref main, not the default github.sha
- verify first as the loop guard: green means nothing to do, exit 0
- changed skills from the before..after diff, levels from the merge commit trailers
- init at 1.0.0 for a skill absent from the registry, needing no trailer
- failing the run and bumping nothing when a level cannot be resolved

**Out - non-goals**

- guessing a level from anything other than a trailer or a conventional title
- cancel-in-progress, which would drop a bump

## Acceptance criteria


- [ ] `AC-H1` *(human)* two PRs merged back to back produce correct versions for both skills
- [ ] `AC-H2` *(human)* the run triggered by the publisher's own push exits 0 having found nothing to do
- [ ] `AC-H3` *(human)* a merge whose level cannot be resolved fails the run and leaves every version unchanged

## Test plan

```sh
the back-to-back case is the acceptance criterion and needs two real merged PRs; ref: main is what makes it work and the default checkout is what breaks it
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 8 points. Sized above the plan's medium. Same iteration cost as the gate, and this one writes to main.

## Outcome

_Written by `work-order close`. Empty until then._
