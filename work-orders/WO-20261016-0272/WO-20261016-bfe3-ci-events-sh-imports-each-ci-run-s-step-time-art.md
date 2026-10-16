---
{
  "id": "WO-20261016-bfe3",
  "slug": "ci-events-sh-imports-each-ci-run-s-step-time-art",
  "title": "ci-events.sh imports each CI run's step-time-* artifacts to the bus, once per run (recut of ff68)",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:00:25+00:00",
  "parent": "WO-20261016-0272",
  "branch": "feat/ci-events-sh-imports-each-ci-run-s-step-time-art",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design5 recut for ORD-0548 DESIGN-GAP routing; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-75b7"
  ],
  "blocks": []
}
---

# WO-20261016-bfe3 - ci-events.sh imports each CI run's step-time-* artifacts to the bus, once per run (recut of ff68)

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

ORD-0715 C1 (brief BR-20261016-infra-design3): "Timed by step-time.sh so SLOW shows up on the bus." Owner, item 37: "every node, seat, job, CI run and merge records its start and end in UTC on the bus by script"; item 28: "Have fallbacks too" (bus down: file queue). WO-20261016-75b7 - claude/workflow CI sharded by suite: diff-selected matrix, full on main and nightly, cached image, timed by step-time.sh writes step-time.sh's would-be bus messages as JSONL lines {subject, payload} into artifact step-time-<shard>, because GitHub runners cannot reach the local NATS. WO-20261016-e832 - CI producer: ci-events.sh publishes GitHub Actions run start and end to the bus built the local poller of gh run list (on main). This ticket adds to that poller (item 30: add a verb to an existing tool, never a new one): for a completed run, download its step-time-* artifacts and publish every line verbatim, so SLOW from CI lands on the same subjects step-time.sh uses locally. Recut of WO-20261016-ff68 (DESIGN-GAP from seat ci-time-import, evidence /home/luna/.local/state/zenith/inbox-triage/20261015/ci-time-import-result.json, brief BR-20261016-infra-design5): ff68 named tests/test_ci_events.sh, which does not exist on main and which timing.mk timing-test never runs (it runs only timing/tests/test_timing.sh, CASE selects a case_<name> function there, lines 118-119); ff68 also kept an .imported array that does not fit the state file on main (an object keyed '<repo>#<id>' with values start|end) and a new CI_EVENTS_PUB publisher where timing/lib.sh already sources sw_pub (stub SW_PUB_CMD in tests); and its scope AC lacked .* after work-orders/ (claude/workflow/templates/scope-ac.md). Second recut: WO-20261016-bd0e cited ci-events.sh lines 43 and 51-54 where main has 45 and 53-56.

## Scope

**In**

