---
{
  "id": "WO-20260824-00d5",
  "slug": "skills-package-manager-roll-it-out-across-the-re",
  "title": "Skills package manager: roll it out across the repository",
  "type": "feature",
  "status": "ready",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:05-05:00",
  "parent": null,
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
    "WO-20260824-f1a5"
  ],
  "blocks": []
}
---

# WO-20260824-00d5 - Skills package manager: roll it out across the repository

## Problem

With the path proven on one skill, the remaining 42 skills still carry an inline read-only notice, project-scaffold still writes the old session-start prose and scaffold.json, and four repositories carry a stale two-line check this design deletes. This epic migrates all of it and closes with the rename that only makes sense once nothing points at the old name.

## Scope

**In**

- the notice leaving the other 42 SKILL.md files
- project-scaffold emitting skills.toml and ignoring .claude/skills/
- skill-onboard.sh for existing projects
- the skill-versioning to skill-registry rename

**Out - non-goals**

- editing the four downstream repositories from a dotfiles session
- any change to the pipeline itself, which epic 1 owns
- the project-only skill system

## Acceptance criteria


- [ ] `AC-H1` *(human)* no SKILL.md in the repository contains the inline read-only notice
- [ ] `AC-H2` *(human)* git grep skill-versioning returns nothing outside history
- [ ] `AC-H3` *(human)* a freshly scaffolded project syncs the four default skills on its first session

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 32 points. Sum of 8 children, after bundling four project-scaffold tickets into one.

## Outcome

_Written by `work-order close`. Empty until then._
