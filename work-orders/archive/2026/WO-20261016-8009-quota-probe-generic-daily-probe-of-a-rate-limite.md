---
{
  "id": "WO-20261016-8009",
  "slug": "quota-probe-generic-daily-probe-of-a-rate-limite",
  "title": "quota-probe: generic daily probe of a rate-limited tool, QUOTA-OK or QUOTA-OUT on the bus, first entry figma (FB-006 resume check)",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:19:35+00:00",
  "parent": "WO-20261016-0272",
  "branch": "feat/quota-probe-generic-daily-probe-of-a-rate-limite",
  "pr": 277,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "tooling ticket cut by design seat yp-design6 per ORD-0910 RR-orch-19 (daily Figma quota check); architect ruling ORD-0550 O4; Lavish prohibited for Claude seats (global rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow/quota-probe test",
      "exit": 0,
      "expect": "pass=8 fail=0"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow/quota-probe lint",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "grep -c figma claude/workflow/quota-probe/quota-probe.sh",
      "exit": 1,
      "expect": "^0$"
    },
    {
      "index": 4,
      "command": "bash claude/workflow/quota-probe/quota-probe.sh --name no-such-probe",
      "exit": 2,
      "expect": "QUOTA-CFG"
    },
    {
      "index": 5,
      "command": "bash -c '! git diff --name-only origin/main...HEAD | grep -vE \"^(work-orders/|claude/workflow/quota-probe/)\"'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [
    "make:test",
    "make:lint",
    "make:probe",
    "make:install",
    "make:stable",
    "path:claude/workflow/quota-probe/quota-probe.sh",
    "path:claude/workflow/quota-probe/tests/test_quota_probe.sh"
  ]
}
---

# WO-20261016-8009 - quota-probe: generic daily probe of a rate-limited tool, QUOTA-OK or QUOTA-OUT on the bus, first entry figma (FB-006 resume check)

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

Four business tickets that draw Figma frames (WO-20261016-3158 - WR2a, WO-20261016-c588 - WR2b, WO-20261016-a7bf - WR2c, WO-20261016-1ef4 - WR2d) are parked with FB-006: every Figma MCP call returns 'You've reached the Figma MCP tool call limit on the Starter plan' (notes on 3158 and c588, 2026-10-16). Their resume condition is the Figma quota coming back, and nothing checks it: no script in dotfiles probes a quota (grep -ril quota claude/workflow on origin/main finds none). This ticket builds the generic, config-driven probe in dotfiles that any rate-limited tool can use; figma is its first config entry. The probe runs once a day from a systemd --user timer (the claude.ai connector login lives on this machine, so it cannot be a cluster CronJob; Design principles 101 item 39 allows a local unit for what must read the local machine), publishes a transition event on the bus, and the orchestrator consumes it and re-seats the parked tickets from ready. No plan upgrade: agents never buy anything.

## Owner words

> Orchestrator order ORD-0910 RR-orch-19, 2026-10-16: park WO-20261016-3158, WO-20261016-c588, WO-20261016-a7bf, WO-20261016-1ef4 with code FB-006 and a resume condition (Figma quota reset, checked by script once a day; cut the daily check as a tooling ticket if none exists). No plan upgrade: agents never buy anything.

> Design principles 101 item 30, 2026-10-16 UTC: "create generic tooling too fucker" and "so its re-usable, add to it, makefiles, dont' be a crackhead and one off shit all the time".

> Item 26: "man drop that shit on a bus we have nats or some open source liteweight tool, come on". Item 28 amendment: "Have fallbacks too".

## Context

Inventory, origin/main 2026-10-16: claude/workflow/bin/bus.sh pub <subject> <json> publishes one event (3 retries, non-zero when the bus is down); claude/workflow/bin/timed-run.sh --node --timeout wraps any step; claude/workflow/stuck-watch/systemd/stuck-deadman.{service,timer} and stuck-watch.mk deadman-install are the systemd --user pattern copied here (sed @DIR@ substitution, enable --now, idempotent uninstall); claude/workflow/config/fallbacks.json FB-006 is 'Figma use_figma -> park with a note'.

