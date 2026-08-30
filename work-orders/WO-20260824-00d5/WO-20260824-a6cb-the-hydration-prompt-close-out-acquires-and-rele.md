---
{
  "id": "WO-20260824-a6cb",
  "slug": "the-hydration-prompt-close-out-acquires-and-rele",
  "title": "The hydration-prompt close-out acquires and releases a treehouse slot",
  "type": "feature",
  "status": "in-progress",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-30",
  "created_at": "2026-08-24T13:19:13-05:00",
  "parent": "WO-20260824-00d5",
  "branch": "feat/the-hydration-prompt-close-out-acquires-and-rele",
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
    "WO-20260824-238b",
    "WO-20260824-c6b0"
  ]
}
---

# WO-20260824-a6cb - The hydration-prompt close-out acquires and releases a treehouse slot

## Problem

The close-out currently runs wherever the session happens to be. It should take a slot keyed by ticket ID so treehouse status becomes the live map of which agent holds which workbench. The gate finding makes the release the load-bearing half: a dirty tree makes treehouse return prompt, take the no-TTY default, abort, leave the slot leased and exit 0.

## Scope

**In**

- acquiring a slot with the ticket ID as --lease-holder
- returning the slot and asserting it is actually free, not reading the exit code
- treehouse status as the live map of holder by ticket ID

**Out - non-goals**

- changing the shape of a hydration entry

## Acceptance criteria


- [x] `AC-H1` *(human)* a close-out that leaves a dirty tree reports a failure instead of reporting success
  - observed `2026-08-30` 2026-08-30 Proved twice, offline and live. Offline, claude/skills/hydration-prompt/testing/run-tests.sh in Podman via bump-gate run-suite, 86 PASS 0 FAIL (was 47): with treehouse stubbed to exit 0 while leaving the lease in place, slot.sh release exits 5, says "still leased", names uncommitted changes as the cause and hands back the treehouse return command that frees it. The mirror case is the one that proves the claim rather than restating it - a stubbed return that exits 1 having actually freed the slot is a success, so the exit code is not consulted in either direction. Live, testing/live-check.sh against the real treehouse v2.3.0 bind-mounted read-only with TREEHOUSE_ROOT redirected into container scratch, 19 PASS 0 FAIL: the raw binary was observed exiting 0 on a dirty tree with the slot still leased ("Worktree has uncommitted changes. Clean and return? [Y/n] Aborted.", rc=0, 1 lease still recorded), and slot.sh release then exited 5 on that exact pool state. The assertion reads treehouse status --json for the ticket ID, never $?.
- [x] `AC-H2` *(human)* no slot is left leased after a successful close-out
  - observed `2026-08-30` 2026-08-30 testing/live-check.sh, real treehouse v2.3.0 in Podman, 19 PASS 0 FAIL. After a clean release, slot.sh holder --holder WO-LIVE-a6cb exits 3, meaning treehouse status --json records no lease for the ticket. Asserted as a post-state, not inferred: keyed on lease_holder rather than the slot status field, because a freed slot inspected from inside its own directory reports "you're here" rather than "available" and the close-out is normally standing in exactly that directory - a separate live case runs the release from inside the slot and confirms it exits 0 with the slot genuinely free. Releasing again is also 0, so re-running a finished close-out does not invent a leak. The run also asserts nothing was written to $HOME/.treehouse, so the live pool was never touched.

## Test plan

```sh
bash claude/skills/hydration-prompt/testing/run-tests.sh in Podman, plus the dirty-tree case the gate probe already characterised
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-30` Retro. The mechanism landed as scripts/slot.sh rather than as verbs on hydration.sh, because WO-20260824-c6b0 - skill-onboard.sh brings an existing project onto the sync inherits it, and a second caller reaching for "hydration.sh release --project ." would be dragging HYDRATION.md semantics into a script that writes no hydration entry. slot.sh has its own --help, its own exit codes and no dependency on anything in this skill, and its header names skill-onboard as the second caller with --holder skill-onboard. Two probe findings changed the design and neither was in --help. First, treehouse get does NOT refuse a holder that already leases a slot: asking twice with one --lease-holder hands out a second slot and records the same holder against both, so acquire had to grow the guard itself. live-check.sh asserts that raw double-lease is still real before asserting slot.sh refuses it, so the day treehouse grows its own guard this goes red rather than leaving a redundant check nobody dares remove. Second, and this one nearly shipped as a bug: a freed slot inspected from INSIDE its own directory reports its status as "you're here", not "available". The obvious implementation - return the slot, then check that path status is available - would therefore have reported a leak on every clean close-out, because the close-out is standing in the slot it just returned. Keying on lease_holder, which treehouse clears to "" on a successful return, is what survives it. There is a case for this in both suites. The split between the two suites is the skill-testing.md live-infrastructure pattern and it earned itself here. The stub is the only way to produce a return that exits 0 without freeing anything AND a return that exits 1 having freed it, which is the pair that proves the exit code is ignored in both directions rather than just in the failing one. The live check is the only way to prove treehouse still behaves the way that stub describes. Neither is sufficient alone and the header of each says which half it owns. Cost paid twice on the way: the stub initially applied TH_RC to its status subcommand as well as to get and return, so every case scripting a non-zero return failed as an unreadable pool instead; and an invented shellcheck digest failed with "manifest unknown", which is the trap already written into HYDRATION.md.
- `2026-08-24` Poker 2026-08-24: 3 points. Small, and the release half is the load-bearing part.

## Outcome

_Written by `work-order close`. Empty until then._
