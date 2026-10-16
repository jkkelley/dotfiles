---
{
  "id": "WO-20261016-f4a0",
  "slug": "bearings-server-for-a-live-line-runs-as-systemd-",
  "title": "Bearings server for a live line runs as systemd user unit bearings-line@<line>, Restart=always, idle stop off, brought up by make line-up (ORD-0832 B1)",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:50:09+00:00",
  "parent": "WO-20261016-af17",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design7 cut for ORD-0830 RR-orch-15 and ORD-0832 B1; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-599f",
    "WO-20261016-e271"
  ],
  "blocks": [
    "WO-20261016-193d",
    "WO-20261016-f82b"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow bearings-test",
      "exit": 0,
      "expect": "ok  bearings"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow -n line-up LINE=t",
      "exit": 0,
      "expect": "bearings-up LINE=t"
    },
    {
      "index": 3,
      "command": "make -C claude/workflow bearings-up",
      "exit": 2,
      "expect": "LINE= is required"
    },
    {
      "index": 4,
      "command": "grep -c ^Restart=always claude/workflow/bearings/systemd/bearings-line@.service",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 5,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 6,
      "command": "bash -c \\!\\ git\\ diff\\ --name-only\\ origin/main...HEAD\\ \\|\\ grep\\ -vE\\ \\'\\^\\(work-orders/\\|claude/workflow/\\(Makefile\\|bearings/\\(bearings\\\\.mk\\|systemd/bearings-line@\\\\.service\\|tests/test_bearings_unit\\\\.sh\\)\\)\\)\\$\\'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [
    "make:bearings-test",
    "make:bearings-up",
    "make:bearings-down",
    "make:bearings-status"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-f4a0 - Bearings server for a live line runs as systemd user unit bearings-line@<line>, Restart=always, idle stop off, brought up by make line-up (ORD-0832 B1)

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

The live line's Bearings page server is a background node process that stops itself after 240 idle minutes and dies with the session that started it, so the owner's only decision surface goes dark with no one told.

## Owner words

> ORD-0832 B1: the Bearings server for a live line runs as a local systemd user unit (Restart=always, idle stop off), brought up by the line-up Make target with the line; its deadman is the stuck-watch monitor, which pages on page 000. The 240-minute idle default stays for ad hoc sessions only.

## Context

Inventory: the server is ~/.claude/skills/bearings/scripts/server.mjs <name> [--idle-minutes N] [--session id] [--join], a foreground node process, outside any repository; it refuses --idle-minutes 0 (IDLE_MS must be above 0) and defaults to 240. It keeps port and key across restarts in ~/.bearings/<name>/server.json. So idle stop off is --idle-minutes 525600 (one year) passed by the unit, server.mjs is never edited, and Restart=always covers any stop. The live line page today is ~/.bearings/inbox-triage.

Pattern reused: stuck-watch/stuck-watch.mk deadman-install renders systemd/stuck-deadman.service with sed into ~/.config/systemd/user and runs systemctl --user daemon-reload and enable --now; homelab-gitops line-ops W7 (WO-20261016-f454) puts line loops in systemd user units the same way. claude/workflow/Makefile line-up runs bin/herdr-grid.sh line-up and is where the line comes up.

Unit template, exactly (claude/workflow/bearings/systemd/bearings-line@.service): a comment header naming this ticket and ORD-0832 B1; [Unit] Description=Bearings page server for line %i (live line, idle stop off); [Service] Type=simple, ExecStart=@NODE@ @SKILL@/scripts/server.mjs %i --idle-minutes @IDLE@ --session line-%i --join, Restart=always, RestartSec=5; [Install] WantedBy=default.target.

## Scope

**In**

- touches: claude/workflow/bearings/systemd/bearings-line@.service (new)
- touches: claude/workflow/bearings/bearings.mk (new)
- touches: claude/workflow/bearings/tests/test_bearings_unit.sh (new)
- touches: claude/workflow/Makefile
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, the parent epic README.md
- step: start only after WO-20261016-599f and WO-20261016-e271 are done and merged (both touch claude/workflow/Makefile); branch from origin/main
- step: write the unit template exactly as in Context
- step: bearings.mk (rolodex header; the stuck-watch.mk style): BEARINGS_HOME := its own dir; BEARINGS_UNITS := $(HOME)/.config/systemd/user; BEARINGS_SKILL ?= $(HOME)/.claude/skills/bearings; BEARINGS_IDLE_MIN ?= 525600; BEARINGS_NODE ?= $(shell command -v node); targets with ## help: bearings-up LINE= (need LINE; mkdir -p the units dir; sed @NODE@ @SKILL@ @IDLE@ into $(BEARINGS_UNITS)/bearings-line@.service; systemctl --user daemon-reload; systemctl --user enable --now bearings-line@$(LINE).service; echo 'bearings up: line=$(LINE)'), bearings-down LINE= (need LINE; systemctl --user disable --now bearings-line@$(LINE).service, errors ignored; echo 'bearings down: line=$(LINE)'; the template file stays, other lines may use it), bearings-status LINE= (systemctl --user status bearings-line@$(LINE).service --no-pager, head -5), bearings-test (image; $(RUN) bash -c 'shellcheck bearings/tests/*.sh && bash bearings/tests/test_bearings_unit.sh')
- step: claude/workflow/Makefile: add 'include bearings/bearings.mk' beside 'include stuck-watch/stuck-watch.mk'; add bearings-up to the .PHONY of the grid block; in line-up, after the herdr-grid.sh line, add the recipe line @$(MAKE) --no-print-directory bearings-up LINE=$(LINE)
- step: tests/test_bearings_unit.sh (new; rolodex header; ok/no counters and a last line pass=N fail=M): temp HOME, a stub systemctl first on PATH logging its arguments, BEARINGS_NODE=/usr/bin/true; cases exactly TP-1 to TP-4 of the test plan; prints 'ok bearings' when fail=0
- step: run TP-1 to TP-4 and the AC checks only; CI runs the rest
- tool: path:~/.claude/skills/bearings/scripts/server.mjs - on the host, outside the repo; fallback: missing: the unit fails to start, systemctl shows it, the deadman ticket pages STK-092
- tool: cmd:systemctl --user - fallback: no user manager (WSL without systemd): bearings-up exits non-zero naming systemctl; the line starts the server as today and the deadman still probes it
- tool: make:claude/workflow/Makefile:image and line-up - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it

**Out - non-goals**

- server.mjs or anything under ~/.claude/skills/bearings: the 240-minute idle default stays for ad hoc sessions
- the deadman probe and the STK-092 code: the deadman ticket cut beside this one
- restarting the live inbox-triage page during the build: the stable gate does that through make line-up
- work-orders/INDEX.md and epic READMEs by hand or by git add: they are ignored generated views
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the unit, the targets and the line-up hook pass their suite
  - check: `make -C claude/workflow bearings-test` exit 0 expect /ok bearings/
- [ ] `AC-H2` *(human)* line-up brings the Bearings server up with the line
  - check: `make -C claude/workflow -n line-up LINE=t` exit 0 expect /bearings-up LINE=t/
- [ ] `AC-H3` *(human)* bearings-up refuses without LINE
  - check: `make -C claude/workflow bearings-up` exit 2 expect /LINE= is required/
- [ ] `AC-H4` *(human)* the unit restarts always
  - check: `grep -c ^Restart=always claude/workflow/bearings/systemd/bearings-line@.service` exit 0 expect /^1$/
- [ ] `AC-H5` *(human)* every new script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H6` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c \!\ git\ diff\ --name-only\ origin/main...HEAD\ \|\ grep\ -vE\ \'\^\(work-orders/\|claude/workflow/\(Makefile\|bearings/\(bearings\\.mk\|systemd/bearings-line@\\.service\|tests/test_bearings_unit\\.sh\)\)\)\$\'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/bearings: the systemd user unit template bearings-line@.service, make bearings-up, bearings-down, bearings-status, and line-up bringing the Bearings server up with the line

**Cases**

- `TP-1`
  - intent: the live line's Bearings page must not stop on the 240-minute idle default or die with a seat; the owner decides only on Bearings (item 12, ORD-0832 B1)
  - command: `make -C claude/workflow bearings-test`
  - expected: exit 0; prints `ok  bearings`; with a stub systemctl and HOME in a temp dir, `make bearings-up LINE=t` writes HOME/.config/systemd/user/bearings-line@.service holding `Restart=always` and `--idle-minutes 525600` and no `@` token left, and the stub log holds `--user daemon-reload` then `--user enable --now bearings-line@t.service`
- `TP-2`
  - intent: idempotent (item 28): bearings-up twice leaves one identical unit; bearings-down twice exits 0 and removes nothing it did not write
  - command: `make -C claude/workflow bearings-test`
  - expected: exit 0; second bearings-up rewrites a byte-identical unit; bearings-down runs `--user disable --now bearings-line@t.service` and exits 0 both times
- `TP-3`
  - intent: line-up brings the server up with the line, by Make, never by hand (item 3)
  - command: `make -C claude/workflow -n line-up LINE=t`
  - expected: exit 0; output holds `herdr-grid.sh line-up` and `bearings-up LINE=t`
- `TP-4`
  - intent: every input is an argument (item 17)
  - command: `make -C claude/workflow bearings-up`
  - expected: exit 2; prints `LINE= is required`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- a real systemd user manager and a live node server: the ORD-0832 B1 test ticket's UAT case
- the full claude/workflow suite: CI runs it

## Assumptions

1. rollback: make bearings-down LINE=<line> and revert the commit; the line falls back to the server started by hand as today

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
