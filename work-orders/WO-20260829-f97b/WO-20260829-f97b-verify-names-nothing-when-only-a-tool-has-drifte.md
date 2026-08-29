---
{
  "id": "WO-20260829-f97b",
  "slug": "verify-names-nothing-when-only-a-tool-has-drifte",
  "title": "verify names nothing when only a tool has drifted",
  "type": "bug",
  "status": "in-progress",
  "priority": "p3",
  "created": "2026-08-29",
  "updated": "2026-08-29",
  "created_at": "2026-08-29T13:41:47-05:00",
  "parent": null,
  "branch": "feat/verify-names-nothing-when-only-a-tool-has-drifte",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Approved by the user in session on 2026-08-29, in the reply that read the regression, the ticket and its non-goals and said 'approve f97b and fix it'. Lavish was not used.",
    "at": "2026-08-29"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20260829-f97b - verify names nothing when only a tool has drifted

## Problem

WO-20260829-5ad4 - verify's drift report walks the registry's tools block and names tools as missing skills scoped cmd_verify's two reporting loops to the registry's skills block, which was correct: they were calling claude/tools/skill-sync.sh a skill that does not exist, and telling the reader to run a bump that dies. The consequence is a gap that ticket's non-goals deliberately left open. On a tree where every skill is in sync and only a tool has changed - edit claude/tools/skill-sync.sh without moving its skill-tool-version: marker - verify still fails, correctly, because render_tools rehashes the file and the registry no longer matches. But it now names nothing at all. The reader gets the generic trailer, 'registry is stale. A skill's contents changed without a version bump, or the registry was hand-edited', and no line telling them it was a tool or which one. Before the fix they at least got the right filename under the wrong label. Observed 2026-08-29 in a container against a clone of main with claude/tools/skill-sync.sh edited: whole stderr was the trailer, rc 1. claude/tools/ is a live workflow - skill-sync.sh and partials/read-only-notice.md.tmpl both ship there and both carry markers - so this is a shape someone will hit.

## Scope

**In**

- a line naming a drifted tool, with advice that can actually be followed - a tool's version is a marker in the file, not something bump touches
- a case in claude/skills/skill-versioning/testing/run-tests.sh asserting a tool-only drift names the tool

**Out - non-goals**

- changing exit codes - a tool-only drift already fails and must keep failing
- reintroducing tools into the skills loops, which is the bug WO-20260829-5ad4 fixed
- a bump subcommand for tools, unless the ticket that adds one wants it

## Acceptance criteria


- [x] `AC-H1` *(human)* a tree whose skills are all in sync and whose tool has changed reports the tool by name
  - observed `2026-08-29` Observed 2026-08-29 on the real tree and on the fixture. Real tree: a clone of this branch in Podman on the digest-pinned bitnami/git base with /repo mounted read-only, claude/skills restored to origin/main so the registry matches the skills exactly, and one byte appended to claude/tools/skill-sync.sh - a tool-only drift with nothing else moving. main's copy of the script, which carries PR #80, printed the skills trailer and named nothing at all. This branch's copy, over the identical tree, printed 'tool drifted skill-sync' with both sides shown - registry sha 6904c947..., on disk 5002d658... - at the same version 2.0.0, which is the actual failure: the bytes moved and the marker did not. rc=1 on both. Fixture: the skill-versioning suite, section 'the drift report reads the skills block only', run via bump-gate.sh run-suite in a container with the source read-only. Four shapes asserted, not one - a changed tool named as a tool, a registered tool gone from disk named as 'tool gone', a tool on disk with no registry row named as 'tool unregistered', and a skill and a tool drifting together both named on one run with both trailers printed.
- [x] `AC-H2` *(human)* the advice printed for that case does not tell the reader to run bump on a tool
  - observed `2026-08-29` Observed 2026-08-29 in the same container run, on the same real-tree tool-only drift. The whole stderr for that case was the tool line, its two sides, and one trailer: 'A tool named above no longer matches its registry row', the path to claude/tools/, then 'bump does not apply here - a tool carries no frontmatter, so its version is the skill-tool-version: marker inside the file, raised by hand. Raise it, and the registry is written from it: by the publisher on main, or by init locally.' The string 'bump <skill>' does not appear, asserted with neg in the suite rather than read by eye. That matters because 'skill-version.sh bump read-only-notice --patch' - the advice a reader got before PR #80 - dies with 'no such skill', so it was not merely mislabelled, it was unfollowable. The trailers are gated on something of that kind having been named, and the pairing is asserted both ways: on a tree where a skill and a tool drift together both trailers print, and on a tool-only tree only the tool one does.
- [x] `AC-H3` *(human)* no skill is named on that run, and the exit code is still 1
  - observed `2026-08-29` Observed 2026-08-29, same run. On the tool-only drift no line matching '^(drifted|stale entry|not in registry)' appears - the assertion carried forward from WO-20260829-5ad4 - verify's drift report walks the registry's tools block and names tools as missing skills, and still passing, so this ticket did not undo that one by reaching back into the skills loops. rc is 1, checked directly rather than inferred: 'a tool-only drift is still exit 1' asserts the code is exactly 1 and not merely non-zero. Gating the trailers made one further state reachable, and it is covered rather than left silent: a registry that differs outside both blocks - proved with a hand-edited generator line - now prints 'no skill or tool entry accounts for it' and points at init, where before this ticket it would have exited 1 printing nothing. skill-versioning's suite is at 148, up from 131.

## Test plan

```sh
skill-versioning's own suite, the section added by WO-20260829-5ad4, which already builds a fixture tool and drives a tool-only drift
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-29` A lifecycle edge hit while starting this ticket, worth knowing and on no ticket. work-order.sh approve writes the ticket file and INDEX.md, and start refuses a dirty tree - so a ticket created and left in draft in an earlier pull request strands its own approval: approve dirties the tree, start will not run, and the only branch to commit the approval on is the one start has not created yet. The normal path hides this because new and approve ride the previous ticket's close-out pull request, which is what happened for WO-20260829-5ad4. Resolved here by committing the approval on local main, letting start branch from it, then rewinding local main to origin/main with git branch -f, so nothing was ever pushed to main. A start --on-current-branch flag, or approve leaving nothing to commit, would remove the edge.

## Outcome

_Written by `work-order done`. Empty until then._
