---
{
  "id": "WO-20261016-2447",
  "slug": "dotfiles-runs-ci-yml-and-merge-on-green-yml-from",
  "title": "dotfiles runs ci.yml and merge-on-green.yml from the pr-flow templates (T7)",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:39:08+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": "feat/dotfiles-runs-ci-yml-and-merge-on-green-yml-from",
  "pr": 185,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Claude seat; design PR 169 merged under ORD-0550 is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-1440"
  ],
  "blocks": [
    "WO-20261016-17dc"
  ]
}
---

# WO-20261016-2447 - dotfiles runs ci.yml and merge-on-green.yml from the pr-flow templates (T7)

## Contents

- Problem
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

Build ticket from claude/workflow/docs/pr-process/pr-process.md section 13; files: .github/workflows/ci.yml .github/workflows/merge-on-green.yml .github/workflows/skill-publish.yml

## Scope

**In**

- .github/workflows/ci.yml .github/workflows/merge-on-green.yml .github/workflows/skill-publish.yml

**Out - non-goals**

- any file not listed in Scope
- a review gate or gh pr merge --auto

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the named test cases pass in podman
  - observed `2026-10-16` PR 185 checks pass=7 skipping=3 (deviation, recorded in the commit: no ci.yml in dotfiles, skill PR gate is the path-selected CI, REQUIRED_CHECK='what has to run')
- [x] `AC-H2` *(human)* files touched equal the Scope list
  - observed `2026-10-16` files: .github/workflows/merge-on-green.yml (rendered, no hand edit), .github/workflows/skill-publish.yml (workflow_dispatch input before)

## Test plan

```sh
UAT: this PR's own checks, then the next PR merges by the Action
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
