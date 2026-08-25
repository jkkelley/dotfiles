---
{
  "id": "WO-20260824-7a63",
  "slug": "close-out-moves-onto-the-branch-done-archives-cl",
  "title": "Close-out moves onto the branch: done archives, cleanup only deletes branches",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T20:32:55-05:00",
  "parent": null,
  "branch": null,
  "pr": null,
  "merge_sha": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Scoped and agreed in session before the ticket was cut: close-out moves onto the branch, cleanup only deletes branches, repo-local tools/ tree kept out of the registry.",
    "at": "2026-08-24"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20260824-7a63 - Close-out moves onto the branch: done archives, cleanup only deletes branches

## Problem

Closing a ticket costs one pull request plus a second, separate commit written straight to main after the merge. The only thing forcing that split is merge_sha, a field that stores data already derivable from the PR number forever. The split also creates an ordering trap: done and the hydration entry must ride the PR, and if they do not, close refuses and the ticket costs a second pull request to carry them.

## Scope

**In**

- done archives the ticket: status, closed, git mv to work-orders/archive/<year>/, prune, reindex, all left uncommitted so it rides the PR
- close renamed to cleanup, writes nothing, deletes the local and remote branch, keeps only the PR-is-MERGED assertion
- merge_sha is no longer written; pr remains the durable pointer
- a repo-local tools/ tree with its own CLAUDE.md declaring it is never vendored
- tools/workflow-version.sh at 1.0.0 and workflows/close-out-procedure.md at 1.0.0
- tools/testing/ with a Containerfile on the existing pinned debian digest
- root CLAUDE.md post-merge cleanup section rewritten

**Out - non-goals**

- extending skill-version.sh to know about a second tree - the coupling this deliberately avoids
- a generated index or registry for workflows/ - there is no second consumer to justify one
- registering anything under tools/ in the registry tools block
- rewriting merge_sha out of tickets already archived
- creating claude/tools/testing/, which stays with WO-20260824-5b89

## Acceptance criteria


- [ ] `AC-H1` *(human)* after done, the ticket is under work-orders/archive/<year>/ with INDEX.md regenerated, and every change is uncommitted
- [ ] `AC-H2` *(human)* cleanup adds no commit to main and leaves neither the local nor the remote branch
- [ ] `AC-H3` *(human)* workflow-version.sh verify fails on a workflows/ doc carrying no version
- [ ] `AC-H4` *(human)* nothing under tools/ appears in claude/skills/registry.json

## Test plan

```sh
bash tools/testing/run-tests.sh and bash claude/skills/work-order/testing/run-tests.sh, both in Podman per Rule 14
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order close`. Empty until then._
