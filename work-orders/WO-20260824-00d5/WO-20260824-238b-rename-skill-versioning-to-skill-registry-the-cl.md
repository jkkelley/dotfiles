---
{
  "id": "WO-20260824-238b",
  "slug": "rename-skill-versioning-to-skill-registry-the-cl",
  "title": "Rename skill-versioning to skill-registry, the closing commit",
  "type": "chore",
  "status": "ready",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-30",
  "created_at": "2026-08-24T13:19:15-05:00",
  "parent": "WO-20260824-00d5",
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
    "WO-20260824-c6b0",
    "WO-20260824-81a6",
    "WO-20260824-b21b",
    "WO-20260824-d058",
    "WO-20260824-79b6",
    "WO-20260824-a6cb",
    "WO-20260824-6a33",
    "WO-20260825-dac4"
  ],
  "blocks": [
    "WO-20260830-eb89"
  ]
}
---

# WO-20260824-238b - Rename skill-versioning to skill-registry, the closing commit

## Problem

After this work the skill owns three publish-side things, consumers never touch it, and versioning is precisely the part CI took over - so the name now describes the one responsibility it no longer has. The rename must be last because every reference has to be updated in the same commit, and there can be no compat symlink: skill_dirs uses find -type d, which does not match a symlink to a directory, so the symlink would hide the breakage rather than surface it.

## Scope

**In**

- git mv claude/skills/skill-versioning claude/skills/skill-registry
- updating every remaining reference
- a major bump, because a renamed skill breaks a consumer's existing usage

**Out - non-goals**

- renaming skill-version.sh - the skill is renamed, the script is not
- a compat symlink, which the registry cannot see

## Acceptance criteria


- [ ] `AC-H1` *(human)* git grep skill-versioning returns nothing outside history
- [ ] `AC-H2` *(human)* verify is green on main after the publish run
- [ ] `AC-H3` *(human)* the publish run records a major bump for skill-registry

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 3 points. Mechanical, and it must be last.

## Outcome

_Written by `work-order close`. Empty until then._
