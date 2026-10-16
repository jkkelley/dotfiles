---
{
  "id": "WO-20261016-e8f2",
  "slug": "stuck-watch-deadman-probes-each-live-line-s-bear",
  "title": "stuck-watch deadman probes each live line's Bearings server and pages STK-092 when the probe returns 000 (ORD-0832 B1)",
  "type": "feature",
  "status": "in-review",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:50:21+00:00",
  "parent": "WO-20261016-af17",
  "branch": "feat/e8f2-stuck-watch-deadman-probes-each-live-line-s-bear",
  "pr": 376,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design7 cut for ORD-0830 RR-orch-15 and ORD-0832 B1; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-cc95"
  ],
  "blocks": [
    "WO-20261016-193d"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow stuck-watch-test",
      "exit": 0,
      "expect": null
    },
    {
      "index": 2,
      "command": "jq -r '.codes[\"STK-092\"].acts' claude/workflow/stuck-watch/config.json",
      "exit": 0,
      "expect": "bearings-up LINE="
    },
    {
      "index": 3,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 4,
      "command": "bash -c \\!\\ git\\ diff\\ --name-only\\ origin/main...HEAD\\ \\|\\ grep\\ -vE\\ \\'\\^\\(work-orders/\\|claude/workflow/stuck-watch/\\(deadman\\\\.sh\\|config\\\\.json\\|README\\\\.md\\|tests/test_stuck_watch\\\\.sh\\)\\)\\$\\'",
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

# WO-20261016-e8f2 - stuck-watch deadman probes each live line's Bearings server and pages STK-092 when the probe returns 000 (ORD-0832 B1)

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

Nothing watches the Bearings page server; when it dies the owner's only decision surface is gone and nobody is paged.

## Owner words

> ORD-0832 B1: the Bearings server for a live line runs as a local systemd user unit (Restart=always, idle stop off), brought up by the line-up Make target with the line; its deadman is the stuck-watch monitor, which pages on page 000. The 240-minute idle default stays for ad hoc sessions only.

## Context

Inventory: stuck-watch/deadman.sh runs once a minute from the systemd user timer stuck-deadman.timer, loops the configured lines, pages through page() (sw_ntfy, deduped per line+code per dedupe_minutes) and logs to deadman.log; its bus check exits 1 on a bus outage, so the probe runs before the bus loop. Its curl is SW_CURL_BIN, stubbed in tests/test_stuck_watch.sh (curl.log).

Page 000 is curl's http_code when nothing answers. The Bearings server keeps its port in ~/.bearings/<line>/server.json .port and answers a keyless GET /state with 403 (the key check in server.mjs), so any code but 000 is alive and the probe never needs the key and never counts as page activity.

config.json additions, exactly: "bearings": {"dir": "~/.bearings", "probe_path": "/state", "timeout_s": 5} and in codes: "STK-092": {"means": "Bearings server of a live line down: probe of 127.0.0.1:<port>/state returned 000, or no server.json", "acts": "architect break glass: make -C claude/workflow bearings-up LINE=<line>"}

## Scope

**In**

- touches: claude/workflow/stuck-watch/deadman.sh
- touches: claude/workflow/stuck-watch/config.json
- touches: claude/workflow/stuck-watch/README.md
- touches: claude/workflow/stuck-watch/tests/test_stuck_watch.sh
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, the parent epic README.md
- step: start only after WO-20261016-cc95 is done and merged (it touches config.json); branch from origin/main
- step: config.json: add the bearings key and the STK-092 code exactly as in Context
- step: deadman.sh: header usage gains one line for STK-092 and env SW_BEARINGS_DIR; before the bus loop, for each line in LINES: f=<bearings dir expanded>/<line>/server.json; port=$(jq -r '.port // empty' f) when f exists; http=000 when port is empty, else http=$("${SW_CURL_BIN:-curl}" -s -o /dev/null -m <timeout_s> -w '%{http_code}' http://127.0.0.1:<port><probe_path>) with 000 on a failed call; http 000: page "$line" STK-092 "bearings down" "line $line: Bearings server probe returned 000 (port ${port:-none}). Break glass: make -C claude/workflow bearings-up LINE=$line"; else log "OK line=$line bearings_http=$http"
- step: README.md: STK-092 row in the codes table after STK-091, exactly: | STK-092 | Bearings server of a live line down (probe 000 or no server.json) | architect break glass: make bearings-up LINE= |
- step: tests/test_stuck_watch.sh: the curl stub answers a /state probe with the content of C/probe.code (default 403) and exit 0, or prints 000 and exits 7 when probe.code is 000; new cases bearings_down and bearings_up added to the case dispatch, exactly TP-1 to TP-3 of the test plan, with SW_BEARINGS_DIR in the temp dir; existing cases get a server.json with port 1 and probe 403 so they still pass
- step: run TP-1 to TP-4 and the AC checks only; CI runs the rest
- tool: make:claude/workflow/Makefile:stuck-watch-test - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:curl on the host - fallback: missing: every probe reads 000 and pages STK-092, loud, never silent
- tool: ntfy through sw_ntfy - fallback: ntfy down: the page is logged with its http code in deadman.log; tests post only to YPC_NTFY_TEST_TOPIC through the stub (item 35)

**Out - non-goals**

- the systemd unit and the Make targets: the Bearings unit ticket cut beside this one
- stuck-watch.sh, pane-look.sh, stuck-watch.mk: unchanged
- restarting the server from the deadman: it pages; the unit's Restart=always restarts
- work-orders/INDEX.md and epic READMEs by hand or by git add: they are ignored generated views
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the probe cases and every stuck-watch case pass
  - observed `2026-10-16` make -C claude/workflow stuck-watch-test exit 0, pass=36 fail=0 incl. bearings_down, bearings_up
  - check: `make -C claude/workflow stuck-watch-test` exit 0
- [x] `AC-H2` *(human)* STK-092 is in the status code map
  - observed `2026-10-16` jq exit 0: architect break glass: make -C claude/workflow bearings-up LINE=<line>
  - check: `jq -r '.codes["STK-092"].acts' claude/workflow/stuck-watch/config.json` exit 0 expect /bearings-up LINE=/
- [x] `AC-H3` *(human)* every script has a rolodex header
  - observed `2026-10-16` make rolodex-check BASE=origin/main exit 0, all have headers
  - check: `make rolodex-check BASE=origin/main` exit 0
- [x] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - observed `2026-10-16` diff name-only filtered by the allowed pattern is empty, exit 0 (grep -v rc 1)
  - check: `bash -c \!\ git\ diff\ --name-only\ origin/main...HEAD\ \|\ grep\ -vE\ \'\^\(work-orders/\|claude/workflow/stuck-watch/\(deadman\\.sh\|config\\.json\|README\\.md\|tests/test_stuck_watch\\.sh\)\)\$\'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

stuck-watch deadman.sh Bearings probe: http_code 000 from a live line's Bearings server pages STK-092

**Cases**

- `TP-1`
  - intent: the owner's only surface is Bearings; a dead page server must reach the owner's phone within a minute (ORD-0832 B1: "its deadman is the stuck-watch monitor, which pages on page 000")
  - command: `make -C claude/workflow stuck-watch-test CASE=bearings_down`
  - expected: exit 0; with the stub curl answering 000 for the /state probe, curl.log holds one ntfy post with `Title: bearings down` and `Priority: high`, and deadman.log holds `STK-092 line=t ntfy=200`; a second pass inside dedupe_minutes posts nothing
- `TP-2`
  - intent: a live server answers 403 to a keyless probe, which is alive, never a page
  - command: `make -C claude/workflow stuck-watch-test CASE=bearings_up`
  - expected: exit 0; deadman.log holds `OK line=t bearings_http=403` and curl.log holds no ntfy post
- `TP-3`
  - intent: a line with no server.json (never started) pages too, and a bus outage does not mask the probe
  - command: `make -C claude/workflow stuck-watch-test CASE=bearings_down`
  - expected: exit 0; no ~/.bearings/t/server.json pages STK-092; with the bus stub down, STK-092 is logged before STK-091
- `TP-4`
  - intent: the existing deadman, watcher and audit cases still hold
  - command: `make -C claude/workflow stuck-watch-test`
  - expected: exit 0

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the real ntfy topic: tests post only to YPC_NTFY_TEST_TOPIC through the stub (item 35)
- the full claude/workflow suite: CI runs it

## Assumptions

1. rollback: revert the commit; the deadman returns to heartbeat and bus checks only

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
