---
{
  "id": "WO-20260824-cc71",
  "slug": "repo-settings-squash-only-with-the-commit-body-t",
  "title": "Repo settings: squash-only, with the commit body taken from the PR description",
  "type": "chore",
  "status": "draft",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:05-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": null,
  "pr": null,
  "merge_sha": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20260824-360d"
  ]
}
---

# WO-20260824-cc71 - Repo settings: squash-only, with the commit body taken from the PR description

## Problem

The publisher reads a Bump: trailer out of the merge commit. Under the default squash_merge_commit_message setting the PR body never reaches the commit, so every trailer would silently vanish and every bump would be dropped. Nothing that depends on a trailer can be built until this is settled.

## Scope

**In**

- squash_merge_commit_title=PR_TITLE and squash_merge_commit_message=PR_BODY
- disabling merge commits and rebase merges
- a throwaway PR that proves a trailer survives the real path

**Out - non-goals**

- branch protection rules
- required status checks, which arrive with the PR gate

## Acceptance criteria


- [ ] `AC-H1` *(human)* all four settings read back from the API with the intended values
- [ ] `AC-H2` *(human)* a Bump: trailer written in a PR description is returned by git interpret-trailers --parse on the resulting main commit

## Test plan

```sh
gh api repos/jkkelley/dotfiles --jq '{squash_merge_commit_title,squash_merge_commit_message,allow_merge_commit,allow_rebase_merge}' then merge a throwaway PR and read git log -1 --format=%B on main
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 1 points. No code. Sized as a gate rather than as work.

## Outcome

_Written by `work-order close`. Empty until then._
