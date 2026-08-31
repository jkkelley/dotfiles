---
{
  "id": "WO-20260824-d058",
  "slug": "remove-the-inline-read-only-notice-from-the-othe",
  "title": "Remove the inline read-only notice from the other 42 SKILL.md files",
  "type": "chore",
  "status": "in-progress",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-31",
  "created_at": "2026-08-24T13:19:12-05:00",
  "parent": "WO-20260824-00d5",
  "branch": "feat/remove-the-inline-read-only-notice-from-the-othe",
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
    "WO-20260824-316d"
  ],
  "blocks": [
    "WO-20260824-79b6",
    "WO-20260824-238b"
  ]
}
---

# WO-20260824-d058 - Remove the inline read-only notice from the other 42 SKILL.md files

## Problem

With the notice rendered at install time, 42 files still carry it inline. A copy that keeps its committed notice and also receives a rendered one shows the notice twice. This is mechanically trivial and is the riskiest mechanical change in the plan, because it touches every skill in the repository at once.

## Scope

**In**

- removing lines 9 to 14 from all 42 remaining skills
- one PR, titled fix(skills): remove the inline read-only notice, now rendered at install

**Out - non-goals**

- hand-written trailers - 42 of them would be 42 chances to typo a skill name
- any frontmatter change whatsoever

## Acceptance criteria


- [x] `AC-H1` *(human)* frontmatter is byte-identical across all 42 files afterwards: name, description, version, in that order
  - observed `2026-08-31` Container run on a clone of the branch at 3a2b90a, base origin/main 2feac19, bitnami/git pinned by digest, --network=none, /repo mounted ro. For all 43 skills the frontmatter block was extracted from HEAD and from origin/main and compared: 43 compared, 0 differing. Key order asserted separately: all 43 lead name, description, version in that order, and the only key appearing beyond those three anywhere in the repository is requires:, on cartography and living-docs, which skill-version.sh validates and which is why those two carried the notice at 10-15 rather than 9-14. The diff confirms it independently: 0 lines added across the 42 files, and 0 version: lines on either side of the diff.
- [x] `AC-H2` *(human)* 42 skills go up exactly one patch level in a single publish run
  - observed `2026-08-31` bump-gate.sh resolve --base origin/main, with the PR title in --title-file and a body carrying no Bump: trailer at all, run in the same container on the same clone: exit 0, and a table of exactly 42 rows, every one of them 'patch' with source 'title', and 0 rows at major, minor or new. That is the mechanism the ticket names, observed in full before the merge. Stated plainly: the publish run itself writes the numbers on main after the merge and cannot be observed from the branch, so what is evidenced here is the resolution that drives it, not the write. A negative control was run alongside it - the same command with a title carrying no conventional type was refused with exit 1, so the resolution is being read rather than assumed.
