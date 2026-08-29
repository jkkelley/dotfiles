---
{
  "id": "WO-20260825-dac4",
  "slug": "verify-structure-refuses-a-brand-new-skill-which",
  "title": "verify --structure refuses a brand new skill, whichever way it is written",
  "type": "bug",
  "status": "done",
  "priority": "p1",
  "created": "2026-08-25",
  "updated": "2026-08-28",
  "created_at": "2026-08-25T07:14:14-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": "feat/verify-structure-refuses-a-brand-new-skill-which",
  "pr": 78,
  "closed": "2026-08-28",
  "approval": {
    "via": "override",
    "reason": "Approved in session on 2026-08-25. The ticket was read as a diff on PR #68, which is where its scope, its dependency on WO-20260824-8cd1 and its blocks edge to WO-20260824-238b were all visible as one change. Lavish was not used.",
    "at": "2026-08-25"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-8cd1"
  ],
  "blocks": [
    "WO-20260824-238b"
  ]
}
---

# WO-20260825-dac4 - verify --structure refuses a brand new skill, whichever way it is written

## Problem

Under merge-time allocation a new skill's SKILL.md carries no version: line, because CI stamps it with init at 1.0.0 on main. verify --structure refuses exactly that: cmd_verify walks every skill directory and reports any without a version as unversioned, before diff_check is even reached. Write the line by hand instead and diff_check reports it as a hand-edited version:. Either way the PR gate is red, so adding a skill becomes the one change that cannot be landed through the pipeline the pipeline exists to enforce. A rename is caught by the same edge, because a renamed directory arrives as an added file whose every line - version: included - is a + in the diff. bump-gate.sh resolve already handles the case correctly on its own, reporting an unregistered skill as new at 1.0.0 per E1.8, so the refusal comes out of skill-version.sh rather than out of the gate's own logic.

## Scope

**In**

- verify --structure treats a skill absent from registry.json as new, and does not require a version: line for it
- diff_check still refuses a version: edit on a skill that is already in the registry
- a renamed skill directory reads as new rather than as a hand-edit
- cases in claude/skills/skill-versioning/testing/run-tests.sh covering all three

**Out - non-goals**

- changing plain verify, which runs on main after the publisher and must still require every skill to be versioned
- teaching bump-gate.sh anything - resolve already reports an unregistered skill as new at 1.0.0
- the publisher's init call, which is WO-20260824-360d
- relaxing the refusal for a skill that is already in the registry, which is the check's whole purpose

## Acceptance criteria


- [x] `AC-H1` *(human)* a PR adding a brand new skill directory with no version: line is green on the gate
  - observed `2026-08-28` Observed 2026-08-28 on PR #78, gate run 33203202657, job 'bump intent' 98957966220's predecessor 98957567239, at branch commit 3bcd179. The branch carried claude/skills/zzz-gate-probe/SKILL.md - a real skill directory added on the branch with no version: line, which is the shape the publisher expects. Both halves of the validate job were green. resolve printed the row 'zzz-gate-probe - -> 1.0.0 new absent from the registry' alongside 'container-sandbox 1.3.0 -> 1.4.0 minor trailer' and 'skill-versioning 2.0.0 -> 2.0.1 patch trailer'. verify --structure --base 751a26d printed 'new zzz-gate-probe (absent from the registry, CI stamps it at 1.0.0)' then 'ok - 44 skills, 1 new, no version: or registry.json in the diff', exit 0. The whole run was green: bump intent pass, what has to run pass, skill-versioning suite pass, the other two legs skipped. This is the gate itself and not a local run - the criterion says green on the gate, and the gate only exists on a pull request. The throwaway was deleted later in the same pull request at 539b3f3 and never reached main or the registry. The 2b variant, the same new skill carrying a hand-written version: 1.0.0, was proved green against a clone of the real 43-skill tree in Podman rather than on the gate, because it is the same code path with the same registry lookup and it would have cost a fourth CI round to say so twice.
