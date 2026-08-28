---
{
  "id": "WO-20260824-f1a5",
  "slug": "skills-package-manager-prove-the-path-on-one-ski",
  "title": "Skills package manager: prove the path on one skill",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-28",
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

- `2026-08-28` Last child shipped: WO-20260825-dac4 - verify --structure refuses a brand new skill, whichever way it is written, done on the branch inside PR #78. This epic now has no children and nothing left in scope. It was NOT closed in that pull request, and the lifecycle is the reason: done requires in-review, in-review requires submit, submit requires in-progress, and start is the only way in - it refuses a dirty tree and then runs 'git checkout -b feat/<slug>', which would have abandoned the child's own branch in the middle of its close-out. Stamping .branch with a branch that never carried a commit would have been a false record. Closing it needs its own branch and its own pull request, which is a deliberate act rather than something to smuggle into a sibling's diff.
- `2026-08-25` SCOPED EXCEPTION TO THE CLOSE-OUT PROCEDURE - one ticket only, already expired. Recording it here, on the open parent, so the deviation is not discovered later and mistaken for drift or for a new house style. WO-20260824-316d - Pilot: take hydration-prompt through the whole pipeline end to end closed out in TWO pull requests instead of one: PR #73 carried the code change and merged, and a second work-orders-only PR carried the evidence and the done. The standard procedure in workflows/close-out-procedure.md - work-order.sh done on the feature branch, inside the ticket's own PR, nothing written to main afterwards - was deliberately not followed. WHY: all three of that ticket's acceptance criteria are observations about what the publisher did to main AFTER the squash landed (AC-H1 a bumped version nobody typed, AC-H2 the registry matching render_registry, AC-H3 verify green on main). The lifecycle has no post-merge slot to record them - it ends at done, and cleanup changes no status - so closing on the branch would have meant archiving the pilot with its headline evidence marked not-yet-observed, which is the single outcome that destroys what the ticket existed to prove. WO-20260824-360d - Publish workflow: allocate versions on merge to main and regenerate the registry took the caveated one-PR route honestly and correctly, because its criteria were provable against a fixture and only its real-main half was outstanding; on the pilot the real-main half IS the deliverable. HOW LONG IT LASTS: for that one ticket, and it is already spent - it expired the moment the close-out PR merged. It covers no other ticket in this epic or in WO-20260824-00d5, it is not extended by a similar-looking argument, and it grants nothing prospectively. GO BACK TO THE PROPER PROCEDURE: every other ticket closes out in exactly one pull request, with evidence, note and done on the feature branch before the merge, per workflows/close-out-procedure.md. If a future ticket genuinely cannot be evidenced before its merge, that is a defect in the lifecycle worth its own ticket - the runner should grow a post-merge way to record an observation - and not a second silent exception.
- `2026-08-24` Migration in flight - the repo is deliberately inconsistent until this epic closes, and things being broken is expected rather than a defect. Root CLAUDE.md does not describe how this repo actually works right now. Rule 16 in particular still requires a PR touching a skill to hand-bump the version and ship a regenerated registry.json, and that stays true until WO-20260824-8cd1 - Rewrite root CLAUDE.md for merge-time allocation and the named main exception. One expected consequence: verify --structure fails on every skill PR in this epic for exactly that reason, and plain verify is the one that has to be green. Decision 2026-08-24, option A - the registry tools block renders only tools that exist on disk. claude/tools/ is empty today, so schema 2 ships with an empty tools object. Building the tools first was considered and rejected on a hard graph edge: WO-20260824-5b89 - skill-sync.sh part one: resolution, and the tools test tree it is proved in lists WO-20260824-de9e - Registry schema 2, with type derived from the tree and requires read from frontmatter in its depends_on, so skill-sync.sh cannot exist before the generator that hashes it. Reordering could only ever have supplied one of the two files. Hashing a placeholder was rejected outright - a stable hash over a file nobody wrote stays green after the real file lands, which is the precise lie this registry exists to prevent. This note is the anchor for that decision; point future sessions here.
- `2026-08-24` Poker 2026-08-24: 56 points. Sum of 13 children.

## Outcome

_Written by `work-order close`. Empty until then._