- [x] `AC-H3` *(human)* no SKILL.md in the repository contains the notice
  - observed `2026-08-31` grep -l 'This copy is read-only' claude/skills/*/SKILL.md returns empty across all 43 skills, against 42 on origin/main. Asserted in the container, and the assertion was proved capable of failing first: reinserting the opener into claude/skills/dba/SKILL.md made the same grep report 1, and restoring it left git status clean, so the zero is a measurement rather than a grep that never matches. The diff backs it: 42 files changed, 294 deletions, 0 insertions, and every deleted non-blank line matches one of the six notice lines with none left over. skill-version.sh verify --structure --base origin/main is green: '43 skills, 0 new, no version: or registry.json in the diff'. The six suites the gate matrix will run were all run - cartography 85 checks, context-compaction 41, living-docs 39, project-scaffold both images, skill-versioning 148, work-order 299 - all green, and bump-gate.sh detect reports tools=false gate=false.

## Test plan

```sh
the title is the mechanism: the publisher fallback gives every changed-but-unlisted skill the title's conventional level, so one fix title produces 42 patch bumps
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-31` How the edit was made, which was the one open judgement call on this ticket. A single one-shot bash script, written to the session scratchpad, run twice, and deliberately not committed. The three candidates were a hand-run sed per file, a script committed to the repository, and a script run once and discarded. The discarded script wins on root CLAUDE.md Rule 2 and on the documentation-lifetime rule: this deletion happens exactly once in the repository's history, so a committed script would be dead code the repository maintains forever for a job that can never recur, and 42 hand-run seds would be 42 chances to get an offset wrong with no validation between them. The durable artefact that stops the notice coming back is not a script at all, it is the inverted assertion in WO-20260824-79b6 - Invert the notice assertion: verify --structure now fails on a notice that is present, which is why that ticket exists and why this one does not need to leave anything behind. The script's full text is reproduced in the pull request body so the edit is reproducible from the record without the repository carrying it. What made it safe was that it validates before it writes and refuses rather than guesses: for each skill it builds that skill's own expected six lines with its own name substituted into the upstream URL, requires an exact match, requires a blank line on both sides, and reports REFUSED by name for anything else. A --check mode does the validation and writes nothing, and it was run first, in the container, against a clone: 42 matched, 1 skipped, 0 refused. Only then was it applied. The ticket's Scope says lines 9 to 14, and the correction the hydration entry carried is confirmed and now has a cause. 38 skills carry the block at 9-14, cartography and living-docs at 10-15, eso-secret-workflow at 13-18, dba at 15-20, and the offset is entirely the length of the frontmatter above it. The baseline frontmatter is 5 lines; cartography and living-docs have a sixth, requires:, and eso-secret-workflow and dba have folded multi-line descriptions running to 9 and 11 lines. So the offsets are not four arbitrary exceptions to be listed, they are one rule, and any future edit keyed on line numbers is wrong for the same reason on whatever the frontmatter looks like that day. The removal is seven lines, not six. The block sits between two blank lines - heading, blank, notice, blank, body - so deleting the six notice lines alone would leave a double blank. Deleting the six plus the trailing blank collapses it to heading, blank, body, which is byte-for-byte the shape claude/skills/hydration-prompt/SKILL.md already had as the one skill done in WO-20260824-f1a5. 42 files, 294 deletions, 0 insertions. One expectation in the hydration entry is wrong and is worth correcting for whoever takes 79b6. It says the gate's matrix will run 42 suites and to budget for the run time. It runs 6. bump-gate.sh detect emits only changed skills that ship testing/run-tests.sh, and of the 42 only cartography, context-compaction, living-docs, project-scaffold, skill-versioning and work-order do. All six were run locally and are green - 85, 41, 39, both images, 148 and 299 checks respectively - and detect also reports tools=false and gate=false, so nothing under claude/tools/ or .github/ is pulled in. The whole matrix is minutes, not a budget item. One thing 79b6 needs and should not have to rediscover. The inline notice that was just removed named skill-update.sh, and the rendered replacement in claude/tools/partials/read-only-notice.md.tmpl names skill-sync.sh. That difference is deliberate and the partial's own header comment says so. An assertion written against the removed text will therefore not match the text that gets installed, and the only string common to both is the opener, > **This copy is read-only.**, which is what grep -l should key on. My first frontmatter assertion failed, and it was the assertion that was wrong rather than the tree. It demanded the key list be exactly name, description, version and cartography and living-docs have requires: as a fourth. AC-H1 asks for those three in that order, not for nothing after them, and skill-version.sh validates requires: explicitly. Corrected to assert the leading three and to report every key seen beyond them repo-wide, which returns requires: and nothing else. The AC-H3 grep was given a negative control before it was believed: reinserting the opener into dba made it report 1, and restoring left git status clean. A grep asserting a zero is worth nothing until it has been made to return non-zero once.
- `2026-08-24` Poker 2026-08-24: 5 points. The five is verification, not editing. Removing six lines from 42 files is a one-liner; proving frontmatter is byte-identical afterwards and that exactly 42 bumps landed is the work.

## Outcome

_Written by `work-order close`. Empty until then._
