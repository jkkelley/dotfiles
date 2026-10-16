---
{
  "id": "WO-20261016-a36a",
  "slug": "seat-up-exports-tmpdir-a-per-seat-scratch-dir-it",
  "title": "seat-up exports TMPDIR, a per-seat scratch dir it creates, into every seat it starts; seat-down removes it",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T12:09:00+00:00",
  "parent": "WO-20261016-4b6c",
  "branch": "feat/a36a-seat-up-exports-tmpdir-a-per-seat-scratch-dir-it",
  "pr": 352,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design20 ORD-1150 T1 tooling leaf; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-ec34"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow grid",
      "exit": 0,
      "expect": "seat-up exports TMPDIR and the seat can write it"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow grid",
      "exit": 0,
      "expect": "seat-down removes the seat TMPDIR"
    },
    {
      "index": 3,
      "command": "make -C claude/workflow grid",
      "exit": 0,
      "expect": "ok  herdr-grid"
    },
    {
      "index": 4,
      "command": "jq -r .workflow.herdr.grid.seat_tmp_dir claude/workflow/config/project.json",
      "exit": 0,
      "expect": "^~/.cache/zenith/seat-tmp$"
    },
    {
      "index": 5,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 6,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/herdr-grid\\.sh|config/project\\.json|tests/unit/test_herdr_grid\\.sh))$'",
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

# WO-20261016-a36a - seat-up exports TMPDIR, a per-seat scratch dir it creates, into every seat it starts; seat-down removes it

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

ORD-1150 T1: a seat started by make seat-up inherits whatever TMPDIR the herdr pane had, usually none, so tools that write temp files (mktemp, work-order.sh code_tree, podman builds, pytest) share /tmp across every seat on the line, collide on names, and leave files no seat owns. There is no per-seat scratch dir, so cleanup after a finished seat cannot find what that seat wrote. The fix is generic in claude/workflow/bin/herdr-grid.sh cmd_seat_up, the one path every seat with a CMD starts through (herdr-bus.mk calls it too), never a per-seat fix.

## Owner words

> tooling leaf: seat-up exports TMPDIR (the seat scratch dir, created if missing) into every seat env; test case asserts TMPDIR is set and writable in a fresh seat. Generic in dotfiles seat-up, no per-seat fix. (ORD-1150 T1, orchestrator brief BR-20261016-infra-design20)

> make sure you clean up too (Design principles 101 item 11)

> config and arguments are good ways to pass things, easy in makefiles too (Design principles 101 item 17)

## Context

Edit 1, claude/workflow/bin/herdr-grid.sh, in the config block next to START_TIMEOUT_MS: SEAT_TMP_ROOT="$(wf_expand "${GRID_SEAT_TMP:-$(gcfg seat_tmp_dir)}")"; [ -n "$SEAT_TMP_ROOT" ] || SEAT_TMP_ROOT="$HOME/.cache/zenith/seat-tmp". Below state_file add seat_tmp() { printf '%s/%s/%s' "$SEAT_TMP_ROOT" "$1" "$2"; }. Edit 2, cmd_seat_up: after the line that runs seat_cmd and before cmd_claim, when cmd is non-empty: local tmp; tmp="$(seat_tmp "$line" "$seat")"; mkdir -p "$tmp" || { log "seat $seat: cannot create TMPDIR $tmp"; return 1; }; cmd="export TMPDIR=$(printf %q "$tmp") && $cmd". The prefix goes on after seat_cmd so the bypass-flag sed still sees the original command. Edit 3, cmd_seat_down: next to the rm -f of the state file: rm -rf "$(seat_tmp "$l" "$seat")". Edit 4, breadcrumb comment above seat_tmp: what broke (seats shared /tmp, no owner for temp files, ORD-1150 T1), why seat-up (the single start path; per-seat env files were rejected because a seat started by herdr-bus.mk would miss them), cost (one mkdir per seat start; a Windows claude.exe seat ignores a Linux TMPDIR, which is harmless). Edit 5, claude/workflow/config/project.json .workflow.herdr.grid: add "seat_tmp_dir": "~/.cache/zenith/seat-tmp" after state_dir. Edit 6, claude/workflow/tests/unit/test_herdr_grid.sh, new block before the final summary line, with GRID_SEAT_TMP="$T/seat-tmp" exported for it: mk_tab1 with free slots; seat-up L tq with CMD bash -c 'test -w "$TMPDIR" && echo TMPOK=$TMPDIR' (quoted so the dollars reach the seat); assert the log holds 'export TMPDIR='; take the logged command after 'pane run <pane> ' from $T/log and run it with bash -c; assert its output is TMPOK=$T/seat-tmp/L/tq and that dir exists; then FORCE=1 seat-down tq L and assert the dir is gone. Ok lines: 'seat-up exports TMPDIR and the seat can write it' and 'seat-down removes the seat TMPDIR'. Ordering: WO-20261016-5569 (PR 199) is merged on main; WO-20261016-ec34 now depends on this ticket, so no two runnable tickets touch herdr-grid.sh.

