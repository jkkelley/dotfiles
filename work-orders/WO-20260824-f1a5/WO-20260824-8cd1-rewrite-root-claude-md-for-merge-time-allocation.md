---
{
  "id": "WO-20260824-8cd1",
  "slug": "rewrite-root-claude-md-for-merge-time-allocation",
  "title": "Rewrite root CLAUDE.md for merge-time allocation and the named main exception",
  "type": "chore",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-28",
  "created_at": "2026-08-24T13:19:10-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": "feat/rewrite-root-claude-md-for-merge-time-allocation",
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
    "WO-20260824-9712"
  ],
  "blocks": [
    "WO-20260825-dac4"
  ]
}
---

# WO-20260824-8cd1 - Rewrite root CLAUDE.md for merge-time allocation and the named main exception

## Problem

Rule 16 currently instructs every contributor to bump a version and ship a regenerated registry by hand, which after this epic is exactly the thing the PR gate refuses. The never-write-main rule also now has one genuine exception. An agent reading the current file would be told to do the wrong thing with full confidence.

## Scope

**In**

- Rule 16 rewritten: CI allocates at merge, a PR carries intent, verify --structure gates
- the named exception to the never-write-main rule, in the wording the design doc fixes
- the pipeline flow documented here, per decision 17
- skill-update.sh stated as the hand-authored path and nothing else

**Out - non-goals**

- changing any rule other than 16 and the main rule

## Acceptance criteria


- [x] `AC-H1` *(human)* an agent reading only root CLAUDE.md can describe the whole path from a skill edit to a project receiving it
  - observed `2026-08-28` Rung 5, run in a fresh subagent given only a copy of the finished CLAUDE.md at /tmp/.../rung5-CLAUDE.md and told to read nothing else. It reproduced all eight steps of the path unaided - edit under claude/skills/<name>/, skill-version.sh verify --structure, the Bump: trailer in the PR body, skill-pr-gate.yml resolving and printing, squash merge carrying the body as the commit message, skill-publish.yml allocating on main via git interpret-trailers --parse with the Skill-Publish marker, .claude/skills.toml declaring it, and skill-sync.sh --boot installing it at the next SessionStart with a receipt. It also answered correctly that the number is allocated at step 6 and never by hand, that the never-write-main exception is exactly one thing (skill-publish.yml), and what skill-update.sh is for. It found one real defect in the new prose - the intro sentence undercounted the hand-run steps - which was fixed before this evidence was recorded. Two out-of-scope contradictions it raised are surfaced on the PR rather than fixed here, per the non-goal.
- [x] `AC-H2` *(human)* no instruction to hand-edit a version: or registry.json survives anywhere in the file
  - observed `2026-08-28` Rung 1, in a container (bitnami/git pinned by digest, --network=none, repo mounted ro): grep -rniE "skill-version.sh (bump|init)|regenerated registry|hand-edit" CLAUDE.md returns exactly two lines, neither of which instructs anyone to hand-edit anything. Line 229 is the pre-existing HYDRATION.md prohibition "Never hand-edit it", about a different file and untouched by this ticket. Line 235 is "workflow commits the version bump and the regenerated registry after a merge", which describes what the publisher does inside the named exception, in the wording the design doc fixes. Zero occurrences of skill-version.sh bump or skill-version.sh init anywhere in the file. The old Rule 16 instructions to run bump and to ship a regenerated registry.json are gone, confirmed by git diff -U0 showing those exact lines among the deletions.

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Heads-up from WO-20260824-7a63 - Close-out moves onto the branch: done archives, cleanup only deletes branches, which merged before this ticket is started. The named exception to the never-write-main rule got NARROWER and this ticket should not write the version it was scoped against. work-order close used to commit its archive straight to main after every merge; it is now named cleanup, it deletes branches only, and it writes nothing at all. So the only process that writes main is the publish workflow, WO-20260824-360d - Publish workflow: allocate versions on merge to main and regenerate the registry. Word the exception against that one process, not two. Also already done and not left for this ticket: root CLAUDE.md section "Post-merge cleanup" was rewritten into "Close-out and post-merge cleanup" and now points at workflows/close-out-procedure.md. Rule 16 was NOT touched and is still entirely this ticket - it still tells contributors to hand-bump and hand-ship a regenerated registry.
- `2026-08-24` Poker 2026-08-24: 3 points. Prose, but it is the repository's constitution and is easy to get subtly wrong.

## Outcome

_Written by `work-order close`. Empty until then._
