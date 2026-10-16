---
{
  "id": "WO-20261016-3ac1",
  "slug": "close-wo-20261016-3570-stuck-watch-pr-170-merged",
  "title": "Close WO-20261016-3570 (stuck-watch, PR 170 merged): start, submit, evidence from the dev gate, done",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:30:48+00:00",
  "parent": "WO-20261016-0272",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design10 cut for ORD-0830 RR-orch-14 and ORD-0921; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-3570 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 2,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": []
}
---

# WO-20261016-3ac1 - Close WO-20261016-3570 (stuck-watch, PR 170 merged): start, submit, evidence from the dev gate, done

## Contents

- Problem
- Owner words
- Context
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

WO-20261016-3570 - Stuck-watch: no-model stuck detection to the bus and the owners phone, with a deadman - shipped in PR 170 (merged, 857d290) but still reads ready, so work-order.sh next lists merged work. It has no ac_checks, only five human criteria, so plain done (no --at merge) closes it once each criterion is evidenced; evidence needs in-progress or in-review, hence start and submit first.

## Owner words

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

## Context

Order ORD-0830 RR-orch-14 (brief BR-20261016-infra-design10, item STALE-READY); infra-design9 result l0_l1 found it.

Evidence map, fixed: AC-H1 to AC-H4 of 3570 are the cases tagged (AC1) idle STK-001 plus one ntfy POST, (AC2) deadman-stale page, (AC3) done-unmerged STK-005, (AC4) dedupe one notification, in claude/workflow/stuck-watch/tests/test_stuck_watch.sh, run by make -C claude/workflow stuck-watch-test (podman, --network=none, stub ntfy). AC-H5 is gh pr view 170: MERGED, mergedBy app/github-actions (auto-merge, the scripted path).

## Scope

**In**

- touches: none outside work-orders: the 3570 ticket file and its directory work-orders/WO-20261016-3570/ move to work-orders/archive/2026/ by work-order.sh done only
- touches (generated, written only by work-order.sh start/submit/evidence/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree; bash claude/skills/work-order/scripts/work-order.sh start --id WO-20261016-3570; then submit --id WO-20261016-3570 --pr 170
- step: run TP-1 and TP-2; for each 3570 criterion run evidence --id WO-20261016-3570 --index N --observed with the matching ok line (index 1 to 4) or the gh line (index 5), verbatim
- step: bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-3570; commit chore(work-orders): close WO-20261016-3570 at PR 170 with this ticket id; no Bump trailer
- tool: make:claude/workflow/stuck-watch/stuck-watch.mk:stuck-watch-test - on main; fallback: make missing: run its podman line from claude/workflow/Makefile RUN with bash stuck-watch/tests/test_stuck_watch.sh; a red case: stop with DESIGN-GAP and its output, never tick
- tool: cmd:git, cmd:jq, cmd:gh, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any edit to the closed ticket content beyond what work-order.sh start, submit, evidence and done write
- the stuck-watch UAT gate and any edit under claude/workflow/stuck-watch/
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* WO-20261016-3570 is done and archived
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-3570 --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H2` *(human)* the diff holds only work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

{"scope":"close-out of WO-20261016-3570 (PR 170 merged)","cases":[ {"id":"TP-1","intent":"AC1 to AC4 of 3570 are the dev-gate cases of the stuck-watch suite; a stub ntfy, never the owner topic (item 35)","command":"make -C claude/workflow stuck-watch-test","expected":"exit 0; ok lines tagged (AC1), (AC2), (AC3), (AC4)"}, {"id":"TP-2","intent":"AC5: PR 170 merged by the scripted merge path, not by hand","command":"gh pr view 170 --json state,mergedBy -q .state+\" \"+.mergedBy.login","expected":"exit 0; MERGED app/github-actions"}, {"id":"TP-3","intent":"the ticket is archived as done","command":"bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-3570 --json","expected":"exit 0; .status is done"}], "isolation":{"runtime":"podman","image":"docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd"}, "out_of_scope":["the stuck-watch UAT gate (make stuck-watch-uat): it runs a live seat, not part of a close-out"]}

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