claude/workflow/Makefile is touched by four live tickets (5082, b0ed, e4b4, 73f2), so this tool ships its own Makefile in its own directory and is called as make -C claude/workflow/quota-probe; no shared file is edited.

A probe of a quota-limited tool may spend one call of that quota; the timer runs it once a day, so at most one Figma call a day is spent on probing.

## Scope

**In**

- touches: claude/workflow/quota-probe/quota-probe.sh
- touches: claude/workflow/quota-probe/config.json
- touches: claude/workflow/quota-probe/Makefile
- touches: claude/workflow/quota-probe/systemd/quota-probe@.service
- touches: claude/workflow/quota-probe/systemd/quota-probe@.timer
- touches: claude/workflow/quota-probe/tests/test_quota_probe.sh
- touches: claude/workflow/quota-probe/README.md
- config.json, 2-space indent: {"state_dir": "~/.local/state/zenith/quota-probe", "subject_prefix": "line.all.event.quota", "probes": {"figma": {"command": "claude -p --model haiku --max-turns 3 --allowedTools mcp__claude_ai_Figma__whoami 'Call the Figma whoami tool exactly once. Then print exactly one line: FIGMA-OK if it returned a user, FIGMA-LIMIT if its result mentions a tool call limit, FIGMA-ERR otherwise.'", "ok_regex": "FIGMA-OK", "out_regex": "FIGMA-LIMIT|tool call limit", "timeout_s": 120, "resumes": ["business WO-20261016-3158", "business WO-20261016-c588", "business WO-20261016-a7bf", "business WO-20261016-1ef4"]}}}
- quota-probe.sh --name NAME [--config FILE] (default FILE: config.json beside the script; env QP_STATE_DIR overrides state_dir, QP_BUS overrides the publisher command, default 'bash <dir>/../bin/bus.sh pub'): runs probes[NAME].command through bash -c under 'timeout timeout_s', captures stdout+stderr, then code = QUOTA-OK (exit 0) when the command exited 0 and output matches ok_regex; QUOTA-OUT (exit 5) when output matches out_regex; QUOTA-ERR (exit 4) otherwise, including a timeout. Unknown NAME or missing config: QUOTA-CFG, exit 2. Prints one line '<code> <name> <at UTC ISO-8601>'
- state: <state_dir>/<name>.json written atomically (tmp then mv) as {name, code, prev, at}; an event {name, code, prev, at, resumes} is published to <subject_prefix>.<name> only when code differs from the prev stored code (first run counts as a change, prev null), so a daily QUOTA-OUT does not repeat on the bus. Idempotent: a rerun with the same result writes the same state minus at and publishes nothing
- fallback, bus down: when the publisher exits non-zero, the event line is appended to <state_dir>/events.jsonl, stderr gets 'FALLBACK QPROBE-BUS <name>', and the exit code stays the probe code (the bus never decides the probe result)
- systemd/quota-probe@.service: Type=oneshot, ExecStart=/bin/bash @DIR@/quota-probe.sh --name %i; systemd/quota-probe@.timer: OnCalendar=*-*-* 13:00:00 UTC, Persistent=true, AccuracySec=5min (once a day)
- Makefile targets, each '## make TARGET VAR=: what' help-commented, inputs VAR=value: probe NAME= (runs quota-probe.sh); install NAME= (sed @DIR@ into ~/.config/systemd/user/quota-probe@.service, copy the timer, daemon-reload, enable --now quota-probe@NAME.timer); uninstall NAME= (disable --now, remove both unit files only when no other quota-probe@*.timer is enabled, daemon-reload; idempotent); lint (podman run --rm --network=none the workflow test image: shellcheck -x quota-probe.sh tests/test_quota_probe.sh); status (systemctl --user list-timers 'quota-probe@*' and every state file); test (builds the workflow test image with make -C .. image, then podman run --rm --network=none the test script, pattern of claude/workflow Makefile RUN); dev (= test); uat (writes a temp config with jq -n holding selftest-ok command "echo X-OK" and selftest-out command "echo X-LIMIT", runs quota-probe.sh --config <it> for both names against the real bus with QP_STATE_DIR a mktemp dir, prints both codes, removes the temp files); stable (install NAME=figma); rollback (uninstall NAME=figma); clean (rm the state_dir)
- tests/test_quota_probe.sh, pattern of claude/workflow/tests/unit/test_timed_run_fallback.sh (header block name/purpose/inputs/outputs/writes-to/cleanup, ok/FAIL lines, 'pass=N fail=M', exit 1 on any failure, mktemp dir removed on exit): a temp config with probes ok (command 'echo X-OK'), out (command 'echo X-LIMIT; exit 1'), err (command 'exit 3'), slow (command 'sleep 5', timeout_s 1); a stub publisher that appends its args to a file; cases t1 ok -> exit 0 and state code QUOTA-OK, t2 out -> exit 5, t3 err -> exit 4, t4 slow -> exit 4 within 3 s, t5 the same ok probe twice -> exactly one publish, t6 ok after out -> second publish with prev QUOTA-OUT, t7 publisher stub exits 1 -> events.jsonl has one line and stderr has 'FALLBACK QPROBE-BUS ok', t8 unknown name -> exit 2. Exactly 8 cases
- README.md: contents list first (dotfiles hard rule), then what it is, the status codes table (QUOTA-OK 0, QUOTA-OUT 5, QUOTA-ERR 4, QUOTA-CFG 2, QPROBE-BUS fallback), how to add a probe (one config entry), the Make targets, the dev/uat/stable gates, cleanup
- breadcrumb comment at the top of quota-probe.sh: what broke (FB-006 parks with no resume check), why a daily systemd --user timer and not a cluster CronJob (the claude.ai login is local), the rejected alternative (a seat polling Figma, which item 39 forbids), the cost (one Figma call a day)
- step: branch from origin/main in your own worktree; write exactly the seven touches files
- step: run `make -C claude/workflow/quota-probe test` then `make -C claude/workflow/quota-probe lint`; commit 'feat(workflow): quota-probe, a daily probe of a rate-limited tool (ORD-0910 RR-orch-19)'; push, open the PR, leave
- step: after merge the stable gate is the orchestrator's: `make -C claude/workflow/quota-probe stable` installs the figma timer
- tool: cmd:jq, cmd:podman, cmd:timeout, cmd:systemctl - fallback: missing on the host: stop with ENV-MISSING naming it
- tool: path:claude/workflow/bin/bus.sh - on main; fallback: bus down -> events.jsonl file queue, stderr FALLBACK QPROBE-BUS (case t7)
- tool: make -C claude/workflow image - on main; fallback: image build fails -> FB-001 rerun with --pull=never on the cached base digest, switch timed-run.sh --fallback ... --fallback-code FB-001

