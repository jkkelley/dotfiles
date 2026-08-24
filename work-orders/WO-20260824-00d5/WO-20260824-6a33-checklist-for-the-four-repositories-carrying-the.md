---
{
  "id": "WO-20260824-6a33",
  "slug": "checklist-for-the-four-repositories-carrying-the",
  "title": "Checklist for the four repositories carrying the stale session-start block",
  "type": "chore",
  "status": "draft",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:14-05:00",
  "parent": "WO-20260824-00d5",
  "branch": null,
  "pr": null,
  "merge_sha": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-c6b0"
  ],
  "blocks": [
    "WO-20260824-238b"
  ]
}
---

# WO-20260824-6a33 - Checklist for the four repositories carrying the stale session-start block

## Problem

Four repositories carry the identical two-line prose session-start check that this design deletes. They cannot be edited from a dotfiles session - that would be propagating a change outward from here rather than making it deliberately inside each repository. What this repository owes is an accurate checklist naming each one and exactly what to remove.

## Scope

**In**

- one row per repository, with file and line numbers
- skill-onboard.sh named as the tool that performs each run

**Out - non-goals**

- editing any of the four repositories from this session or this repository
- the four runs themselves, which are deliberate acts inside each repository

## Acceptance criteria


- [ ] `AC-H1` *(human)* the checklist names all four repositories with file and line numbers that resolve
- [ ] `AC-H2` *(human)* each row states that it is closed only by that repository's own merged PR

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 3 points. Sized as the checklist only. The four runs happen inside those repositories and are not tickets here.

## Outcome

_Written by `work-order close`. Empty until then._
