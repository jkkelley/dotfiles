---
{
  "id": "WO-20260824-00d5",
  "slug": "skills-package-manager-roll-it-out-across-the-re",
  "title": "Skills package manager: roll it out across the repository",
  "type": "feature",
  "status": "ready",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-30",
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

- `2026-08-30` A seventh step was added to the approved order on 2026-08-30: WO-20260830-eb89 - skill-sync fills the CLAUDE.md skills table between the markers. It runs first once every ticket in the original cut is done, and the graph says so with an edge onto WO-20260824-238b - Rename skill-versioning to skill-registry, the closing commit rather than a paragraph saying so. Why it exists: WO-20260824-b21b - CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule ships the skills:begin and skills:end markers and names skill-sync as their writer, per the design doc body and plan E2.4, and nothing in the repository writes between them. Verified across every open and archived ticket on 2026-08-30 before cutting it: WO-20260824-5b89 - skill-sync.sh part one: resolution, and the tools test tree it is proved in and WO-20260824-efb0 - skill-sync.sh part two: build, swap, receipt and self-update both name writing outside .claude/skills/ as an explicit non-goal, so the fill was never in anyone's scope. It was surfaced by b21b rather than planned, which is why it arrives as an addition rather than a re-derivation of the order. Why last rather than beside b21b: the user was asked on 2026-08-30 whether to widen b21b to cover it and chose not to. b21b is 5 points of prose reviewed as prose, and the fill is script work in a different skill with a different suite; one pull request carrying both would be reviewed as one unit and neither half would get the reading it needs. The cost of deferring is a marker pair that sits empty until eb89 lands, which is inert rather than broken - a project's CLAUDE.md simply does not yet say what it holds, and the receipt under .claude/cache/ still records it. 238b stays the closing commit of the rollout itself; eb89 is new work appended after it, not a reordering of the six steps approved on 2026-08-29.
- `2026-08-30` Step 2 split into two branches, and b21b now depends on 81a6. The approved order of 2026-08-29 put WO-20260824-81a6 - project-scaffold plumbing: skills.toml, the gitignore blanket, scaffold.json removed, skill-update.sh narrowed and WO-20260824-b21b - CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule beside each other in step 2. Asked on 2026-08-30 whether they should share a branch; the answer was no, and the edge was added so the graph says so rather than a hydration paragraph saying so. Why separate: 81a6 is scripts and templates, b21b is roughly 68 lines of replaced prose, and the two are reviewed differently - 81a6 own Out block already names CLAUDE.md.tmpl as a non-goal for that reason. One PR mixing them would be reviewed as one unit and neither half would get the reading it needs. Why an edge rather than nothing: both write claude/skills/project-scaffold/, so concurrent branches means the second rebases, and without an edge work-order next offers both at once and invites exactly that. The edge is a sequencing constraint, not a discovered technical dependency - it does not change the approved order, it records how step 2 is being executed. For the agent taking b21b: 81a6 does not touch CLAUDE.md.tmpl at all, so the rebase surface is empty and the only thing you inherit is one version bump already spent on project-scaffold. Take b21b as its own branch with its own Bump: project-scaffold=minor. Two of the four dead work-order.sh close references still live in CLAUDE.md.tmpl at lines 207 and 248 and they are b21b to fix; the third is claude/skills/work-order/settings.local.json.tmpl:6 and is on no ticket.
- `2026-08-30` Execution order approved by the user 2026-08-29, after the epic's shape was reviewed against the children's Problem sections. (1) WO-20260824-a6cb - The hydration-prompt close-out acquires and releases a treehouse slot: zero dependencies, smallest, and it de-risks the hardest ticket. (2) WO-20260824-81a6 - project-scaffold plumbing: skills.toml, the gitignore blanket, scaffold.json removed, skill-update.sh narrowed, with WO-20260824-b21b - CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule beside it; these set the written shape of skills.toml and the gitignore stanza on the greenfield path, which c6b0 then retrofits. (3) WO-20260824-c6b0 - skill-onboard.sh brings an existing project onto the sync. (4) WO-20260824-6a33 - Checklist for the four repositories carrying the stale session-start block, which already depends on c6b0. (5) WO-20260824-d058 - Remove the inline read-only notice from the other 42 SKILL.md files then WO-20260824-79b6 - Invert the notice assertion: verify --structure now fails on a notice that is present, independent of the rest and runnable at any point, though not concurrently with c6b0 since both churn heavily. (6) WO-20260824-238b - Rename skill-versioning to skill-registry, the closing commit, last by construction. A first draft of this order put d058 first on the theory that onboarding before it would install a doubled notice. That is false: render_notice in claude/tools/skill-sync.sh strips an existing inline notice before inserting the rendered one, and its comment says it was written for exactly this transition window. d058 is the largest mechanical change in the epic, which is not the same as the first.
- `2026-08-24` Poker 2026-08-24: 32 points. Sum of 8 children, after bundling four project-scaffold tickets into one.

## Outcome

_Written by `work-order close`. Empty until then._
