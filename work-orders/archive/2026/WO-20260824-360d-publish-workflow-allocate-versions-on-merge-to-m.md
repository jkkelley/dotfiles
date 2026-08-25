---
{
  "id": "WO-20260824-360d",
  "slug": "publish-workflow-allocate-versions-on-merge-to-m",
  "title": "Publish workflow: allocate versions on merge to main and regenerate the registry",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-25",
  "created_at": "2026-08-24T13:19:08-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": "feat/publish-workflow-allocate-versions-on-merge-to-m",
  "pr": 70,
  "merge_sha": null,
  "closed": "2026-08-25",
  "approval": {
    "via": "override",
    "reason": "Reviewed and approved on PR #55 on GitHub, which is where the whole cut was read as one diff. Lavish was offered and declined in favour of the PR.",
    "at": "2026-08-24"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-cc71",
    "WO-20260824-efb0"
  ],
  "blocks": [
    "WO-20260824-316d"
  ]
}
---

# WO-20260824-360d - Publish workflow: allocate versions on merge to main and regenerate the registry

## Problem

This is the one thing permitted to write to main directly, and it is where a version is finally allocated - at the moment ordering is actually known. It has to survive two PRs merging back to back, it must never guess a level, and a run that finds nothing to do has to be free rather than a loop.

## Scope

**In**

- on push to main, with a concurrency group that does not cancel in progress
- actions/checkout at ref main, not the default github.sha
- verify first as the loop guard: green means nothing to do, exit 0
- changed skills from the before..after diff, levels from the merge commit trailers
- init at 1.0.0 for a skill absent from the registry, needing no trailer
- failing the run and bumping nothing when a level cannot be resolved

**Out - non-goals**

- guessing a level from anything other than a trailer or a conventional title
- cancel-in-progress, which would drop a bump

## Acceptance criteria


- [x] `AC-H1` *(human)* two PRs merged back to back produce correct versions for both skills
  - observed `2026-08-25` Reproduced deterministically in .github/scripts/testing/run-tests.sh, in Podman on a digest-pinned base, under 'two merges in one push - AC-H1'. A fixture repository with a real generated registry takes two commits - feat(skills) touching alpha, then fix(skills) touching beta - and one publish.sh apply over <before>..HEAD allocates alpha 1.2.3 -> 1.3.0 and beta 2.0.0 -> 2.0.1 in a single publisher commit, verify green afterwards, each skill taking its own commit's type. The adjacent check 'bumping one of two changed skills leaves verify green' proves why the plan's <before>..<after> range was wrong: bump regenerates the whole registry, so a narrow range writes the other skill's new content hash under its old number and verify never notices again. NOT YET OBSERVED on the real main - the workflow does not exist there until this PR merges, and two real back-to-back merges are the remaining half.
- [x] `AC-H2` *(human)* the run triggered by the publisher's own push exits 0 having found nothing to do
  - observed `2026-08-25` 'the loop guard - a run with nothing to do is free' in .github/scripts/testing/run-tests.sh: apply against a tree whose registry already matches exits 0, prints 'Nothing to allocate', makes no commit, and never reaches the range - asserted by the absence of the range line, so the guard is proved to short-circuit rather than merely to agree with a later step. 'a second run over the same range' repeats it immediately after a real allocation on the same fixture. NOT YET OBSERVED on the real main, but it is the merge of this pull request itself: it changes no skill, verify on main is green today (43 skills versioned, registry in sync), so the push that lands the workflow is the first run and it has nothing to do.
- [x] `AC-H3` *(human)* a merge whose level cannot be resolved fails the run and leaves every version unchanged
  - observed `2026-08-25` 'an unresolvable level fails the run and bumps nothing' in .github/scripts/testing/run-tests.sh: a commit touching alpha with no trailer and a non-conventional subject makes apply exit 1 naming both the skill and the commit, with the worktree byte-identical afterwards (sha256 over every file, compared before and after), HEAD unmoved and alpha still 1.2.3. Three further shapes refuse the same way - revert:, unmapped on purpose; Bump: alpha=mayor; and a two-commit batch where only the second is unresolvable, in which alpha is deliberately left unbumped as well, because publishing half a batch is the silent-absorption failure. NOT YET OBSERVED on the real main, and not something to manufacture there: it would need a merge that deliberately leaves main red.

## Test plan

```sh
the back-to-back case is the acceptance criterion and needs two real merged PRs; ref: main is what makes it work and the default checkout is what breaks it
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-25` AC-H2 observed for real on 2026-08-25. The merge of PR #70 triggered skill-publish run 32855883869 on main: success in 9s, 'ok - 43 skills versioned, registry in sync', then 'verify is green on this tree: every skill is versioned and the registry matches. Nothing to allocate.', then 'nothing to push'. The log contains zero 'range' lines, which is the fixture's own assertion holding on the real runner - the guard short-circuited before determine_range was ever called rather than reaching the same answer later. registry.json on main is untouched at a22c58f and verify is green there. The criterion's evidence text was written before the merge and still says NOT YET OBSERVED; this note is the observation. AC-H1 and AC-H3 remain fixture-only.
- `2026-08-25` Resolution is shared, not copied: .github/scripts/bump-lib.sh now holds skills_in, skill_exists, registry_version, next_version, level_rank and title_level, and bump-gate.sh sources it. Two halves of one pipeline reaching different conclusions about the same commit is the failure the design exists to prevent, so they run one copy of the code.
- `2026-08-25` The publisher stamps Skill-Publish: true on its own commits and skips any commit carrying it. Without that, its own chore(skills): subject maps to patch and a later run re-bumps every skill the previous run touched. The loop guard normally exits first; this is the belt to its braces and it costs one line.
- `2026-08-25` The range is <before>..HEAD, not the plan's <before>..<after>, and levels come from every commit in it rather than from git log -1. skill-version.sh bump regenerates the WHOLE registry, so a run that bumps only some of the unpublished skills on the tree it checked out writes the others' new content hashes under their old version numbers; verify then reports green and that change ships to every project as a version they already have. Proved as a check in .github/scripts/testing/run-tests.sh rather than argued.
- `2026-08-24` Poker 2026-08-24: 8 points. Sized above the plan's medium. Same iteration cost as the gate, and this one writes to main.

## Outcome

_Written by `work-order close`. Empty until then._
