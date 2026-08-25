---
{
  "id": "WO-20260824-7a63",
  "slug": "close-out-moves-onto-the-branch-done-archives-cl",
  "title": "Close-out moves onto the branch: done archives, cleanup only deletes branches",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T20:32:55-05:00",
  "parent": null,
  "branch": "feat/close-out-moves-onto-the-branch-done-archives-cl",
  "pr": 62,
  "merge_sha": null,
  "closed": "2026-08-24",
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


- [x] `AC-H1` *(human)* after done, the ticket is under work-orders/archive/<year>/ with INDEX.md regenerated, and every change is uncommitted
  - observed `2026-08-24` Case 090-done-archives-on-branch.sh, in Podman on the pinned debian digest with --network=none. Against a real git project it captures HEAD before running done, then asserts: done exits 0, HEAD is unchanged so done committed nothing, git status is non-empty so the move is in the working tree, the caller is still on the feature branch, the ticket is under work-orders/archive/2026/, status is done, closed is stamped, the active-tree directory is gone, INDEX.md still finds it, and archive/README.md and archive/2026/README.md were regenerated. It also asserts merge_sha is absent and "pr": 7 present. 14 checks, all green.
- [x] `AC-H2` *(human)* cleanup adds no commit to main and leaves neither the local nor the remote branch
  - observed `2026-08-24` Case 095-cleanup-deletes-branches.sh, same container, against a real bare origin with a stubbed gh reporting MERGED. It records origin/main before running cleanup and asserts afterwards that origin/main is byte-identical, so cleanup added no commit. It also asserts the archive was already on origin/main BEFORE cleanup ran, which proves the record arrived through the pull request rather than through this command. Both branches are gone: git rev-parse --verify fails locally and git ls-remote --exit-code fails on the remote. A second cleanup exits 0 and leaves origin/main unchanged again, so it is idempotent. 8 checks, all green. Case 070 separately asserts it refuses at rc 3 when gh reports OPEN and leaves the branch intact.
- [x] `AC-H3` *(human)* workflow-version.sh verify fails on a workflows/ doc carrying no version
  - observed `2026-08-24` Container, real workflows/ tree copied out of a read-only mount. An unversioned workflows/stray.md made verify print "unversioned stray" then "run workflow-version.sh init to stamp them" at rc 1; removing it returned "ok - 1 workflow document(s) versioned" at rc 0. The suite additionally covers a marker that is present but not semver: it is reported as "malformed gamma (1.0)" rather than as unversioned, and is deliberately NOT told to run init, because init skips a file that already has a marker and would report success having done nothing.
- [x] `AC-H4` *(human)* nothing under tools/ appears in claude/skills/registry.json
  - observed `2026-08-24` Same container run. Grepping claude/skills/registry.json for workflow-version, close-out-procedure and dotfiles-tools returned absent for all three, and the tools block still renders as an empty object. render_tools only ever walks claude/tools/, so the repo-local tools/ tree cannot reach the registry. skill-version.sh verify printed "ok - 43 skills versioned, registry in sync" at rc 0 after the work-order major bump.

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
