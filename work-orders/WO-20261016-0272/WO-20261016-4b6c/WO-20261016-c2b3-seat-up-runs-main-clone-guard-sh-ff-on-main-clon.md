---
{
  "id": "WO-20261016-c2b3",
  "slug": "seat-up-runs-main-clone-guard-sh-ff-on-main-clon",
  "title": "seat-up runs main-clone-guard.sh ff on MAIN_CLONE (default ~/dotfiles) and refuses with MAIN-DRIFT exit 3 before claiming a slot",
  "type": "feature",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:07:19+00:00",
  "parent": "WO-20261016-4b6c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design13 cut for ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-2ca4",
    "WO-20261016-ad18"
  ],
  "blocks": [
    "WO-20261016-9756"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow grid",
      "exit": 0,
      "expect": null
    },
    {
      "index": 2,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "grep -c 'main-clone-guard.sh\" ff' claude/workflow/bin/herdr-grid.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/herdr-grid\\.sh|tests/unit/test_herdr_grid\\.sh))$'",
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

# WO-20261016-c2b3 - seat-up runs main-clone-guard.sh ff on MAIN_CLONE (default ~/dotfiles) and refuses with MAIN-DRIFT exit 3 before claiming a slot

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

seat-up starts seats against whatever the ~/dotfiles primary clone holds. When it sat on feat/dag-state-t6, every new seat ran stale tools for 40+ minutes and nothing refused.

## Owner words

> seat dag-t6b ran work-order.sh start inside the ~/dotfiles main clone ... every seat calling ~/dotfiles tools ran stale code (brief BR-20261016-infra-design13, ORD-0830 RR-orch-14)

> see a bug, isolate it, and get it fixed as asap (Design principles 101 item 22)

> Have fallbacks too (Design principles 101 item 28)

## Context

Order ORD-0830 RR-orch-14, brief BR-20261016-infra-design13 item DESIGN-GAP main clone drift. Evidence: ~/.local/state/zenith/breakglass/2026/10/20261016-095436-main-clone-efb2-start-stamp.patch and seats/wr2-feed.result.json (ENV-MISSING on claude/tools/shot while ~/dotfiles sat on feat/dag-state-t6 at c7bd763 for 40+ min). Depends on the guard tool ticket WO-20261016-3327 and, for file order on herdr-grid.sh, on WO-20261016-2ca4 (last of the grid-fix chain 5569 -> ec34 -> 2ca4).

Behaviour, fixed. In cmd_seat_up of claude/workflow/bin/herdr-grid.sh, before cmd_claim: run bash "$HERE/main-clone-guard.sh" ff "${MAIN_CLONE:-$HOME/dotfiles}" and capture its stdout. Exit 0: continue unchanged. Exit 3: print the guard line and then 'grid: seat-up refused: main clone drift' on stderr and return 3; no slot claimed, no pane opened. Any other exit (guard missing or broken): stderr 'grid: warn main-clone-guard exit N, seat-up continues' and continue (fallback: a broken guard never stops the line; the sweep still reports). MAIN_CLONE is the only new input (env, item 17); make seat-up already passes the environment. Breadcrumb comment at the change names this ticket and the breakglass patch path.

Test cases added to claude/workflow/tests/unit/test_herdr_grid.sh, using its stub herdr and a fixture bare remote plus clone in mktemp: (a) MAIN_CLONE on branch feat: seat-up exit 3, stderr has MAIN-DRIFT, the stub herdr log has no new split or label; (b) MAIN_CLONE on main behind by 1: seat-up exit 0, clone fast-forwarded, seat labelled; (c) MAIN_CLONE a non-git dir: seat-up exit 0 as before. Existing cases keep passing (set MAIN_CLONE to a non-git dir in the file's setup).

## Scope

**In**

- touches: claude/workflow/bin/herdr-grid.sh (cmd_seat_up only, plus its breadcrumb)
- touches: claude/workflow/tests/unit/test_herdr_grid.sh (cases a, b, c in Context and MAIN_CLONE in setup)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree after WO-20261016-3327 and WO-20261016-2ca4 merged; make exactly the two edits in Context
- step: run `make -C claude/workflow grid` and `make rolodex-check BASE=origin/main` and the AC checks only
- step: commit 'feat(workflow): seat-up refuses on main clone drift' with the ticket id; no Bump trailer
- tool: make:claude/workflow/Makefile:grid - on main; fallback: missing: stop with DESIGN-GAP naming it; image build fails: stop with ENV-MISSING podman
- tool: script:claude/workflow/bin/main-clone-guard.sh - from WO-20261016-3327 on main; fallback: absent on main: stop with DESIGN-GAP naming WO-20261016-3327
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any other change to herdr-grid.sh (seat-down, adopt, claim)
- claude/workflow/Makefile
- fixing the clone: the guard only fast-forwards
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the grid suite passes with the drift cases
  - check: `make -C claude/workflow grid` exit 0
- [ ] `AC-H2` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H3` *(human)* seat-up calls the guard
  - check: `grep -c 'main-clone-guard.sh" ff' claude/workflow/bin/herdr-grid.sh` exit 0 expect /^1$/
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/herdr-grid\.sh|tests/unit/test_herdr_grid\.sh))$'` exit 1

## Test plan

```sh
{"scope":"seat-up refuses on main clone drift and fast-forwards a clean behind clone","cases":[{"id":"TP-1","intent":"a seat started while ~/dotfiles is off main runs stale tools (wr2-feed ENV-MISSING); seat-up must refuse before claiming a slot","command":"make -C claude/workflow grid","expected":"exit 0; cases a, b, c print ok and the existing cases still pass"},{"id":"TP-2","intent":"rolodex header kept","command":"make rolodex-check BASE=origin/main","expected":"exit 0"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["the full workflow suite: CI runs it"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
