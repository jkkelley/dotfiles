---
{
  "id": "WO-20261016-4575",
  "slug": "close-wo-20261016-75b7-pr-220-merged-with-work-o",
  "title": "Close WO-20261016-75b7 (PR 220 merged) with work-order.sh done --at merge",
  "type": "chore",
  "status": "ready",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:19:52+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design9 cut for ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-4710"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-75b7 --json | jq -r .status",
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
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-4575 - Close WO-20261016-75b7 (PR 220 merged) with work-order.sh done --at merge

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

WO-20261016-75b7 - claude/workflow CI sharded by suite, diff-selected - is in-review though PR 220 merged 2026-10-16T07:33Z. Its checks are point-in-time and its AC-H6 anchors a bare work-orders/, so plain done on a later main cannot pass.

## Owner words

> get this code merged the fuck in, dead code is shit (Design principles 101 item 21)

## Context

Evidence: the corrected scope regex with work-orders/.* over gh pr view 220 --json files prints nothing (rc 1). Tool from WO-20261016-4710 (done --at merge) must be on main first.

## Scope

**In**

- touches: none outside work-orders: the 75b7 ticket file moves to work-orders/archive/2026/ by work-order.sh done only
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree after WO-20261016-4710 merged; run bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-75b7 --at merge
- step: commit 'chore(work-orders): close WO-20261016-75b7 at the PR 220 merge commit' with this ticket id; no Bump trailer
- tool: script:claude/skills/work-order/scripts/work-order.sh done --at merge (WO-20261016-4710) - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:gh, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any edit to WO-20261016-75b7 content or to the files of PR 220
- work-orders/INDEX.md and epic READMEs by hand or by git add
- waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* WO-20261016-75b7 is done and archived
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-75b7 --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H2` *(human)* the diff holds only work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

{"scope":"close-out of WO-20261016-75b7 with done --at merge","cases":[
{"id":"TP-1","intent":"PR 220 merged at 07:33Z but its ticket never closed; its checks are point-in-time and only pass at the merge commit","command":"bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-75b7 --at merge","expected":"exit 0; prints WO-20261016-75b7 -> done"},
{"id":"TP-2","intent":"the ticket is archived as done","command":"bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-75b7 --json","expected":"exit 0; .status is done"}],
"isolation":{"runtime":"podman","image":"docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd"},
"out_of_scope":["the checks of WO-20261016-75b7 themselves: done --at merge runs them"]}

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
