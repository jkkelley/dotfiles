---
{
  "id": "WO-20260824-2136",
  "slug": "extract-the-read-only-notice-into-a-single-rende",
  "title": "Extract the read-only notice into a single rendered partial",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:07-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": null,
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
    "WO-20260824-5b89"
  ]
}
---

# WO-20260824-2136 - Extract the read-only notice into a single rendered partial

## Problem

The same six-line notice is pasted into 43 SKILL.md files. Changing its wording means 43 edits, and a vendored copy that was installed before the change keeps the old text forever. It should exist once and be rendered into a skill at install time.

## Scope

**In**

- claude/tools/partials/read-only-notice.md.tmpl with one placeholder for the skill name
- registering the partial in the registry tools block so a change forces a re-render everywhere

**Out - non-goals**

- removing the notice from any SKILL.md, which is the pilot and epic 2
- making the tool name a placeholder - it is hardcoded to skill-sync.sh on purpose

## Acceptance criteria


- [ ] `AC-H1` *(human)* rendering the template for work-order produces text byte-identical to work-order/SKILL.md lines 9 to 14 as they stand today
- [ ] `AC-H2` *(human)* the partial appears in the registry tools block with a version and a hash

## Test plan

```sh
diff the rendered output against the current lines in a container; byte-identical output is what proves this is a refactor and not a rewrite
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 2 points. The anchor. One template file, one byte-identical acceptance criterion, no unknowns.

## Outcome

_Written by `work-order close`. Empty until then._
