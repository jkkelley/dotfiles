---
{
  "id": "WO-20260824-9712",
  "slug": "end-to-end-proof-in-a-scratch-project-including-",
  "title": "End-to-end proof in a scratch project, including the lost-receipt case",
  "type": "chore",
  "status": "done",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-28",
  "created_at": "2026-08-24T13:19:09-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": "feat/end-to-end-proof-in-a-scratch-project-including-",
  "pr": 76,
  "merge_sha": null,
  "closed": "2026-08-28",
  "approval": {
    "via": "override",
    "reason": "Reviewed and approved on PR #55 on GitHub, which is where the whole cut was read as one diff. Lavish was offered and declined in favour of the PR.",
    "at": "2026-08-24"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-316d"
  ],
  "blocks": [
    "WO-20260824-8cd1",
    "WO-20260824-c6b0",
    "WO-20260824-81a6",
    "WO-20260824-b21b"
  ]
}
---

# WO-20260824-9712 - End-to-end proof in a scratch project, including the lost-receipt case

## Problem

The hook only proves itself by firing. Five properties matter and none can be observed from a unit test: that a session start installs the skill, that a hand-authored skill beside it survives, that a manifest removal removes, and above all that a lost receipt orphans a managed directory rather than deleting a local one.

## Scope

**In**

- a scratch repository with a manifest naming hydration-prompt
- a hand-authored skill placed deliberately beside the managed one
- removing from the manifest and re-syncing
- deleting the receipt and re-syncing

**Out - non-goals**

- automating any of this - rung 5 is manual and that is the point

## Acceptance criteria


- [x] `AC-H1` *(human)* on first session start the skill is installed with the notice rendered into it
  - observed `2026-08-28` Real session start in /tmp/skill-sync-proof, source startup, hook "$HOME/.local/bin/skill-sync" --boot from ~/.claude/settings.json. Hook stdout, read out of the session transcript 7984b616 and not out of the agent reply: "owned hydration-prompt" then "skill-sync: 1 skills in place (1 installed, 0 removed). Source jkkelley/dotfiles@main." .claude/skills/hydration-prompt/SKILL.md exists carrying version 2.0.4 and the rendered notice "> **This copy is read-only.**" immediately after the "# Hydration prompt" heading. Receipt sha ce66fada matches the published registry entry for hydration-prompt 2.0.4. Rung 1 first: --plan printed "owned hydration-prompt", exit 0, and created no .claude/cache at all.
- [x] `AC-H2` *(human)* the hand-authored skill beside it is untouched, unread and unreported
  - observed `2026-08-28` A hand-authored skill .claude/skills/local-notes/ (SKILL.md + notes.txt, in no registry) sat beside the managed one for all six session starts. Untouched: SKILL.md c44fdd46 and notes.txt 3862f536 byte-identical at every step, and the tree digest 3438ce8c identical across the lost-receipt re-sync. Unreported: the string local-notes does not occur in the skill-sync stdout of any of the six sessions, proved by walking every string of every transcript JSON object rather than by reading the agent reply. Unread: the four plan tags owned, previous, dropped and unknown named only hydration-prompt and no-such-skill, never local-notes.
- [x] `AC-H3` *(human)* removal from the manifest removes the directory, and a deleted receipt deletes nothing
  - observed `2026-08-28` Removal: manifest emptied to "use = [ ]", stamp cleared, real session start 7cbe35b1 printed "previous hydration-prompt" then "dropped hydration-prompt" then "0 skills in place (0 installed, 1 removed)". .claude/skills/hydration-prompt gone, local-notes survived. Lost receipt: hydration-prompt reinstalled (5 files, tree digest e1dfaeeb), then skills-receipt.json deleted and the manifest emptied, then real session start a5a5d8b4 printed only "0 skills in place (0 installed, 0 removed)" with no plan tag at all. The managed directory SURVIVED byte-identical at e1dfaeeb - orphaned, not deleted - and local-notes survived too. With no receipt, previous is empty, so dropped is empty, so there is no rm -rf set. Reproduced independently in a container against the same binary (sha 6904c947, mounted read-only, network on, debian@sha256:328d1649): case 5 managed dir SURVIVED yes, byte-identical yes, and the same digest e1dfaeeb as the host.
- [x] `AC-H4` *(human)* the receipt records owned correctly at each of the four steps
  - observed `2026-08-28` Receipt read after every step, not once. Step 1 install: owned ["hydration-prompt"], skills.hydration-prompt 2.0.4/ce66fada. Step 2 idempotent re-sync: owned ["hydration-prompt"], unchanged. Step 3 manifest removal: owned [] and skills {}. Step 4a restage: owned ["hydration-prompt"]. Step 4b lost receipt: owned [] and skills {} - correct, because the sync no longer owns the orphan it can no longer prove it installed. Churn guard observed rather than assumed: session ff73d60b 20s after the first was silent and synced nothing (STAMP_MAX_AGE 900); .sync-stamp was removed before each subsequent step as setup, and that is the only thing removed that was not under test.

## Test plan

```sh
manual, rung 5. A scratch repository and four real session starts
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-28` Rule 14 required a new section. Neither container-sandbox/SKILL.md nor references/skill-testing.md had a pattern for a machine-level hook, which is the one subject that cannot be containerised honestly: a container has no ~/.claude/settings.json entry, and mounting a copy proves a copy. Added "Verifying a hook that only fires on a real session start" to container-sandbox/SKILL.md, splitting the proof the way skill-testing.md already splits run-tests.sh from live-check.sh. It records the trap this ticket actually hit: asked to quote the hook output verbatim, the spawned agent returned two lines and silently dropped a third, and the dropped line was the "previous hydration-prompt" plan tag. The transcript jsonl is the raw record and is the only sound way to prove the negative in AC-H2.
- `2026-08-24` Poker 2026-08-24: 5 points. Sized above the plan's small. Five scenarios, each needing a real session start, plus a scratch repo staged with a hand-authored skill beside a managed one.

## Outcome

_Written by `work-order close`. Empty until then._
