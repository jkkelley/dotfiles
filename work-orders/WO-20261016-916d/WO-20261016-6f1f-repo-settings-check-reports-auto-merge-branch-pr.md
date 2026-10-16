---
{
  "id": "WO-20261016-6f1f",
  "slug": "repo-settings-check-reports-auto-merge-branch-pr",
  "title": "repo-settings-check reports auto-merge, branch protection and merge workflow per repo, read-only",
  "type": "feature",
  "status": "in-progress",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:19:50+00:00",
  "parent": "WO-20261016-916d",
  "branch": "feat/repo-settings-check-reports-auto-merge-branch-pr",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Claude seat: owner rule bars Lavish for Claude runtimes; brief BR-20261016-a2a-guard from the architect is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-6f1f - repo-settings-check reports auto-merge, branch protection and merge workflow per repo, read-only

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

P2

## Scope

**In**

- claude/workflow/a2a-guard/repo-settings-check.sh

**Out - non-goals**

- changing any setting

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* one status code line per repo

## Test plan

```sh
make repo-settings-check REPOS=jkkelley/dotfiles
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` Built on feat/a2a-guard, the brief's one branch for this epic; the per-ticket branch start minted was empty and removed.

## Outcome

_Written by `work-order done`. Empty until then._
