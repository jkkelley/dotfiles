---
{
  "id": "WO-20260824-f1a5",
  "slug": "skills-package-manager-prove-the-path-on-one-ski",
  "title": "Skills package manager: prove the path on one skill",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:05-05:00",
  "parent": null,
  "branch": null,
  "pr": null,
  "merge_sha": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20260824-00d5"
  ]
}
---

# WO-20260824-f1a5 - Skills package manager: prove the path on one skill

## Problem

Skill versions are allocated by hand at author time, which is a claim about ordering that cannot be known until merge. Projects receive skills as copies with no way to learn the original moved on. This epic builds the whole pipeline - registry, sync, PR gate, publisher, hook - and proves it end to end on a single skill before anything else is migrated.

## Scope

**In**

- merge-time version allocation in CI
- claude/tools/skill-sync.sh and its test tree
- registry schema 2, with type derived and requires declared
- hydration-prompt as the pilot skill

**Out - non-goals**

- migrating the other 42 skills, which is epic 2
- project-scaffold changes, which are epic 2
- the project-only skill system
- justfile coverage

## Acceptance criteria


- [ ] `AC-H1` *(human)* hydration-prompt carries a version on main that no human typed
- [ ] `AC-H2` *(human)* a scratch project receives hydration-prompt on session start, with the notice rendered in
- [ ] `AC-H3` *(human)* skill-version.sh verify is green on main after the pilot merges

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 56 points. Sum of 13 children.

## Outcome

_Written by `work-order close`. Empty until then._
