---
{
  "id": "WO-20261016-bf62",
  "slug": "review-server-a-systemd-user-unit-restart-always",
  "title": "review-server: a systemd --user unit (Restart=always) serves the review root from config/review.json; make -f review.mk review-server-up, -down, -status replace the architect's background http.server",
  "type": "feature",
  "status": "draft",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:25:51+00:00",
  "parent": "WO-20261016-35de",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-8c45"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow -f review.mk review-test",
      "exit": 0,
      "expect": "ok review-server: 6 cases"
    },
    {
      "index": 2,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "grep -c '^Restart=always$' claude/workflow/systemd/zenith-review.service",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(systemd/zenith-review\\.service|review\\.mk|tests/unit/test_review_server\\.sh))$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "make:review-server-up",
    "make:review-server-status",
    "path:claude/workflow/systemd/zenith-review.service"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-bf62 - review-server: a systemd --user unit (Restart=always) serves the review root from config/review.json; make -f review.mk review-server-up, -down, -status replace the architect's background http.server

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

The review server is python3 -m http.server 45610 started by the architect in a background shell (pid 1987220): it dies with that shell, nobody restarts it, and Rule 18 forbids background processes. It must be a local systemd --user unit like stuck-deadman, brought up and down by Make.

## Owner words

> ORD-1012 W1: the review server becomes a monitors.json entry (local systemd unit, Restart=always) instead of an architect background shell (orchestrator brief BR-20261016-infra-design14)

> Only what must read the local machine (herdr panes, local processes) runs as a local systemd unit (Design principles 101 item 39)

> Have fallbacks too (Design principles 101 item 28)

## Context

Order ORD-1012 W1 via brief BR-20261016-infra-design14, ORD-0830 RR-orch-14; F35. Reuse, not invention (item 4): the unit and its install targets copy claude/workflow/stuck-watch/stuck-watch.mk deadman-install / deadman-uninstall / deadman-status and claude/workflow/stuck-watch/systemd/stuck-deadman.service (sed-rendered @VAR@ template into ~/.config/systemd/user, daemon-reload, enable --now).

Unit template, new file claude/workflow/systemd/zenith-review.service: [Unit] Description=zenith review server: serves the review root on 127.0.0.1 (config/review.json); [Service] Type=simple; ExecStartPre=/bin/mkdir -p @ROOT@; ExecStart=/usr/bin/python3 -m http.server @PORT@ --bind @BIND@ --directory @ROOT@; Restart=always; RestartSec=2; [Install] WantedBy=default.target. A header comment names this ticket and the http.server evidence.

review.mk targets added after RP's: review-server-up renders @ROOT@ @PORT@ @BIND@ from config/review.json (jq, ~ expanded) into ~/.config/systemd/user/zenith-review.service, daemon-reload, enable --now, then polls curl -fsS http://BIND:PORT/ up to 10 times 1s apart and prints 'review server on http://BIND:PORT/ root ROOT' exit 0, else 'REVIEW-DOWN' exit 3; idempotent (re-run rewrites the same file and restarts only when it changed: cmp before copy). review-server-down: disable --now, rm the unit, daemon-reload, 'review server off', exit 0 even when absent. review-server-status: systemctl --user is-active zenith-review.service plus the curl probe, prints 'review server active http://BIND:PORT/' exit 0 or 'REVIEW-DOWN <state>' exit 3. review-server-migrate FROM=DIR: cp -rn DIR/. ROOT/ (no clobber, idempotent), prints 'migrated N entries from DIR'. Fallback, scripted and tested: systemctl --user unavailable (no user bus) -> review-server-up prints 'FALLBACK FB-REVIEW herdr pane' and exits 4, and the caller runs the same ExecStart line in a labelled herdr pane 'review-server' (Rule 18), never a background job.

