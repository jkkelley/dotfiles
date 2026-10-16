---
{
  "id": "WO-20261016-6edb",
  "slug": "wk5t-test-plan-and-script-for-make-wiki-review",
  "title": "WK5t: test plan and script for make wiki-review",
  "type": "test",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:49:51+00:00",
  "parent": "WO-20261016-35de",
  "branch": "feat/6edb-wk5t-test-plan-and-script-for-make-wiki-review",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design16 recut for ORD-0830 RR-orch-14 F35; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-6584"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_review.py",
      "exit": 0,
      "expect": "^OK"
    },
    {
      "index": 2,
      "command": "env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node wk5-t --fallback \"podman run --rm --pull=never --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_review.py\" --fallback-code FB-001 -- podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_review.py",
      "exit": 0,
      "expect": "FALLBACK FB-001"
    },
    {
      "index": 3,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'",
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

# WO-20261016-6edb - WK5t: test plan and script for make wiki-review

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

Test sibling of WK5. The tester runs exactly this plan from ~/dotfiles on the WK5 branch and nothing else. Orchestrator orders 2026-10-16 (MSG-20261016T061019Z-yp-design): ORD-0552 O2 'write each AC as command + expected exit code + expected output in the ticket text, and carry owner words verbatim and full context in Problem'; ORD-0555 O1 'before a ticket goes ready, list every tool, script, Make target and fixture its steps and AC checks call; any not on main gets a tooling ticket first'; ORD-0556 O1 'every tooling ticket builds a generic, config-driven tool in dotfiles'; ORD-0558 O1 'every design and ready ticket names the fallback for each tool and dependency it uses, the scripted switch with its status code, and a test case for the fallback path'.

## Owner words

> DESIGN-GAP WKt test plan shape: WO-20261016-a4da - WK5t: test plan and script for make wiki-review: start refuses, Test plan is a one-line JSON in a sh fence, not the claude/workflow/templates/test-plan.md shape; ticket is ready so amend refuses. Recut (cancel and re-new with --test-plan-file). (orchestrator brief BR-20261016-infra-design16)

> testing the same way with test plans and scripts, every node has what it fucking needs up front, not later (Design principles 101 item 30)

## Context

Recut of WO-20261016-a4da by design seat infra-design16 (ORD-0830 RR-orch-14, F35). Same scope, steps, tools, fallbacks and checks as WO-20261016-a4da; only the ## Test plan block changed, from a one-line JSON blob in a sh fence to the claude/workflow/templates/test-plan.md shape that wo_require_test_plan parses, so start no longer refuses test_plan_missing. Evidence: /home/luna/.local/state/zenith/inbox-triage/20261015/seats/wk0t.result.json (start output: is a test ticket with no test plan block). WO-20261016-a4da is cancelled superseded by this ticket. The code under test (WO-20261016-6584) is merged and archived done.

## Scope

**In**

- touches: none outside work-orders; this is a --type test run of the merged WO-20261016-6584 code on origin/main
- touches (generated, written only by work-order.sh start/submit/evidence/done, never by hand or git add): this ticket file and its archive path
- step: worktree at origin/main after WO-20261016-6584 merged; run TP-1 and TP-2 exactly, from the worktree root
- step: write every case output to the path printed by `make -s artifact-new KEY=log NAME=wk5-test EXT=log`; evidence each AC with work-order.sh evidence --observed and that path
- step: a red case: work-order.sh note on WO-20261016-6584 with its output and stop with DESIGN-GAP; never edit a file
- tool: cmd:podman with docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 (python:3.12-slim at pin time 2026-10-16) - fallback: registry pull refused: rerun with --pull=never on the locally cached image of the same digest; switch: timed-run.sh --fallback ... --fallback-code FB-001 (WO-20261016-d304); fallback test: the FB-001 AC below
- tool: cmd:git, cmd:gh, cmd:make - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output
- tool: make:Makefile:artifact-new (on main) - fallback: bash claude/tools/artifact/artifact.sh new with the same KEY NAME EXT; switch: timed-run.sh --fallback ... --fallback-code FB-004 (WO-20261016-d304)
- tool: script:claude/workflow/bin/timed-run.sh - on main; fallback: missing: stop with DESIGN-GAP naming it

**Out - non-goals**

- editing any file; a failing case is a note on WO-20261016-6584 with its output
- work-orders/INDEX.md and epic READMEs by hand or by git add
- waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* TP-1 the unit tests pass in the pinned image
  - observed `2026-10-16` exit 0, Ran 8 tests, OK; log /home/luna/.local/state/zenith/log/2026/10/20261016-110422-wk5-test.log
  - check: `podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_review.py` exit 0 expect /^OK/
- [x] `AC-H2` *(human)* TP-2 the FB-001 fallback path runs the cached digest
  - observed `2026-10-16` exit 0, output has FALLBACK FB-001; log /home/luna/.local/state/zenith/log/2026/10/20261016-110422-wk5-test.log
  - check: `env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node wk5-t --fallback "podman run --rm --pull=never --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_review.py" --fallback-code FB-001 -- podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_review.py` exit 0 expect /FALLBACK FB-001/
- [ ] `AC-H3` *(human)* the diff holds only generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/tools/wiki review

**Cases**

- `TP-1`
  - intent: the unit tests of claude/tools/wiki review prove the spec contract; a broken one corrupts every wiki that calls it
  - command: `podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_review.py`
  - expected: exit 0; the last line is OK
- `TP-2`
  - intent: fallback path (owner item 28): registry pull refused, the cached digest runs through the FB-001 switch
  - command: `env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node wk5-t --fallback "podman run --rm --pull=never --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_review.py" --fallback-code FB-001 -- podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_review.py`
  - expected: exit 0; output contains FALLBACK FB-001

**Isolation**

- runtime: podman
- image: `docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9` (python:3.12-slim at pin time 2026-10-16)

**Out of scope - CI covers**

- lint and the full suite: CI runs them

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
