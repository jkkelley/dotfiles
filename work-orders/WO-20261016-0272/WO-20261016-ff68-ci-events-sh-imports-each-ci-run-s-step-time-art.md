---
{
  "id": "WO-20261016-ff68",
  "slug": "ci-events-sh-imports-each-ci-run-s-step-time-art",
  "title": "ci-events.sh imports each CI run's step-time-* artifacts to the bus, once per run",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T07:21:12+00:00",
  "parent": "WO-20261016-0272",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design3 cut for ORD-0715; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-75b7",
    "WO-20261016-e832"
  ],
  "blocks": []
}
---

# WO-20261016-ff68 - ci-events.sh imports each CI run's step-time-* artifacts to the bus, once per run

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

ORD-0715 C1 (brief BR-20261016-infra-design3): "Timed by step-time.sh so SLOW shows up on the bus." Owner, item 37: "every node, seat, job, CI run and merge records its start and end in UTC on the bus by script"; item 28: "Have fallbacks too" (bus down: file queue). WO-20261016-75b7 - claude/workflow CI sharded by suite: diff-selected matrix, full on main and nightly, cached image, timed by step-time.sh writes step-time.sh's would-be bus messages as JSONL lines {subject, payload} into artifact step-time-<shard>, because GitHub runners cannot reach the local NATS. WO-20261016-e832 - CI producer: ci-events.sh publishes GitHub Actions run start and end to the bus builds the local poller of gh run list. This ticket adds to that poller (item 30: add a verb to an existing tool, never a new one): for a completed run, download its step-time-* artifacts and publish every line verbatim, so SLOW from CI lands on the same subjects step-time.sh uses locally.

## Scope

**In**

- touches: claude/workflow/timing/ci-events.sh
- touches: claude/workflow/timing/tests/test_ci_events.sh
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-0272/README.md
- step: ci-events.sh: publisher command from env CI_EVENTS_PUB (default "$HERE/../bin/bus.sh pub", split with read -r -a exactly as bin/step-time.sh splits STEP_TIME_PUB)
- step: ci-events.sh: when a run is seen completed and is not yet in the state file's .imported array: `gh run download <databaseId> -R <repo> -p 'step-time-*' -D <mktemp -d>`, retried 3 times only when the error is not 'no artifact matches'; for every */step-time.jsonl line in file then line order call `"${PUB[@]}" "$(jq -r .subject)" "$(jq -c .payload)"`; a publish failure prints 'ci-events: publish to <subject> failed' on stderr and continues; then append the databaseId to .imported (keep the last 500) and remove the temp dir; 'no artifact matches' marks the run imported with nothing published
- step: tests/test_ci_events.sh: stub gh whose 'run download' copies fixture step-time.jsonl (two lines: line.ci.time.workflow-lint with dur_s 200 budget_s 180, and line.ci.event.step.slow code SLOW) into -D/step-time-lint/, and a run id whose download exits 1 printing 'no artifact matches any of the names or patterns provided'; CI_EVENTS_PUB points at a stub that appends '<subject> <payload>' to a file; assert TP-1, TP-2, TP-3
- step: run `make -C claude/workflow timing-test CASE=ci-events` and `make -C claude/workflow lint` (only these; CI runs the rest)
- tool: path:claude/workflow/timing/ci-events.sh - created by WO-20261016-e832 (dependency); fallback: absent on main at start: stop with DESIGN-GAP naming it
- tool: make:claude/workflow/timing/timing.mk:timing-test CASE=ci-events - established by WO-20261016-e832; fallback: CASE=ci-events does not run tests/test_ci_events.sh on main: stop with DESIGN-GAP
- tool: cmd:gh run download - fallback: gh or GitHub down: retry 3 times, leave the run unimported so the next tick retries, exit 0 with the error on stderr
- tool: path:claude/workflow/bin/bus.sh pub - on main; fallback: bus down: the line stays unpublished and the run is still marked imported; the artifact (retention 7 days) is the file-queue record, and ci-events.sh never fails the poll for it
- tool: cmd:jq, cmd:podman - fallback: missing: stop with ENV-MISSING naming it

**Out - non-goals**

- the CI side (workflow-suite.yml, ci-time-pub.sh): WO-20261016-75b7
- judging SLOW again here: step-time.sh already coded it in the payload; this ticket only carries lines verbatim
- work-orders/INDEX.md, the ticket file or the parent README by hand: work-order.sh writes them; their close-out diff is allowed
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow timing-test CASE=ci-events` exits 0 and its output matches /fail=0/ (proof: command, exit code and output pasted by work-order.sh evidence)
- [ ] `AC-H2` *(human)* `make -C claude/workflow lint` exits 0 (proof: command, exit code and output pasted by work-order.sh evidence)
- [ ] `AC-H3` *(human)* `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/|claude/workflow/timing/(ci-events\.sh|tests/test_ci_events\.sh))$'` exits 1 and prints nothing

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/timing/ci-events.sh: import of step-time-* artifacts of a completed run to the bus

**Cases**

- `TP-1`
  - intent: a CI shard over budget must reach the bus as SLOW, or the bottleneck is never filed (item 37)
  - command: `make -C claude/workflow timing-test CASE=ci-events`
  - expected: exit 0; the stub publisher received line.ci.time.workflow-lint and line.ci.event.step.slow with the fixture payloads byte for byte
- `TP-2`
  - intent: a re-run of the poller must not publish a run's timings twice (item 28 idempotency)
  - command: `make -C claude/workflow timing-test CASE=ci-events`
  - expected: exit 0; a second --once over the same completed run publishes nothing more and calls gh run download no more
- `TP-3`
  - intent: a run with no step-time artifact (any workflow but workflow suite) must not fail the poller
  - command: `make -C claude/workflow timing-test CASE=ci-events`
  - expected: exit 0; stub gh run download exits 1 with 'no artifact matches'; ci-events.sh exits 0 and the run is marked imported

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
