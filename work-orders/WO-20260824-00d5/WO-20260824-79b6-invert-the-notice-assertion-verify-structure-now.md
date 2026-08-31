---
{
  "id": "WO-20260824-79b6",
  "slug": "invert-the-notice-assertion-verify-structure-now",
  "title": "Invert the notice assertion: verify --structure now fails on a notice that is present",
  "type": "feature",
  "status": "in-progress",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-31",
  "created_at": "2026-08-24T13:19:13-05:00",
  "parent": "WO-20260824-00d5",
  "branch": "feat/invert-the-notice-assertion-verify-structure-now",
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
    "WO-20260824-d058"
  ],
  "blocks": [
    "WO-20260824-238b"
  ]
}
---

# WO-20260824-79b6 - Invert the notice assertion: verify --structure now fails on a notice that is present

## Problem

Between the notice check being deleted and this ticket, nothing stops someone pasting the notice back into a SKILL.md - and the obvious reaction to seeing it missing is to put it back. A committed notice plus a rendered one shows twice in the installed copy. This cannot land before every file is clean, because the assertion would fail on the repository's own contents.

## Scope

**In**

- the assertion inverting: a notice present in an upstream SKILL.md is now a failure
- a failure message that says why, because the obvious reaction is to paste it back

**Out - non-goals**

- anything about a rendered notice in an installed copy, which is expected and correct

## Acceptance criteria


- [ ] `AC-H1` *(human)* pasting the notice into any SKILL.md fails the PR gate
- [ ] `AC-H2` *(human)* the failure message explains that the notice is rendered at install and must not be committed

## Test plan

```sh
bash claude/skills/skill-versioning/testing/run-tests.sh in Podman per Rule 14
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 2 points. One inverted assertion and a message.

## Outcome

_Written by `work-order close`. Empty until then._
