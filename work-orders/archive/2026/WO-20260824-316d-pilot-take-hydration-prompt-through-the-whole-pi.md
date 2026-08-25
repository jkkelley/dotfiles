---
{
  "id": "WO-20260824-316d",
  "slug": "pilot-take-hydration-prompt-through-the-whole-pi",
  "title": "Pilot: take hydration-prompt through the whole pipeline end to end",
  "type": "chore",
  "status": "done",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-25",
  "created_at": "2026-08-24T13:19:09-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": "feat/pilot-take-hydration-prompt-through-the-whole-pi",
  "pr": 73,
  "merge_sha": null,
  "closed": "2026-08-25",
  "approval": {
    "via": "override",
    "reason": "Reviewed and approved on PR #55 on GitHub, which is where the whole cut was read as one diff. Lavish was offered and declined in favour of the PR.",
    "at": "2026-08-24"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-2ad1",
    "WO-20260824-360d",
    "WO-20260824-bb0d"
  ],
  "blocks": [
    "WO-20260824-9712",
    "WO-20260824-d058"
  ]
}
---

# WO-20260824-316d - Pilot: take hydration-prompt through the whole pipeline end to end

## Problem

Every piece of the pipeline has been tested on its own. Nothing has yet proved they compose. hydration-prompt is the right pilot because it ships a test suite, so the matrix is genuinely exercised, and because it is used every session, so a break shows up immediately rather than in three weeks.

## Scope

**In**

- removing the notice from hydration-prompt/SKILL.md and only that file
- opening the PR with the Bump: trailer in the description
- confirming the gate prints the resolution table and runs exactly one matrix leg
- confirming the publisher bumps and regenerates on merge

**Out - non-goals**

- any other skill's notice, which is epic 2
- fixing gate or publisher defects here - those are defects against their own tickets, not scope on this one

## Acceptance criteria


- [x] `AC-H1` *(human)* main carries a bumped hydration-prompt version that nobody typed by hand
  - observed `2026-08-25` Observed on the real main, 2026-08-25, after PR #73 squashed as fe62080. The publisher run 32861246926 (skill-publish.yml) succeeded and produced commit 16541f6 'chore(skills): allocate versions on main', authored and committed by github-actions[bot], body '- hydration-prompt -> 2.0.4 (patch, from the trailer)' and 'Allocated by .github/workflows/skill-publish.yml over 75725db..HEAD. skill-version.sh owns both formats; nothing here was written by hand.', carrying Skill-Publish: true so its own push cannot re-trigger allocation. git show origin/main:claude/skills/hydration-prompt/SKILL.md reads version: 2.0.4 and the registry row reads "hydration-prompt": { "version": "2.0.4", ... }, up from 2.0.3. Nobody typed either. The branch touched neither file, which the gate asserted before the merge: skill-version.sh verify --structure --base main returned 'ok - 43 skills versioned, no version: or registry.json in the diff'. The level travelled the intended path end to end - the PR body's last paragraph carried 'Bump: hydration-prompt=patch', the gate resolved 'hydration-prompt 2.0.3 -> 2.0.4 patch trailer' in run 32860649099 and again in 32861130304, and git interpret-trailers --parse on the squash commit fe62080 on main still reads 'Bump: hydration-prompt=patch', proving the trailer survived squash_merge_commit_message=PR_BODY. detect emitted skills=["hydration-prompt"], tools=false, gate=false, so exactly one matrix leg ran, named hydration-prompt, and it passed 47 checks; 'the gate's own suite' and 'claude/tools' were skipped.
- [x] `AC-H2` *(human)* the registry on main matches render_registry immediately after the publish run
  - observed `2026-08-25` Observed on the real main, 2026-08-25, immediately after publisher run 32861246926 and against the fast-forwarded main at 16541f6. skill-version.sh verify returned 'ok - 43 skills versioned, registry in sync', rc=0, in Podman on the digest-pinned bitnami/git base with the repository mounted read-only. That message is the assertion this criterion asks for rather than a proxy for it: verify computes expected=$(render_registry) over the tree and compares it byte-for-byte with the committed registry.json, printing named drift per skill on any mismatch. A byte-identical comparison means the registry the publisher committed is exactly what render_registry produces from the tree it committed alongside - including hydration-prompt's new sha256 ce66fada2bf857b11c917e9f9ea6405847a450039e2577fd9d388e25479cf68b, which moved because the notice came out of SKILL.md, under its newly allocated 2.0.4. The read-only mount also means the check could not have made itself true.
- [x] `AC-H3` *(human)* verify is green on main afterwards
  - observed `2026-08-25` Observed on the real main, 2026-08-25, at 16541f6 with main in sync with origin/main. Rung 6 of the ladder: plain skill-version.sh verify - not --structure - green, 'ok - 43 skills versioned, registry in sync', rc=0, in a container. Rung 7, the suites, all green afterwards and at the counts the hydration entry recorded: claude/tools 251 pass 0 fail, skill-versioning 103 pass 0 fail, work-order 299 checks across 22 case files all passing, the gate's own suite .github/scripts/testing/run-tests.sh 145 passed 0 failed, and hydration-prompt itself 47 passed 0 failed both locally and as the single CI matrix leg. Nothing on main was left red by the allocation, and the skill whose version moved still passes its own suite.

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-25` Close-out is deliberately SPLIT for this ticket, against the standard procedure, and this note is the reason so it is not re-litigated later. The procedure in workflows/close-out-procedure.md runs 'done' on the feature branch inside the ticket's own PR, and writes nothing to main afterwards. That assumes a ticket's acceptance criteria are observable before the merge. All three of this ticket's are not: AC-H1, AC-H2 and AC-H3 are each an observation about what the publisher did to main AFTER the squash landed, and this is the observation ticket whose entire value is making them on the real main rather than on a fixture. The lifecycle offers no post-merge slot to record them - it ends at 'done', and 'cleanup' changes no status - so following the procedure literally would mean archiving the ticket with the pilot's headline evidence marked not-yet-observed, which is the one outcome that destroys what the ticket exists to prove. WO-20260824-360d took that caveated route honestly and correctly, because its ACs were provable on a fixture and its real-main half was genuinely still outstanding; here the real-main half IS the deliverable. So: PR #73 carries the code change and merges first, the publisher's run on main is watched, and evidence plus 'done' ride a second work-orders-only PR that changes no skill and therefore allocates nothing. This is an exception justified by an observation ticket about the merge itself. It is not a precedent for ordinary tickets, whose ACs are observable on the branch and whose close-out stays in one PR.
- `2026-08-24` Poker 2026-08-24: 2 points. Almost no authored work - it is an observation ticket. Deliberately does not absorb gate or publisher rework.

## Outcome

_Written by `work-order close`. Empty until then._
