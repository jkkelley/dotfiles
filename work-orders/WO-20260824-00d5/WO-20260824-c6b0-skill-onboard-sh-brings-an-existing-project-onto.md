---
{
  "id": "WO-20260824-c6b0",
  "slug": "skill-onboard-sh-brings-an-existing-project-onto",
  "title": "skill-onboard.sh brings an existing project onto the sync",
  "type": "feature",
  "status": "draft",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:10-05:00",
  "parent": "WO-20260824-00d5",
  "branch": null,
  "pr": null,
  "merge_sha": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-9712"
  ],
  "blocks": [
    "WO-20260824-6a33",
    "WO-20260824-238b"
  ]
}
---

# WO-20260824-c6b0 - skill-onboard.sh brings an existing project onto the sync

## Problem

Every project that already exists has committed skills, no manifest, no gitignore entry and the old prose in its CLAUDE.md. Doing that by hand in each one is where the mistakes come from. The script has to work without ever touching the user's working tree, which means a treehouse slot, and the gate finding proved it must assert the slot went free rather than trusting an exit code.

## Scope

**In**

- taking a treehouse slot with --lease-holder skill-onboard, never stashing
- writing .claude/skills.toml, the gitignore lines and the CLAUDE.md block
- git rm -r --cached .claude/skills/ only where they were committed
- commit, push, PR, squash-merge, delete the branch
- returning the slot and asserting it is free afterwards

**Out - non-goals**

- installing the hook - that is machine level and setup.sh owns it
- running this against any real repository, which is a separate deliberate act

## Acceptance criteria


- [ ] `AC-H1` *(human)* run against a scratch repository with committed skills it lands a merged PR and leaves no leased slot behind
- [ ] `AC-H2` *(human)* a dirty working tree makes the run report a failure rather than exit 0 having done nothing

## Test plan

```sh
a scratch repository in a container, plus the dirty-tree case that the gate probe showed exits 0 while leaking a slot
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 5 points. Sized below medium-plus: the risky half, asserting the slot actually went free, is already solved knowledge from the gate probe.

## Outcome

_Written by `work-order close`. Empty until then._