## Scope

**In**

- touches: claude/workflow/bin/herdr-grid.sh (config block, seat_tmp, cmd_seat_up, cmd_seat_down, breadcrumb)
- touches: claude/workflow/config/project.json (.workflow.herdr.grid.seat_tmp_dir)
- touches: claude/workflow/tests/unit/test_herdr_grid.sh (one new block before the summary line)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main (it holds WO-20261016-5569, PR 199) in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone
- step: make exactly Edits 1-6 in Context
- step: run the AC checks only; CI runs lint and the full suite
- step: commit 'feat(workflow): seat-up exports a per-seat TMPDIR, seat-down removes it' with the ticket id; no Bump trailer (no skill under claude/skills changes)
- tool: make:claude/workflow/Makefile:grid - on main; fallback: missing: stop with DESIGN-GAP naming it; its image fails to build: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- workflow-spawn.sh and the claim path: a seat claimed without CMD runs no command, so there is nothing to export into
- a Windows TMPDIR for claude.exe seats
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* a fresh seat gets TMPDIR set to its own scratch dir and can write it
  - observed `2026-10-16` x
  - check: `make -C claude/workflow grid` exit 0 expect /seat-up exports TMPDIR and the seat can write it/
- [x] `AC-H2` *(human)* seat-down removes the seat scratch dir
  - observed `2026-10-16` make -C claude/workflow grid exit 0: ok seat-down removes the seat TMPDIR
  - check: `make -C claude/workflow grid` exit 0 expect /seat-down removes the seat TMPDIR/
- [x] `AC-H3` *(human)* the whole grid suite stays green
  - observed `2026-10-16` make -C claude/workflow grid exit 0: ok herdr-grid
  - check: `make -C claude/workflow grid` exit 0 expect /ok herdr-grid/
- [x] `AC-H4` *(human)* the scratch root comes from config
  - observed `2026-10-16` jq prints ~/.cache/zenith/seat-tmp, exit 0
  - check: `jq -r .workflow.herdr.grid.seat_tmp_dir claude/workflow/config/project.json` exit 0 expect /^~/.cache/zenith/seat-tmp$/
- [x] `AC-H5` *(human)* rolodex pointers hold
  - observed `2026-10-16` make rolodex-check BASE=origin/main exit 0
  - check: `make rolodex-check BASE=origin/main` exit 0
- [x] `AC-H6` *(human)* the diff holds only the In files
  - observed `2026-10-16` grep -vE filter on name-only diff printed nothing, exit 1
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/herdr-grid\.sh|config/project\.json|tests/unit/test_herdr_grid\.sh))$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/bin/herdr-grid.sh seat-up and seat-down, the per-seat TMPDIR

**Cases**

- `TP-1`
  - intent: a seat without its own TMPDIR shares /tmp with every seat on the line, collides on temp names and leaves files nobody cleans up (ORD-1150 T1)
  - command: `make -C claude/workflow grid`
  - expected: exit 0; output holds ok  seat-up exports TMPDIR and the seat can write it, ok  seat-down removes the seat TMPDIR, and the last line ok  herdr-grid

**Isolation**

_A locally built image uses `- image: localhost/<name>:<tag>` plus `- build: <command>` and `- containerfile: <path>` lines, never a localhost digest (RR-orch-18)._

- runtime: podman
- image: `localhost/dotfiles-workflow-test:1`
- build: `make -C claude/workflow image`
- containerfile: claude/workflow/tests/container/Containerfile

**Out of scope - CI covers**

- lint and the full suite: CI runs them (Design principles 101 item 6)

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