- [x] `AC-H2` *(human)* a PR that hand-edits the version: of a skill already in the registry is still refused, and the message says which
  - observed `2026-08-28` Observed 2026-08-28 on PR #78, gate run 33203318713, job 'bump intent' 98957966220, at branch commit 7890235. That commit hand-edited version: 2.0.0 to 2.0.1 in claude/skills/skill-versioning/SKILL.md and changed nothing else. The job failed at the step 'no hand-edited version, no hand-edited registry' with exit 1, printing 'version: edited in this diff skill-versioning/SKILL.md' followed by 'CI allocates the version at merge and writes the registry itself. A branch carries the intent, not the number. Revert both and state the bump in the PR.' and the recovery line 'git checkout 751a26d0ecaa754f872daacbde03d5a6fb5e8d96 -- <path>'. The message names the skill, which is the second half of the criterion. skill-versioning was chosen over any other registered skill deliberately: the PR body already carried 'Bump: skill-versioning=patch', so resolve stayed green and the refusal came from verify --structure rather than from the trailer check one step earlier. The tree at that commit also still carried the unregistered zzz-gate-probe, and the refusal said nothing about it - the exemption is per skill, not a switch the branch flips. Reverted at 6708078; the gate was green again on the same tree minus that one line.
- [x] `AC-H3` *(human)* a PR that renames a skill directory is green on the gate
  - observed `2026-08-28` Observed 2026-08-28 on PR #78, gate run 33203392408, job 'bump intent' 98958221775, at branch commit 6708078. That commit ran 'git mv claude/skills/repo-sync claude/skills/repo-sync-renamed' on a skill the registry already carries at a real version, and git recorded it as R100. The whole run was green. resolve dropped repo-sync from its table entirely - skill_exists in bump-lib.sh removes a deleted skill from changed, so no trailer was needed for it - and printed 'repo-sync-renamed - -> 1.0.0 new absent from the registry'. verify --structure printed 'new repo-sync-renamed (absent from the registry, CI stamps it at 1.0.0)' and 'ok - 44 skills, 2 new, no version: or registry.json in the diff', exit 0. A real registered skill was renamed rather than the throwaway, because renaming an already-unregistered directory would have proved nothing: the point is that the old name IS in the registry and the new one is not. The unpairable half was proved separately against a clone of the real tree in Podman - claude/skills/skill-versioning deleted and claude/skills/skill-registry added with nothing in common, where git listed both SKILL.md paths rather than one, and verify --structure was still green because a SKILL.md gone from the tree is exempt as a deletion. That is the shape WO-20260824-238b will actually take. Undone at 539b3f3.

## Test plan

```sh
skill-versioning's own suite for the unit level, then a real PR adding a throwaway skill directory - the gate is the thing under test and it only exists on a pull request
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-28` cmd_verify's stale-entry loop matches every line in registry.json beginning with four spaces and a quote, which includes the tools block, so a failing plain verify now prints 'stale entry skill-sync (no such skill)' and the same for read-only-notice. Cosmetic, only visible in output that has already failed for another reason, predates this branch - it appeared the moment claude/tools/ became non-empty - and it is on no ticket. Left alone here per Rule 3.
- `2026-08-25` The blocks edge to WO-20260824-238b - Rename skill-versioning to skill-registry, the closing commit is the one that matters, and it is why this is p1 rather than a backlog item. A renamed skill directory arrives in the diff as an added file, so every one of its lines is a + - version: included - and diff_check reads that as a hand-edit. The closing commit of epic 2 cannot land until this does.
- `2026-08-25` Found while building WO-20260824-2ad1 - PR gate workflow: validate the bump intent and run the affected suites, and recorded there as a note rather than fixed, because the refusal comes out of skill-version.sh and not out of the gate. The gate calls verify --structure and inherits it, so the symptom will present as 'the gate refuses my new skill' and the cause is two functions away.

## Outcome

_Written by `work-order done`. Empty until then._
