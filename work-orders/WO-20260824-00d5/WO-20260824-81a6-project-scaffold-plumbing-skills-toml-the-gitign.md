---
{
  "id": "WO-20260824-81a6",
  "slug": "project-scaffold-plumbing-skills-toml-the-gitign",
  "title": "project-scaffold plumbing: skills.toml, the gitignore blanket, scaffold.json removed, skill-update.sh narrowed",
  "type": "feature",
  "status": "ready",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:11-05:00",
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
    "WO-20260824-9712"
  ],
  "blocks": [
    "WO-20260824-238b"
  ]
}
---

# WO-20260824-81a6 - project-scaffold plumbing: skills.toml, the gitignore blanket, scaffold.json removed, skill-update.sh narrowed

## Problem

Four small changes to project-scaffold that only make sense together and would otherwise be four PRs against the same directory in one week. A new project must be unable to commit a skill, must arrive with a manifest naming the four defaults, must stop writing a scaffold.json nothing will read any more, and skill-update.sh must say in its header that it is no longer the path for managed skills.

## Scope

**In**

- a blanket ignore for **/.claude/skills/ beside the existing agents line
- writing .claude/skills.toml with the four defaults from decision 20, plus an empty agents block with a comment
- project-scaffold no longer writing .claude/scaffold.json, and readers moved to the receipt
- skill-update.sh header stating the split: hand-authored skills only

**Out - non-goals**

- CLAUDE.md.tmpl, which is its own ticket because it is prose and reviewed differently

## Acceptance criteria


- [ ] `AC-H1` *(human)* a project scaffolded from the template cannot commit a skill
- [ ] `AC-H2` *(human)* a freshly scaffolded project syncs the four defaults on its first session
- [ ] `AC-H3` *(human)* git grep scaffold.json returns nothing outside history
- [ ] `AC-H4` *(human)* the skill-update.sh header answers should I be running this without reading the body

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 6 points. Bundle of four: 1 + 2 + 2 + 1. All project-scaffold plumbing, one PR.

## Outcome

_Written by `work-order close`. Empty until then._
