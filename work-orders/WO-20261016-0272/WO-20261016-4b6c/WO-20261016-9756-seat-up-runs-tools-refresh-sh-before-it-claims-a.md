---
{
  "id": "WO-20261016-9756",
  "slug": "seat-up-runs-tools-refresh-sh-before-it-claims-a",
  "title": "seat-up runs tools-refresh.sh before it claims a slot and refuses the seat (exit 3, TOOLS-STALE) when the refresh fails, so no seat starts on a stale tool copy",
  "type": "feature",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:11:17+00:00",
  "parent": "WO-20261016-4b6c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design17 cut for ORD-1053 / ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4; Lavish prohibited for Claude seats (global rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-8e05",
    "WO-20261016-c2b3"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow grid",
      "exit": 0,
      "expect": null
    },
    {
      "index": 2,
      "command": "grep -c 'TOOLS_REFRESH_BIN:-' claude/workflow/bin/herdr-grid.sh",
      "exit": 0,
      "expect": "^[1-9]"
    },
    {
      "index": 3,
      "command": "grep -c 'TOOLS-STALE' claude/workflow/bin/herdr-grid.sh",
      "exit": 0,
      "expect": "^[1-9]"
    },
    {
      "index": 4,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 5,
      "command": "bash -c '! git diff --name-only origin/main...HEAD | grep -vE \"^(work-orders/.*|claude/workflow/(bin/herdr-grid[.]sh|tests/unit/test_herdr_grid[.]sh))$\"'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-9756 - seat-up runs tools-refresh.sh before it claims a slot and refuses the seat (exit 3, TOOLS-STALE) when the refresh fails, so no seat starts on a stale tool copy

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

seat-up starts seats whatever state the seat tool copies are in; nothing refreshes zwo and the other architect copies before a seat runs. Evidence: seats/yp-design11.result.json design_gap[1]: zwo (the architect copy at ~/.local/share/zenith-architect/work-order, refreshed only when someone runs ~/.local/bin/zrefresh by hand) listed epics 0d38 1555 4ffa 708e 715b as leaves while dotfiles main next did not (repro: zwo next --project <business> vs bash ~/dotfiles/claude/skills/work-order/scripts/work-order.sh next); seats/yp-design6.result.json and yp-design11 approved business tickets with zwo because its old approve had no tool gate. zrefresh is untracked (~/.local/bin/zrefresh: git -C ~/dotfiles pull --ff-only, then rsync -a --delete of the ~/dotfiles working tree claude/workflow (minus tests), claude/skills/work-order and claude/tools/artifact into ~/.local/share/zenith-architect), so it copies whatever branch the clone sits on.

## Owner words

> ORD-1053 A4: prevention ticket: tool copies for seats come from dotfiles main only; seat-up runs zrefresh (or skill-sync) before a seat starts, so no seat uses a stale copy. (orchestrator brief BR-20261016-infra-design17)

> see a bug, isolate it, and get it fixed as asap (Design principles 101 item 22)

> Have fallbacks too (Design principles 101 item 28)

## Context

Order ORD-1053 A4, brief BR-20261016-infra-design17. Depends on the tool ticket WO-20261016-8e05 (tools-refresh.sh on main) and, for file order on herdr-grid.sh and test_herdr_grid.sh, on WO-20261016-c2b3 (the main-clone guard in cmd_seat_up, last of the grid-fix chain). Behaviour, fixed. In cmd_seat_up of claude/workflow/bin/herdr-grid.sh, after the main-clone guard call that WO-20261016-c2b3 adds and before cmd_claim: run bash "${TOOLS_REFRESH_BIN:-$HERE/tools-refresh.sh}" run and capture stdout and stderr. Exit 0: print its one line on stdout and continue unchanged. Any other exit N, including a missing script: print its output, then 'grid: seat-up refused: tools refresh exit N (TOOLS-STALE)' on stderr and return 3; no slot claimed, no pane opened. TOOLS_REFRESH_BIN is the only new input (env, item 17; tests point it at a stub); make seat-up already passes the environment, and MAIN_CLONE and TOOLS_DIR reach the script the same way. Add TOOLS_REFRESH_BIN to the env line of the header comment. Breadcrumb at the change naming this ticket and the yp-design11 evidence. Fallback: the refresh itself falls back to the last fetched origin/main when GitHub is down (its own ticket), so only a broken clone or script refuses; then the orchestrator gets the refused exit and the architect may break glass (item 33). Rejected: warn and continue on failure, a seat on a stale copy is the defect; rejected: refreshing in seat-down or the sweep, a seat started between sweeps still gets a stale copy. Cost: one fetch per seat-up, timed by TIMED. Test cases added to claude/workflow/tests/unit/test_herdr_grid.sh using its stub herdr: in setup export TOOLS_REFRESH_BIN to a stub script in the fixture dir that prints 'tools-refresh: current fixture' and exits with the code in $T/fx/refresh-rc (default 0), so every existing case keeps passing; (a) refresh-rc 3: seat-up exit 3, stderr has TOOLS-STALE, the stub herdr log has no new split or label; (b) refresh-rc 0: seat-up exit 0, stdout has 'tools-refresh: current fixture', seat labelled; (c) TOOLS_REFRESH_BIN pointing at a missing path: seat-up exit 3 with TOOLS-STALE.

## Scope

**In**

- touches: claude/workflow/bin/herdr-grid.sh (cmd_seat_up only, plus the header env line and its breadcrumb)
- touches: claude/workflow/tests/unit/test_herdr_grid.sh (stub in setup and cases a, b, c in Context)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree after WO-20261016-8e05 and WO-20261016-c2b3 merged, never the ~/dotfiles primary clone; make exactly the two edits in Context
- step: run `make -C claude/workflow grid` and the AC checks only; CI runs the rest
- step: commit 'feat(workflow): seat-up refreshes seat tools from main and refuses a stale copy' with the ticket id; no Bump trailer
- tool: make:claude/workflow/Makefile:grid - on main; fallback: missing: stop with DESIGN-GAP naming it; image build fails: stop with ENV-MISSING podman
- tool: path:claude/workflow/bin/tools-refresh.sh - from WO-20261016-8e05 on main; fallback: absent on main: stop with DESIGN-GAP naming WO-20261016-8e05
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any other change to herdr-grid.sh (seat-down, adopt, claim, the main-clone guard)
- claude/workflow/Makefile and tools-refresh.sh itself: WO-20261016-8e05 owns them
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the grid suite passes with the refresh cases
  - check: `make -C claude/workflow grid` exit 0
- [ ] `AC-H2` *(human)* seat-up calls the refresh
  - check: `grep -c 'TOOLS_REFRESH_BIN:-' claude/workflow/bin/herdr-grid.sh` exit 0 expect /^[1-9]/
- [ ] `AC-H3` *(human)* seat-up refuses by the TOOLS-STALE code
  - check: `grep -c 'TOOLS-STALE' claude/workflow/bin/herdr-grid.sh` exit 0 expect /^[1-9]/
- [ ] `AC-H4` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H5` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c '! git diff --name-only origin/main...HEAD | grep -vE "^(work-orders/.*|claude/workflow/(bin/herdr-grid[.]sh|tests/unit/test_herdr_grid[.]sh))$"'` exit 0

## Test plan

```sh
{"scope":"seat-up refreshes seat tools before claiming a slot and refuses on a failed refresh","cases":[{"id":"TP-1","intent":"seats ran a stale zwo copy (yp-design11); seat-up must refresh first and refuse a seat when the refresh fails, before any slot is claimed","command":"make -C claude/workflow grid","expected":"exit 0; cases a, b, c print ok and the existing cases still pass"},{"id":"TP-2","intent":"rolodex header kept","command":"make rolodex-check BASE=origin/main","expected":"exit 0"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["the full workflow suite: CI runs it"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
