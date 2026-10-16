---
{
  "id": "WO-20261016-cc95",
  "slug": "pane-look-monitor-queued-stale-and-idle-stale-ju",
  "title": "pane-look monitor: QUEUED-STALE and IDLE-STALE judged from the pane spinner, never agent_status",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:04:48+00:00",
  "parent": "WO-20261016-af17",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-cc22",
    "WO-20261016-ca8c"
  ]
}
---

# WO-20261016-cc95 - pane-look monitor: QUEUED-STALE and IDLE-STALE judged from the pane spinner, never agent_status

## Contents

- Problem
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

MSG-20261016-051746-prevent O2 (brief stuck-watch-brief.v3.json): "pane-look monitor (monitors.json entry, every 10 min): snapshot each seat screen to the artifact store; status code QUEUED-STALE when a seat has queued input older than 5 min, IDLE-STALE when idle over 1 min with no result file; replaces the architect scratchpad pane-look.sh". ORD-0550 O3: herdr agent_status reads idle while a seat is mid-turn (wD9:p3 sweep-build idle at 05:26Z with a 29m spinner and 6 subagents); judge working/idle from the pane spinner line and its timer, never agent_status alone. Pane format seen 2026-10-16 on wD9:p3: spinner `✢ Concocting… (50m 47s · ↓ 23.8k tokens)`, queued marker `❯ Press up to edit queued messages`, input box line `❯ <text>` between two rules of `─`.

## Scope

**In**

- touches: claude/workflow/stuck-watch/pane-look.sh
- touches: claude/workflow/stuck-watch/tests/test_pane_look.sh
- touches: claude/workflow/stuck-watch/tests/fixtures/pane-working.txt
- touches: claude/workflow/stuck-watch/tests/fixtures/pane-idle.txt
- touches: claude/workflow/stuck-watch/tests/fixtures/pane-queued.txt
- touches: claude/workflow/stuck-watch/config.json
- touches: claude/workflow/stuck-watch/stuck-watch.mk
- touches: claude/workflow/config/monitors.json
- step: config.json: add `pane_look: {judge_every_s: 60, snapshot_every_s: 600, queued_stale_s: 300, idle_stale_s: 60, spinner_re: "^[^[:alnum:][:space:]] [A-Z][a-z]+… \\(([0-9]+h )?([0-9]+m )?[0-9]+s", queued_re: "^❯ (Press up to edit queued messages|.+)$", artifact_key: "pane-look"}`
- step: pane-look.sh --line L --ws WS [--once]: every judge_every_s, for each named agent pane of WS (`herdr agent list`), read `herdr pane read <pane> --source recent-unwrapped --lines 60`; working = a spinner_re line whose timer text differs from the previous tick (state file $state_dir/pane-look/<seat>.json); idle otherwise; agent_status is recorded but never decides
- step: queued = a queued_re line below the last spinner line; QUEUED-STALE when queued text is unchanged for queued_stale_s; IDLE-STALE when idle for idle_stale_s and no `$LW_RESULTS/<seat>-result.json`
- step: each code: `sw_pub line.<line>.stuck.<code> <json {seat,pane,code,since,agent_status,evidence}>` once per seat+code per episode (dedupe in the state file); evidence = the snapshot path
- step: every snapshot_every_s per seat write the 60 lines to the artifact store at `~/.local/state/zenith/pane-look/YYYY/MM/YYYYMMDD-HHMMSS-<seat>.txt` with frontmatter what/by/repo/branch/created (UTC)
- step: stuck-watch.mk: `pane-look-loop LINE= WS=` (foreground loop) and `pane-look-test [CASE=]` (podman, --network=none)
- step: monitors.json: entry `{"name":"pane-look","owner":"stuck-watch","slot":"3.3","interval":0,"command":"make -C ${repo} pane-look-loop LINE=${line} WS=${ws}","publishes":"line.${line}.stuck.QUEUED-STALE, line.${line}.stuck.IDLE-STALE"}`
- step: fixtures copy the three pane shapes above; tests stub herdr and SW_PUB_CMD
- step: run `make -C claude/workflow pane-look-test`
- tool: path:claude/workflow/tests/container/Containerfile - on main; fallback: no fallback permitted (dotfiles Rule 14, never the host): podman or the image missing stops the node with ENV-MISSING podman
- tool: path:claude/workflow/stuck-watch/lib.sh - on main; fallback: bus down: sw_pub returns 1 and the caller warns; the snapshot still lands in the artifact store
- tool: cmd:herdr - on main; fallback: tests use the stub herdr; a real herdr down in UAT stops with A2A-003 and the herdr error
- provides: make:claude/workflow/stuck-watch/stuck-watch.mk:pane-look-test (created by this ticket)

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow pane-look-test` exits 0 and prints `ok working judged from a moving spinner timer while agent_status says idle` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* the same run prints `ok QUEUED-STALE after 300s of unchanged queued input`, `ok IDLE-STALE after 60s idle with no result file` and `ok no IDLE-STALE when the result file exists` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H3` *(human)* `jq -e '.monitors[]|select(.name=="pane-look" and .slot=="3.3")' claude/workflow/config/monitors.json` exits 0 (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H4` *(human)* `grep -c agent_status claude/workflow/stuck-watch/pane-look.sh` lines never feed the working/idle decision (test case `agent_status idle with a moving spinner is working`) (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/stuck-watch/pane-look.sh against fixture panes, stub herdr and stub bus

**Cases**

- `TP-1`
  - intent: agent_status lies mid-turn (05:26Z sweep-build); the spinner timer is the truth (ORD-0550 O3)
  - command: `make -C claude/workflow pane-look-test CASE=working`
  - expected: exit 0; prints `ok  working judged from a moving spinner timer while agent_status says idle`
- `TP-2`
  - intent: queued orders older than 5 min are a stalled line
  - command: `make -C claude/workflow pane-look-test CASE=queued`
  - expected: exit 0; prints `ok  QUEUED-STALE after 300s of unchanged queued input`
- `TP-3`
  - intent: an idle seat with no result is stuck
  - command: `make -C claude/workflow pane-look-test CASE=idle`
  - expected: exit 0; prints `ok  IDLE-STALE after 60s idle with no result file`
- `TP-4`
  - intent: a finished seat is not stuck
  - command: `make -C claude/workflow pane-look-test CASE=done`
  - expected: exit 0; prints `ok  no IDLE-STALE when the result file exists`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- shellcheck and the full stuck-watch suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
