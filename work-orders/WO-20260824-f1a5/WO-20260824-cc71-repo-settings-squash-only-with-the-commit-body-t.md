---
{
  "id": "WO-20260824-cc71",
  "slug": "repo-settings-squash-only-with-the-commit-body-t",
  "title": "Repo settings: squash-only, with the commit body taken from the PR description",
  "type": "chore",
  "status": "done",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:05-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": "feat/repo-settings-squash-only-with-the-commit-body-t",
  "pr": 57,
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


- [x] `AC-H1` *(human)* all four settings read back from the API with the intended values
  - observed `2026-08-24` gh api repos/jkkelley/dotfiles --jq "{squash_merge_commit_title,squash_merge_commit_message,allow_merge_commit,allow_rebase_merge}" read back {"allow_merge_commit":false,"allow_rebase_merge":false,"squash_merge_commit_message":"PR_BODY","squash_merge_commit_title":"PR_TITLE"} on 2026-08-24. Before the change the same read returned COMMIT_MESSAGES, COMMIT_OR_PR_TITLE, true, true. This is a fresh read issued separately from the PATCH, not the PATCH response.
- [x] `AC-H2` *(human)* a Bump: trailer written in a PR description is returned by git interpret-trailers --parse on the resulting main commit
  - observed `2026-08-24` Throwaway PR #56 carried "Bump: nothing=patch" in its description and nothing in its branch commit message. After the squash merge, git log -1 --format=%B origin/main | git interpret-trailers --parse printed exactly "Bump: nothing=patch", and the subject was the PR title plus (#56). Merge sha d7f2f8c44ac2b010bed5cf09e43db20b636d5b64. The trailer can only have come from the PR body, so PR_BODY is carrying it through the real merge path.

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

- `2026-08-24` Settings applied and both criteria evidenced. Merge commits and rebase merges are now off repository-wide, so squash is the only path into main for every future PR, including this one. The throwaway probe was PR #56; its branch chore/trailer-probe is deleted locally and on the remote, and the file it added, notes/trailer-probe.md, is removed by this ticket PR so main is left with no scaffolding. Branch protection and required status checks were left alone - they are out of scope and the checks arrive with WO-20260824-2ad1.
- `2026-08-24` Poker 2026-08-24: 1 points. No code. Sized as a gate rather than as work.

## Outcome

_Written by `work-order close`. Empty until then._