Monitors entry NOT in this ticket: claude/workflow/config/monitors.json has every 3x3 slot taken (1.1 to 3.3) and pr-flow and pane-look both claim 3.3, so a tenth monitor has no slot; the slot is an orchestrator ruling (result of infra-design14). This ticket ships the unit and review-server-status so the entry is one config line once a slot exists.

Test, new file claude/workflow/tests/unit/test_review_server.sh, run in podman with SYSTEMCTL and CURL pointed at stubs in mktemp (review.mk reads SYSTEMCTL ?= systemctl --user, CURL ?= curl, REVIEW_UNIT_DIR ?= ~/.config/systemd/user): cases 1 up renders the unit with the fixture config's port 45999 and root, calls enable --now, prints 'review server on'; 2 up again with no change does not restart (stub log has no second restart); 3 status with the stub curl failing prints REVIEW-DOWN exit 3; 4 down removes the unit, exit 0, and down again exit 0; 5 migrate copies 2 entries and a second migrate copies 0 and clobbers nothing; 6 SYSTEMCTL stub exiting 1 with 'Failed to connect to bus' -> FALLBACK FB-REVIEW exit 4. Ends with exactly 'ok review-server: 6 cases'.

## Scope

**In**

- touches: claude/workflow/systemd/zenith-review.service (new, as in Context)
- touches: claude/workflow/review.mk (add review-server-up, review-server-down, review-server-status, review-server-migrate and the review-server case to review-test; RP's targets unchanged)
- touches: claude/workflow/tests/unit/test_review_server.sh (new, the 6 cases in Context)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: write the unit, the targets and the test exactly as in Context
- step: run make -C claude/workflow -f review.mk review-test and make rolodex-check BASE=origin/main and the AC checks only
- step: UAT, after the tests pass: make -C claude/workflow -f review.mk review-server-up, review-server-migrate FROM=$HOME/.local/state/zenith/inbox-triage/20261015/review, review-server-status; save the three outputs plus ss -ltnp | grep 45610 to the artifact store (key evidence) and put the path in your result
- step: commit 'feat(workflow): review server as a systemd --user unit' with the ticket id; no Bump trailer
- tool: make:claude/workflow/review.mk:review-test - built by WO-20261016-8c45; tool: image localhost/dotfiles-workflow-test:1 - fallback: missing: make -C claude/workflow image, then retry once; build fails: stop with ENV-MISSING podman
- tool: cmd:systemctl --user - fallback: no user bus: FALLBACK FB-REVIEW, run the ExecStart line in a labelled herdr pane review-server, report the code
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- claude/workflow/config/monitors.json: the slot is an orchestrator ruling, see Context
- killing the architect's running http.server (pid 1987220): the orchestrator does it after UAT, the unit then owns port 45610
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the 8 publish and 6 server cases pass in podman
  - check: `make -C claude/workflow -f review.mk review-test` exit 0 expect /ok review-server: 6 cases/
- [ ] `AC-H2` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H3` *(human)* the unit restarts always
  - check: `grep -c '^Restart=always$' claude/workflow/systemd/zenith-review.service` exit 0 expect /^1$/
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(systemd/zenith-review\.service|review\.mk|tests/unit/test_review_server\.sh))$'` exit 1

## Test plan

```sh
{"scope":"review.mk review-server-up, -down, -status, -migrate against systemctl and curl stubs","cases":[{"id":"TP-1","intent":"a review server that dies with a shell leaves the owner a dead link; the unit must render from config, be idempotent, report REVIEW-DOWN and fall back to a herdr pane when there is no user bus","command":"make -C claude/workflow -f review.mk review-test","expected":"exit 0; last line ok review-server: 6 cases"},{"id":"TP-2","intent":"UAT on the real host: the unit serves port 45610","command":"make -C claude/workflow -f review.mk review-server-status","expected":"exit 0; review server active http://127.0.0.1:45610/"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["the monitors.json slot: orchestrator ruling","the full workflow suite: CI runs it"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