**Out - non-goals**

- running the figma probe for real or installing the timer inside the build seat (stable gate is the orchestrator's, after merge)
- re-seating or editing the parked business tickets; the bus event is the hand-off
- editing claude/workflow/Makefile, config/fallbacks.json, monitors.json or bin/bus.sh
- buying or upgrading any plan
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the 8 cases pass in podman
  - observed `2026-10-16` pass=8 fail=0
  - check: `make -C claude/workflow/quota-probe test` exit 0 expect /pass=8 fail=0/
- [x] `AC-H2` *(human)* shellcheck clean
  - observed `2026-10-16` shellcheck clean, exit 0
  - check: `make -C claude/workflow/quota-probe lint` exit 0
- [x] `AC-H3` *(human)* figma is a config entry, not code
  - observed `2026-10-16` grep -c figma = 0, exit 1
  - check: `grep -c figma claude/workflow/quota-probe/quota-probe.sh` exit 1 expect /^0$/
- [x] `AC-H4` *(human)* an unknown probe name exits 2
  - observed `2026-10-16` QUOTA-CFG no-such-probe, exit 2
  - check: `bash claude/workflow/quota-probe/quota-probe.sh --name no-such-probe` exit 2 expect /QUOTA-CFG/
- [x] `AC-H5` *(human)* the diff is exactly the touches plus generated work-orders files
  - observed `2026-10-16` diff limited to quota-probe and work-orders, exit 0
  - check: `bash -c '! git diff --name-only origin/main...HEAD | grep -vE "^(work-orders/|claude/workflow/quota-probe/)"'` exit 0

## Test plan

```sh
make -C claude/workflow/quota-probe test && make -C claude/workflow/quota-probe lint
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
