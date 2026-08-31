---
{
  "id": "WO-20260824-c6b0",
  "slug": "skill-onboard-sh-brings-an-existing-project-onto",
  "title": "skill-onboard.sh brings an existing project onto the sync",
  "type": "feature",
  "status": "done",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-30",
  "created_at": "2026-08-24T13:19:10-05:00",
  "parent": "WO-20260824-00d5",
  "branch": "feat/skill-onboard-sh-brings-an-existing-project-onto",
  "pr": 86,
  "merge_sha": null,
  "closed": "2026-08-30",
  "approval": {
    "via": "override",
    "reason": "Reviewed and approved on PR #55 on GitHub, which is where the whole cut was read as one diff. Lavish was offered and declined in favour of the PR.",
    "at": "2026-08-24"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-9712",
    "WO-20260824-a6cb"
  ],
  "blocks": [
    "WO-20260824-6a33",
    "WO-20260824-238b"
  ]
}
---

# WO-20260824-c6b0 - skill-onboard.sh brings an existing project onto the sync

## Problem

Every project that already exists has committed skills, no manifest, no gitignore entry and the old prose in its CLAUDE.md. Doing that by hand in each one is where the mistakes come from. The script has to work without ever touching the user's working tree, which means a treehouse slot, and the gate finding proved it must assert the slot went free rather than trusting an exit code.

## Scope

**In**

- taking a treehouse slot with --lease-holder skill-onboard, never stashing
- writing .claude/skills.toml, the gitignore lines and the CLAUDE.md block
- git rm -r --cached .claude/skills/ only where they were committed
- commit, push, PR, squash-merge, delete the branch
- returning the slot and asserting it is free afterwards

**Out - non-goals**

- installing the hook - that is machine level and setup.sh owns it
- running this against any real repository, which is a separate deliberate act

## Acceptance criteria


- [x] `AC-H1` *(human)* run against a scratch repository with committed skills it lands a merged PR and leaves no leased slot behind
  - observed `2026-08-30` Verified in Podman, claude/tools suite, section "AC-H1: a scratch repository with committed skills lands a merged PR" and the two sections under it. The fixture is a real git repository with a real bare origin, three skills committed under .claude/skills/, a CLAUDE.md carrying the prose session-start check and a .gitignore of its own; the workbench is a real git worktree of it, handed out by a stubbed treehouse; gh is stubbed and its "pr merge" performs an actual squash-merge into the bare origin and deletes the remote branch, so every assertion below is against the repository rather than against the stub log. Observed: the run exits 0; a pull request was opened and squash-merged; the remote and local branches are gone; origin/main carries .claude/skills.toml declaring container-sandbox and work-order, a .gitignore blanketing **/.claude/skills/ and .claude/cache/ with the template comments attached, and a CLAUDE.md whose "## Skills" section is byte-for-byte the templates one with the skills:begin/skills:end pair, the prose session-start check gone and the projects own sections intact; git no longer tracks the two declared skills and still tracks the hand-authored one; the pool records no lease afterwards; the users working tree is byte-for-byte what it was. The manifest it wrote was then fed to skill-sync --plan against the real registry.json and both skills came back owned with nothing unknown. Mutation-checked: making on_exit trust the release exit code turns the AC-H2 assertions red, and making write_manifest also write into the project turns the working-tree assertion red. Suite total 350 checks, 0 failures, up from 258.
- [x] `AC-H2` *(human)* a dirty working tree makes the run report a failure rather than exit 0 having done nothing
  - observed `2026-08-30` Verified in Podman, claude/tools suite, section "AC-H2: a dirty workbench fails loudly instead of exiting 0". The stubbed treehouse reproduces the recorded v2.3.0 defect verbatim: return on a worktree with uncommitted changes prints "| Worktree has uncommitted changes. Clean and return? [Y/n] Aborted.", frees nothing and exits 0. A file is left in the workbench before the run, as an earlier crashed run would leave it. Observed: the run does not exit 0; it exits 5, which is separate from an ordinary failure because a stranded workbench wants a human rather than a retry; stderr says STILL LEASED and carries slot.sh message naming the slot and the --if-lease-holder command that frees it; the pool still records skill-onboard as the holder; no pull request was opened; origin/main is at the same commit; the users working tree is untouched; and the debris is still there rather than discarded, because release never passes --force. The paired case "a clean failure still returns the workbench" proves the other half: a stubbed gh pr create failure exits non-zero, is NOT reported as exit 5, and the workbench goes back.

## Test plan

```sh
a scratch repository in a container, plus the dirty-tree case that the gate probe showed exits 0 while leaking a slot
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-30` Now depends on WO-20260824-a6cb - The hydration-prompt close-out acquires and releases a treehouse slot, an edge added 2026-08-29 and not present when this ticket was cut. The reason is in both tickets' own Problem sections and nowhere else: this one says the script 'has to work without ever touching the user's working tree, which means a treehouse slot, and the gate finding proved it must assert the slot went free rather than trusting an exit code', and a6cb says 'the gate finding makes the release the load-bearing half: a dirty tree makes treehouse return prompt, take the no-TTY default, abort, leave the slot leased and exit 0'. Same finding, same failure mode, and a6cb is where it gets handled first. git grep over work-orders/ finds that language on these two tickets and on no others. Without the edge, next offered this ticket - the largest in the epic and the only one that touches other people's projects - before the acquire-and-release it depends on had been proved, and the leaked-slot-at-exit-0 case would have been rediscovered inside it.
- `2026-08-24` Poker 2026-08-24: 5 points. Sized below medium-plus: the risky half, asserting the slot actually went free, is already solved knowledge from the gate probe.

## Outcome

_Written by `work-order close`. Empty until then._
