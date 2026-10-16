---
{
  "id": "WO-20261016-5569",
  "slug": "seat-up-waits-for-the-agent-to-be-idle-or-workin",
  "title": "seat-up waits for the agent to be idle or working, never idle only",
  "type": "bug",
  "status": "in-review",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:04:22+00:00",
  "parent": "WO-20261016-4b6c",
  "branch": "feat/seat-up-waits-for-the-agent-to-be-idle-or-workin",
  "pr": 199,
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
    "WO-20261016-38a6",
    "WO-20261016-ec34"
  ]
}
---

# WO-20261016-5569 - seat-up waits for the agent to be idle or working, never idle only

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

Evidence 2026-10-16T05:42Z: make seat-up exited 1 at claude/workflow/Makefile:63 while seat stuck-watch-2 (wD9:p50) started and ran; no ~/.local/state/zenith/herdr-grid/inbox-triage/stuck-watch-2.agent-seen was written, while infra-design and yp-design (05:43Z) both got theirs. cmd_seat_up in claude/workflow/bin/herdr-grid.sh runs `hj agent wait "$pane" --until idle --timeout $START_TIMEOUT_MS`; a seat whose CMD carries its prompt starts its first turn at once, herdr reports it working, the wait times out after 60 s and seat-up returns 1 before the agent rename and the agent-seen stamp. Owner, ORD-0600-grid O1: seat-up exit 1 fixed.

## Scope

**In**

- touches: claude/workflow/bin/herdr-grid.sh
- touches: claude/workflow/tests/unit/test_herdr_grid.sh
- step: in cmd_seat_up change `--until idle` to `--until idle --until working` (herdr agent wait accepts the flag twice; `herdr agent wait --help`: 'repeat for more than one state')
- step: add a breadcrumb comment above that line: what broke (05:42Z stuck-watch-2, Makefile:63), why (a prompted seat is working at once), why this fix (any detected state proves the agent started; rejected: a longer timeout, which still fails on a long first turn), cost (none)
- step: in test_herdr_grid.sh make the stub's `agent wait` exit 1 when fixture $T/fx/working exists and the args lack `--until working`, and add case `seat-up with a prompted seat that is working exits 0 and writes agent-seen`
- step: run `make -C claude/workflow grid`
- tool: make:claude/workflow/Makefile:grid - on main; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute
- tool: cmd:herdr - on main; fallback: tests use the stub herdr; a real herdr down in UAT stops with A2A-003 and the herdr error

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* `make -C claude/workflow grid` exits 0 and prints `ok seat-up with a prompted seat that is working exits 0 and writes agent-seen` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` make -C claude/workflow grid exit 0; ok seat-up with a prompted seat that is working exits 0 and writes agent-seen
- [x] `AC-H2` *(human)* `git grep -n -- '--until idle --until working' claude/workflow/bin/herdr-grid.sh` prints exactly one line (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` git grep exit 0; claude/workflow/bin/herdr-grid.sh:270: hj agent wait "$pane" --until idle --until working --timeout "$START_TIMEOUT_MS" >/dev/null || { log "seat $seat: agent never reached idle in $pane"; return 1; }
- [x] `AC-H3` *(human)* `git diff --name-only origin/main` lists only the two files under In (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` git diff --name-only origin/main: claude/workflow/bin/herdr-grid.sh claude/workflow/tests/unit/test_herdr_grid.sh work-orders/INDEX.md work-orders/WO-20261016-0272/WO-20261016-4b6c/README.md work-orders/WO-20261016-0272/WO-20261016-4b6c/WO-20261016-5569-seat-up-waits-for-the-agent-to-be-idle-or-workin.md

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/bin/herdr-grid.sh cmd_seat_up against the stub herdr in tests/unit/test_herdr_grid.sh

**Cases**

- `TP-1`
  - intent: a prompted seat is working at once; seat-up must exit 0 or every new seat reads as a failed spawn (05:42Z)
  - command: `make -C claude/workflow grid`
  - expected: exit 0; prints `ok  seat-up with a prompted seat that is working exits 0 and writes agent-seen`
- `TP-2`
  - intent: a seat that never starts must still fail, or a dead spawn reads as a live seat
  - command: `make -C claude/workflow grid`
  - expected: exit 0; the existing case for `agent never reached idle` still prints ok

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- shellcheck of the workflow tree and the full workflow suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
