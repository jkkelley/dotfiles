---
{
  "id": "WO-20260824-8cd1",
  "slug": "rewrite-root-claude-md-for-merge-time-allocation",
  "title": "Rewrite root CLAUDE.md for merge-time allocation and the named main exception",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:10-05:00",
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
  "depends_on": [
    "WO-20260824-9712"
  ],
  "blocks": []
}
---

# WO-20260824-8cd1 - Rewrite root CLAUDE.md for merge-time allocation and the named main exception

## Problem

Rule 16 currently instructs every contributor to bump a version and ship a regenerated registry by hand, which after this epic is exactly the thing the PR gate refuses. The never-write-main rule also now has one genuine exception. An agent reading the current file would be told to do the wrong thing with full confidence.

## Scope

**In**

- Rule 16 rewritten: CI allocates at merge, a PR carries intent, verify --structure gates
- the named exception to the never-write-main rule, in the wording the design doc fixes
- the pipeline flow documented here, per decision 17
- skill-update.sh stated as the hand-authored path and nothing else

**Out - non-goals**

- changing any rule other than 16 and the main rule

## Acceptance criteria


- [ ] `AC-H1` *(human)* an agent reading only root CLAUDE.md can describe the whole path from a skill edit to a project receiving it
- [ ] `AC-H2` *(human)* no instruction to hand-edit a version: or registry.json survives anywhere in the file

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 3 points. Prose, but it is the repository's constitution and is easy to get subtly wrong.

## Outcome

_Written by `work-order close`. Empty until then._
