---
{
  "id": "WO-20260824-81a6",
  "slug": "project-scaffold-plumbing-skills-toml-the-gitign",
  "title": "project-scaffold plumbing: skills.toml, the gitignore blanket, scaffold.json removed, skill-update.sh narrowed",
  "type": "feature",
  "status": "in-progress",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-30",
  "created_at": "2026-08-24T13:19:11-05:00",
  "parent": "WO-20260824-00d5",
  "branch": "feat/project-scaffold-plumbing-skills-toml-the-gitign",
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
    "WO-20260824-238b",
    "WO-20260824-b21b"
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


- [x] `AC-H1` *(human)* a project scaffolded from the template cannot commit a skill
  - observed `2026-08-30` cases-git/010-skills-gitignored.sh, run under the pinned bitnami/git image inside the suite: scaffold, git init, then a managed skill and a hand-authored one written under .claude/skills/. git check-ignore reports all three paths ignored, and after git add -A nothing under .claude/skills/ is staged. 9 checks, 0 failed. The negative is on the same tree in the same run: .claude/skills.toml, .claude/settings.json, .claude/scripts/log-issue.sh and CLAUDE.md are all still tracked, and the manifest is staged.
- [x] `AC-H2` *(human)* a freshly scaffolded project syncs the four defaults on its first session
  - observed `2026-08-30` Two halves, because no one suite can prove both. cases/160-skills-manifest.sh asserts scaffold.sh writes .claude/skills.toml byte-identical to the template, naming work-order, living-docs, container-sandbox and context-compaction one at a time, with no version anywhere outside the comments. claude/tools run-tests.sh section "the manifest project-scaffold ships" then feeds that same template file to skill-sync --plan and asserts the parser reads exactly those four and nothing from the empty [agents] block. 258 checks, 0 failed.
- [x] `AC-H3` *(human)* git grep scaffold.json returns nothing outside history
  - observed `2026-08-30` scaffold.sh no longer writes it: the apply_plan tail block is deleted. git grep scaffold.json over the tree excluding work-orders/, HYDRATION.md and docs/superpowers/ returns 8 hits, every one of them prose recording that the file was removed, plus one negative assertion in cases/010 that fails if it comes back. Nothing writes it and nothing reads it. A literal zero-hit grep is not reachable - the ticket title contains the string - and deleting a thing without saying so is what Rule 12 forbids.
- [x] `AC-H4` *(human)* the skill-update.sh header answers should I be running this without reading the body
  - observed `2026-08-30` The header now opens with SHOULD YOU BE RUNNING THIS? and a three-row table keyed on the project .claude/skills.toml: named in it means no, skill-sync owns it and the next session start replaces your copy; absent, or no manifest at all, means yes. That is the first thing on screen, above the fetch-from-GitHub rationale and above the two modes. --help repeats it in three lines before USAGE. skill-versioning SKILL.md carries the same split under "Applying an update to a project". Its suite is 148 checks, 0 failed.

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
