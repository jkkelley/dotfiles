---
{
  "id": "WO-20260824-6a33",
  "slug": "checklist-for-the-four-repositories-carrying-the",
  "title": "Checklist for the four repositories carrying the stale session-start block",
  "type": "chore",
  "status": "done",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-31",
  "created_at": "2026-08-24T13:19:14-05:00",
  "parent": "WO-20260824-00d5",
  "branch": "feat/checklist-for-the-four-repositories-carrying-the",
  "pr": 88,
  "merge_sha": null,
  "closed": "2026-08-31",
  "approval": {
    "via": "override",
    "reason": "Reviewed and approved on PR #55 on GitHub, which is where the whole cut was read as one diff. Lavish was offered and declined in favour of the PR.",
    "at": "2026-08-24"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-c6b0"
  ],
  "blocks": [
    "WO-20260824-238b"
  ]
}
---

# WO-20260824-6a33 - Checklist for the four repositories carrying the stale session-start block

## Problem

Four repositories carry the identical two-line prose session-start check that this design deletes. They cannot be edited from a dotfiles session - that would be propagating a change outward from here rather than making it deliberately inside each repository. What this repository owes is an accurate checklist naming each one and exactly what to remove.

## Scope

**In**

- one row per repository, with file and line numbers
- skill-onboard.sh named as the tool that performs each run

**Out - non-goals**

- editing any of the four repositories from this session or this repository
- the four runs themselves, which are deliberate acts inside each repository

## Acceptance criteria


- [x] `AC-H1` *(human)* the checklist names all four repositories with file and line numbers that resolve
  - observed `2026-08-31` docs/skills-onboarding-checklist.md names gatehouse-click, aws-lightsail-k8s-router, template-resume-builder and claudes-markdown-12-rules, each with its CLAUDE.md block range and the origin/main SHA those numbers were read at on 2026-08-31. Resolution was verified rather than asserted: for every row, git show <sha>:CLAUDE.md piped to sed -n '<start>p' returned the session-start heading, and sed -n '<end+1>p' returned the next H2. gatehouse-click 315 to 382, ends before '## Starting a session'; aws-lightsail-k8s-router 363 to 430, ends before '## Starting a session'; template-resume-builder 131 to 195, ends before '## Output workspace'; claudes-markdown-12-rules 69 to 136, ends before '## Hard rule: never name a ticket without its title'. Row 2 is pinned to origin/main at 8f672e9689e4 rather than that repository's HEAD, which sits on a feature branch where the same block starts at 370; skill-onboard.sh works from origin/BASE so 363 is the number that resolves for the run and 370 is the one that misleads.
- [x] `AC-H2` *(human)* each row states that it is closed only by that repository's own merged PR
  - observed `2026-08-31` Every one of the four rows states the rule in its own Status cell, verified by grep -c 'closes only on' returning 4: each reads '[ ] open, closes only on <that repository>'s own merged PR', naming the repository rather than referring to a rule elsewhere on the page. The page also opens with a section titled 'This repository cannot tick a single box below', placed above the table so it is read before the checklist is, which states that a row closes only when that repository's own pull request merges, that nothing in dotfiles observes those merges, and that an unticked box therefore means the run has not merged rather than that nobody updated the page. A 'Closing a row' section gives the three steps and notes that four repositories means four separate dotfiles pull requests on four different days, which is named as the cost of having a state column and the reason the page is not generated.

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-31` Retro. The ticket was sized and written as four rows describing one identical edit, and the discovery step falsified that premise before a word of the page was written: two of the four blocks are byte-identical, one differs by a single invisible character, and one has drifted five prose differences and four extra lines. The page is therefore one shared edit plus four genuinely different preconditions, and the shape survived only because the premise was checked rather than trusted. What produced the two skill-onboard.sh defects was not cleverness, it was reading four real files instead of four assumed ones. Both WO-20260824-c6b0 - skill-onboard.sh brings an existing project onto the sync and this ticket name running against a real repository as an explicit non-goal, and that non-goal held: nothing was run anywhere. Reading is not running, and reading was enough to find that LEGACY_HEADING misses an em-dash heading and that a repository with no .claude/skills/ directory dies at exit 3. A tool proved only against a scratch fixture agrees with the fixture; the first four real inputs disagreed with it twice. The one thing that would have gone wrong unnoticed was line numbers taken from a working tree. aws-lightsail-k8s-router sits on a feature branch where the block starts at 370, while skill-onboard.sh works from origin/BASE where it starts at 363. Both numbers are real, only one is useful, and a row carrying 370 would have resolved perfectly for whoever checked it in their editor and misdirected the run. Every row is now pinned to an origin/main SHA and each was verified by git show <sha>:CLAUDE.md at the recorded start and end lines, which is the difference between a checklist that resolves and one that merely looks like it does. A process note worth keeping: the first attempt at the epic note recorded the em dash as prose, and the write emitted a hyphen, so the sentence quoted a hyphen while calling it an em dash - the exact defect it was documenting. It was caught because nothing had been committed and the text was re-read rather than assumed. The fix was to stop writing glyphs and write codepoints, which is strictly better anyway since the two characters are indistinguishable on screen. Finally, the PII question the hydration entry flagged as the one thing to decide with the user rather than alone was correctly escalated and correctly answered: the owner handle is already published in this repository in at least three places, one of which - CLAUDE.md.tmpl:98, carrying a username and a repository name together - is not among the two exceptions the policy documents. That third case is a real gap in a policy this repository enforces on every commit, it was found by asking rather than assuming, and it is on no ticket.
- `2026-08-24` Poker 2026-08-24: 3 points. Sized as the checklist only. The four runs happen inside those repositories and are not tickets here.

## Outcome

_Written by `work-order close`. Empty until then._