- touches: claude/workflow/timing/ci-events.sh
- touches: claude/workflow/timing/tests/test_timing.sh
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-0272/README.md
- step: ci-events.sh state values become start -> end -> imported: the line '[ "$seen" = end ] && continue' (line 45) becomes '[ "$seen" = imported ] && continue'; the end block (from 'd="$(jq -r '((.updatedAt' to the jq that sets .[$k]="end", lines 52-56) is published and the state set to end only when $seen is not already end; then import runs
- step: ci-events.sh new function ci_import <repo> <id>: tmp=$(mktemp -d); up to 3 tries of out=$("$GH" run download "$id" -R "$repo" -p 'step-time-*' -D "$tmp" 2>&1), sleeping ${CI_EVENTS_RETRY_SLEEP:-2} between tries; exit 0: for every line of "$tmp"/*/step-time.jsonl in glob then line order, s=$(jq -r .subject) p=$(jq -c .payload) and 'sw_pub "$s" "$p" || echo "ci-events: publish to $s failed" >&2'; then return 0; output matching 'no artifact matches': return 0 with nothing published, no retry; 3 failures: echo "A2A-003 gh run download $id -R $repo failed 3 times: $out" >&2 and return 1; rm -rf "$tmp" on every path
- step: ci-events.sh after the end step: 'if ci_import "$repo" "$id"; then' set .[$k]="imported" in the state file (same jq tmp-and-mv as the one that sets end) and echo "import $node"; else leave it end so the next poll retries; a failed import never changes rc (the poll still exits 0 for it); a bus-down publish still marks the run imported (the artifact, retention 7 days, is the file-queue fallback)
- step: tests/test_timing.sh new function case_ci_import, placed after case_ci_events, and 'ci-import' appended to the default CASES list (line 118: CASES="${CASE:-timeout start-end slow fast report ci-events}"): setup; fixture $C/step-time.jsonl with exactly two lines {"subject":"line.ci.time.workflow-lint","payload":{"node":"workflow-lint","dur_s":200,"budget_s":180}} and {"subject":"line.ci.event.step.slow","payload":{"code":"SLOW","node":"workflow-lint","dur_s":200,"budget_s":180}}; runs.json two completed success runs, databaseId 77 and 78; stub gh: 'run list' cats runs.json; 'run download <id> ... -D <dir>' appends 'download <id>' to $STUB/gh.log, and for 78 prints 'no artifact matches any of the names or patterns provided' to stderr and exits 1, else mkdir -p <dir>/step-time-lint and copies the fixture there; export GH_BIN TM_CI_STATE CI_EVENTS_RETRY_SLEEP=0 as case_ci_events does, unset them at the end
- step: case_ci_import asserts, with ok/no, exactly these names: 'ci-import: run 77 lines published verbatim' (grep -Fxc of each '<subject> <payload>' line in bus.log is 1), 'ci-import: no artifact matches marks run 78 imported, exit 0' (--once rc 0 and jq -r '.["jkkelley/dotfiles#78"]' state is imported), 'ci-import: a second poll publishes nothing and downloads nothing' (second --once: bus.log and gh.log line counts unchanged)
- step: run 'make -C claude/workflow timing-test CASE=ci-import', 'make -C claude/workflow timing-test CASE=ci-events' and 'make -C claude/workflow lint' (only these; CI runs the rest)
- tool: path:claude/workflow/timing/ci-events.sh - on main (WO-20261016-e832, archived); fallback: absent: stop with DESIGN-GAP
- tool: make:claude/workflow/timing/timing.mk:timing-test CASE=<name> - on main, runs case_<name> in timing/tests/test_timing.sh; fallback: CASE=ci-import prints 'FAIL unknown case ci-import' after the build: the case function name or CASES entry is wrong, fix it in test_timing.sh
- tool: fn:sw_pub - on main in claude/workflow/stuck-watch/lib.sh, sourced by timing/lib.sh; tests stub it with SW_PUB_CMD (set by setup()); fallback: bus down: line unpublished, run still imported, artifact is the record
- tool: cmd:gh run download - fallback: gh or GitHub down: 3 tries, run left at end so the next poll retries, error on stderr
- tool: cmd:jq, cmd:podman - fallback: missing: stop with ENV-MISSING naming it

**Out - non-goals**

- the CI side (workflow-suite.yml, ci-time-pub.sh): WO-20261016-75b7
- judging SLOW again here: step-time.sh already coded it in the payload; this ticket only carries lines verbatim
- a new test file such as timing/tests/test_ci_events.sh, or any change to timing.mk: the case lives in test_timing.sh
- work-orders/INDEX.md, the ticket file or the parent README by hand: work-order.sh writes them; their close-out diff is allowed
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* `make -C claude/workflow timing-test CASE=ci-import` exits 0 and its output matches /fail=0/ and has the three ok lines named in the steps (proof: command, exit code and output pasted by work-order.sh evidence)
  - observed `2026-10-16` make -C claude/workflow timing-test CASE=ci-import: exit 0, 3 ok lines, pass=3 fail=0
- [x] `AC-H2` *(human)* `make -C claude/workflow timing-test CASE=ci-events` exits 0 and its output matches /fail=0/ (proof: command, exit code and output pasted by work-order.sh evidence)
  - observed `2026-10-16` make -C claude/workflow timing-test CASE=ci-events: exit 0, pass=4 fail=0
- [x] `AC-H3` *(human)* `make -C claude/workflow lint` exits 0 (proof: command, exit code and output pasted by work-order.sh evidence)
  - observed `2026-10-16` make -C claude/workflow lint: exit 0
- [x] `AC-H4` *(human)* `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/timing/ci-events\.sh|claude/workflow/timing/tests/test_timing\.sh)$'` exits 1 and prints nothing (template: claude/workflow/templates/scope-ac.md)
  - observed `2026-10-16` scope grep exit 1, printed nothing (only In files changed)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/timing/ci-events.sh: import of the step-time-* artifacts of a completed run to the bus, tested by case_ci_import in claude/workflow/timing/tests/test_timing.sh

**Cases**

- `TP-1`
  - intent: a CI shard over budget must reach the bus as SLOW, or the bottleneck is never filed (item 37)
  - command: `make -C claude/workflow timing-test CASE=ci-import`
  - expected: exit 0; output has 'ok   ci-import: run 77 lines published verbatim' and matches /fail=0/; the stub bus.log holds line.ci.time.workflow-lint and line.ci.event.step.slow with the fixture payloads byte for byte, once each
- `TP-2`
  - intent: a re-run of the poller must not publish a run's timings twice (item 28 idempotency)
  - command: `make -C claude/workflow timing-test CASE=ci-import`
  - expected: exit 0; output has 'ok   ci-import: a second poll publishes nothing and downloads nothing'
- `TP-3`
  - intent: a run with no step-time artifact (any workflow but the workflow suite) must not fail the poller
  - command: `make -C claude/workflow timing-test CASE=ci-import`
  - expected: exit 0; output has 'ok   ci-import: no artifact matches marks run 78 imported, exit 0'
- `TP-4`
  - intent: the existing ci start and end events must not regress under the new imported state
  - command: `make -C claude/workflow timing-test CASE=ci-events`
  - expected: exit 0 and output matches /fail=0/

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- UAT: the line's node-timing pane shows a workflow-<shard> timing from a real PR run, proof `bus.sh` read of line.ci.time.> (merge train, not the build seat)

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
