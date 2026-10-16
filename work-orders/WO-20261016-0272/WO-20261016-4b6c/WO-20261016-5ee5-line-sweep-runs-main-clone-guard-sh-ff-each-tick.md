---
{
  "id": "WO-20261016-5ee5",
  "slug": "line-sweep-runs-main-clone-guard-sh-ff-each-tick",
  "title": "line sweep runs main-clone-guard.sh ff each tick and emits LW-MAIN-DRIFT once per new drift line to the orchestrator",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:07:26+00:00",
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
    "WO-20261016-2092",
    "WO-20261016-ad18"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow line-watch-test",
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
      "command": "jq -e '.consumers.orchestrator.codes | index(\"LW-MAIN-DRIFT\")' claude/workflow/config/line-watch.json",
      "exit": 0,
      "expect": null
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/line-watch\\.sh|config/line-watch\\.json|tests/unit/test_line_watch\\.sh))$'",
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

# WO-20261016-5ee5 - line sweep runs main-clone-guard.sh ff each tick and emits LW-MAIN-DRIFT once per new drift line to the orchestrator

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

The line sweep checks seats every minute but never the ~/dotfiles primary clone they all run tools from, so 40+ minutes on feat/dag-state-t6 passed with no event on the bus.

## Owner words

> seat dag-t6b ran work-order.sh start inside the ~/dotfiles main clone ... every seat calling ~/dotfiles tools ran stale code (brief BR-20261016-infra-design13, ORD-0830 RR-orch-14)

> we need a scripted way to monitor (Design principles 101 item 27: one pattern for everything that watches)

## Context

Order ORD-0830 RR-orch-14, brief BR-20261016-infra-design13 item DESIGN-GAP main clone drift. Evidence: ~/.local/state/zenith/breakglass/2026/10/20261016-095436-main-clone-efb2-start-stamp.patch and seats/wr2-feed.result.json (ENV-MISSING on claude/tools/shot while ~/dotfiles sat on feat/dag-state-t6 at c7bd763 for 40+ min). Depends on the guard tool ticket WO-20261016-3327 and, for file order on claude/workflow/config/line-watch.json, on WO-20261016-2092 (in review).

Behaviour, fixed. New function main_clone_tick in claude/workflow/bin/line-watch.sh, called in sweep_once right after adopt_named; reap_watchers. It runs bash "$HERE/main-clone-guard.sh" ff "${MAIN_CLONE:-$HOME/dotfiles}" (a clean, behind clone is fast-forwarded by it). Exit 3: if the stdout line differs from the content of "$STATE/main-clone.last", emit LW-MAIN-DRIFT main-clone - "LINE" "LINE" "" (emit's existing signature) and write the line there; same line: no event. Exit 0: write the ok line there, no event. Other exit: stderr warn, no event, sweep continues. claude/workflow/config/line-watch.json: add LW-MAIN-DRIFT to the orchestrator consumer's codes array, nothing else. Breadcrumb at the function names this ticket.

Test cases added to claude/workflow/tests/unit/test_line_watch.sh with its stub herdr and nats and a fixture clone: (a) clone on branch feat, two sweeps: exactly one LW-MAIN-DRIFT event published, to orchestrator; (b) clone behind by 1: after one sweep it is fast-forwarded and no LW-MAIN-DRIFT event; (c) MAIN_CLONE a non-git dir: no event. Existing cases keep passing (MAIN_CLONE set to a non-git dir in setup).

## Scope

**In**

- touches: claude/workflow/bin/line-watch.sh (main_clone_tick and its call in sweep_once only)
- touches: claude/workflow/config/line-watch.json (LW-MAIN-DRIFT in the orchestrator codes array only)
- touches: claude/workflow/tests/unit/test_line_watch.sh (cases a, b, c and MAIN_CLONE in setup)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree after WO-20261016-3327 and WO-20261016-2092 merged; make exactly the three edits in Context
- step: run `make -C claude/workflow line-watch-test` and `make rolodex-check BASE=origin/main` and the AC checks only
- step: commit 'feat(workflow): line sweep reports main clone drift' with the ticket id; no Bump trailer
- tool: make:claude/workflow/mk/line-watch.mk:line-watch-test - on main; fallback: missing: stop with DESIGN-GAP naming it; image build fails: stop with ENV-MISSING podman
- tool: script:claude/workflow/bin/main-clone-guard.sh - from WO-20261016-3327 on main; fallback: absent on main: stop with DESIGN-GAP naming WO-20261016-3327; bus down at runtime: emit's existing file-queue fallback
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any other change to the sweep, check_seat or the consumers
- a new monitor entry: the guard rides the existing sweep
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the line-watch suite passes with the drift cases
  - check: `make -C claude/workflow line-watch-test` exit 0
- [ ] `AC-H2` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H3` *(human)* LW-MAIN-DRIFT routes to the orchestrator
  - check: `jq -e '.consumers.orchestrator.codes | index("LW-MAIN-DRIFT")' claude/workflow/config/line-watch.json` exit 0
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/line-watch\.sh|config/line-watch\.json|tests/unit/test_line_watch\.sh))$'` exit 1

## Test plan

```sh
{"scope":"the line sweep fast-forwards or reports the primary clone each tick","cases":[{"id":"TP-1","intent":"40+ min of drift produced no bus event; the sweep must emit one LW-MAIN-DRIFT per new drift line and stay quiet otherwise","command":"make -C claude/workflow line-watch-test","expected":"exit 0; cases a, b, c print ok and existing cases still pass"},{"id":"TP-2","intent":"rolodex header kept","command":"make rolodex-check BASE=origin/main","expected":"exit 0"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["the full workflow suite: CI runs it"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
