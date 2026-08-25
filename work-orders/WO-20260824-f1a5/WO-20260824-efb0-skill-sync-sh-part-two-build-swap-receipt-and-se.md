---
{
  "id": "WO-20260824-efb0",
  "slug": "skill-sync-sh-part-two-build-swap-receipt-and-se",
  "title": "skill-sync.sh part two: build, swap, receipt, and self-update",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:07-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": "feat/skill-sync-sh-part-two-build-swap-receipt-and-se",
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
  "depends_on": [
    "WO-20260824-5b89"
  ],
  "blocks": [
    "WO-20260824-2ad1",
    "WO-20260824-360d",
    "WO-20260824-bb0d"
  ]
}
---

# WO-20260824-efb0 - skill-sync.sh part two: build, swap, receipt, and self-update

## Problem

With the owned set resolved, the sync has to apply it without ever being able to destroy a hand-authored skill sitting beside a managed one. Every destructive decision is receipt-driven, the parent directory is never removed wholesale, and the script has to be able to replace itself while it is running - which is only safe because bash reads a script lazily by byte offset.

## Scope

**In**

- sweeping stale .claude/cache/.sync.* older than an hour before starting
- building into a temp directory, rendering the notice, and swapping each owned directory individually
- removing a dropped directory only when the receipt says the sync installed it
- writing the receipt with owned and status, and the stamp
- self-update by mv to .bak, forking with SKILL_SYNC_CHILD=1, rolling back on failure
- locking with mkdir, not flock, per Rule 17

**Out - non-goals**

- the resolution half, delivered by part one
- any use of flock, cmp or diff, none of which are portable

## Acceptance criteria


- [x] `AC-H1` *(human)* a hand-authored skill beside a managed one is untouched, unread and unreported across a full sync
  - observed `2026-08-24` Group 11 of claude/tools/testing/run-tests.sh, all four rows of the ownership matrix off one sync. some-local-thing is planted in .claude/skills/ beside two managed skills, is in neither the manifest nor the receipt, and is chmod 000 for the duration of the run - so a sync that so much as opened it would fail rather than pass quietly. Afterwards: the directory is still there, byte-identical by sha256, absent from stdout, absent from stderr, and not claimed by the receipt. The parent still holds all three names, which is the assertion that fails if the sync ever treats .claude/skills/ as its own. Row 1 replaced (LOCAL-MARKER gone, upstream body present, multi-file skill whole), row 2 installed, row 3 removed. 193 PASS 0 FAIL in Podman, --network=none, on the debian@sha256:328d1649 base.
- [x] `AC-H2` *(human)* a skill dropped from the manifest is removed when the receipt claims it, and orphaned rather than deleted when the receipt is missing
  - observed `2026-08-24` Group 12. With no receipt at all a previously managed directory is orphaned rather than deleted and a local one is untouched, while the declared skill still installs. A corrupt receipt does the same rather than throwing - exit 0, nothing removed, and the corrupt file is replaced by a readable one. Group 11 covers the other half: a name in the receipt and no longer in the manifest is removed, and the receipt stops claiming it. Receipt names are validated against NAME_RE in read_previous, so a receipt saying ../../etc is refused by name on stderr and never becomes a path, while the valid name beside it is still dropped - part one's check on manifest names does not cover this, they read different files.
- [x] `AC-H3` *(human)* the sync always exits 0, and every failure path prints loudly
  - observed `2026-08-24` Groups 13, 15 and 16, plus part one's group 7 which still passes unchanged. Every failure path asserts exit 0 and the loud print separately: unreachable registry, unreachable archive, an archive that is not a tarball, a registry entry the source tree does not have, a lock held by another sync, and a self-update that rolls back. Each also asserts the tree survived - snapshot before and after .claude/skills/ - and that the receipt records status failed while still claiming what it owned. A hard kill mid-download (kill -9 during the archive fetch) leaves every directory at its previous version, none half-written, and the build directory and lock behind, which the next run's sweep and stale-lock break then clear. Four concurrent syncs finish with an intact tree, one well-formed receipt, no lock and no build directory.
- [x] `AC-H4` *(human)* the comment explaining why self-update is mv and not cp is present in the script
  - observed `2026-08-24` Group 17, first four checks: the literal string '`mv`, never `cp`' is in the source, as is the sentence explaining that cp truncates and rewrites the live inode, and SKILL_SYNC_CHILD appears in the source. Backed by the behaviour rather than left as a grep: a newer published version is fetched, the .bak keeps the version that was running, and a replacement that does not run, a download that fails and a truncated download are each rolled back to it with a loud two-line message that says the skills themselves are current. A run with SKILL_SYNC_CHILD=1 does the real work and does not self-update, which is the recursion bound. A published version equal to or older than the running one is not fetched at all.

## Test plan

```sh
bash claude/tools/testing/run-tests.sh in Podman per Rule 14, covering the ownership matrix and the four failure modes named in the plan
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Two bugs part one shipped, found by the cases this ticket added, fixed here. load_registry read its awk output with IFS=tab, and a tab is IFS whitespace, so bash collapsed two of them into one and every skill with an empty requires - 41 of the 43 - shifted its version into the field after it. It was invisible while only two fields were read. The separator is now a pipe, which cannot appear in a name that passed NAME_RE. Second, the lock is a directory inside .claude/cache/, so a project on its very first sync - a manifest and nothing else - could not take it, and the symptom was a 20-second wait and a loud failure on the single most common state this runs in. cmd_boot now creates the cache before the sweep and the lock.
- `2026-08-24` Three decisions the design documents do not settle, taken in the open. (1) The lock gets its own five-minute stale window, LOCK_MAX_AGE, separate from the hour the build sweep uses. A lock is only ever held by a running sync and a sync cannot outlive the 30-second hook that started it, so an hour would mean one killed hook blocks every session on the machine for the rest of that hour. (2) A failed sync deliberately does not write the stamp. Writing it would suppress the next session's attempt and with it the two-line warning that session would have printed, turning a loud failure into a silent one fifteen minutes wide - which is the defect the whole design exists to remove. The cost is retrying a broken fetch. (3) The receipt's source is jkkelley/dotfiles@main, not @<sha> as the spec's example shows. A codeload tarball fetch does not yield a commit sha and a second API call to get one is not worth a diagnostic field.
- `2026-08-24` Poker 2026-08-24: 8 points. The destructive half. Sized above part one for the ownership matrix, the four failure modes and the self-update path.

## Outcome

_Written by `work-order close`. Empty until then._
