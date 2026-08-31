---
{
  "id": "WO-20260824-d058",
  "slug": "remove-the-inline-read-only-notice-from-the-othe",
  "title": "Remove the inline read-only notice from the other 42 SKILL.md files",
  "type": "chore",
  "status": "in-progress",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-31",
  "created_at": "2026-08-24T13:19:12-05:00",
  "parent": "WO-20260824-00d5",
  "branch": "feat/remove-the-inline-read-only-notice-from-the-othe",
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
    "WO-20260824-316d"
  ],
  "blocks": [
    "WO-20260824-79b6",
    "WO-20260824-238b"
  ]
}
---

# WO-20260824-d058 - Remove the inline read-only notice from the other 42 SKILL.md files

## Problem

With the notice rendered at install time, 42 files still carry it inline. A copy that keeps its committed notice and also receives a rendered one shows the notice twice. This is mechanically trivial and is the riskiest mechanical change in the plan, because it touches every skill in the repository at once.

## Scope

**In**

- removing lines 9 to 14 from all 42 remaining skills
- one PR, titled fix(skills): remove the inline read-only notice, now rendered at install

**Out - non-goals**

- hand-written trailers - 42 of them would be 42 chances to typo a skill name
- any frontmatter change whatsoever

## Acceptance criteria


- [ ] `AC-H1` *(human)* frontmatter is byte-identical across all 42 files afterwards: name, description, version, in that order
- [ ] `AC-H2` *(human)* 42 skills go up exactly one patch level in a single publish run
- [ ] `AC-H3` *(human)* no SKILL.md in the repository contains the notice

## Test plan

```sh
the title is the mechanism: the publisher fallback gives every changed-but-unlisted skill the title's conventional level, so one fix title produces 42 patch bumps
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 5 points. The five is verification, not editing. Removing six lines from 42 files is a one-liner; proving frontmatter is byte-identical afterwards and that exactly 42 bumps landed is the work.

## Outcome

_Written by `work-order close`. Empty until then._
