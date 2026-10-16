---
{
  "id": "WO-20261016-e983",
  "slug": "wk3t-test-plan-and-script-for-make-wiki-index",
  "title": "WK3t: test plan and script for make wiki-index",
  "type": "test",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T12:04:24+00:00",
  "parent": "WO-20261016-35de",
  "branch": "feat/e983-wk3t-test-plan-and-script-for-make-wiki-index",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design20 recut for DESIGN-GAP F48; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-b6a8"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_index.py",
      "exit": 0,
      "expect": "^OK"
    },
    {
      "index": 2,
      "command": "env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node wk3-t --fallback \"podman run --rm --pull=never --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_index.py\" --fallback-code FB-001 -- podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_index.py",
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

# WO-20261016-e983 - WK3t: test plan and script for make wiki-index

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

Test sibling of WK3. The tester runs exactly this plan from ~/dotfiles on the WK3 branch and nothing else. Orchestrator orders 2026-10-16 (MSG-20261016T061019Z-yp-design): ORD-0552 O2 'write each AC as command + expected exit code + expected output in the ticket text, and carry owner words verbatim and full context in Problem'; ORD-0555 O1 'before a ticket goes ready, list every tool, script, Make target and fixture its steps and AC checks call; any not on main gets a tooling ticket first'; ORD-0556 O1 'every tooling ticket builds a generic, config-driven tool in dotfiles'; ORD-0558 O1 'every design and ready ticket names the fallback for each tool and dependency it uses, the scripted switch with its status code, and a test case for the fallback path'.

## Owner words

> WO-20261016-ca80 - WK3t: test plan and script for make wiki-index: Test plan is a JSON line (no **Cases** block), same as 6803; start will refuse. Fix the generator that cuts WK*t tickets (F48 recurred 3x: 168e, 6803, ca80) (orchestrator brief BR-20261016-infra-design20)

## Context

Recut by infra-design20 (BR-20261016-infra-design20, DESIGN-GAP F48): the predecessor's ## Test plan was a one-line JSON fence, so start refused it test_plan_missing and amend refuses a ready ticket. Same In, Out, ACs and edges; the plan is the same cases rendered into the claude/workflow/templates/test-plan.md shape. The generator fix is WO-20261016-3d4d (new, amend and approve refuse a one-line plan on a test ticket).

## Scope

**In**

- touches: none outside work-orders; this is a --type test run of the merged WO-20261016-b6a8 code on origin/main
- touches (generated, written only by work-order.sh start/submit/evidence/done, never by hand or git add): this ticket file and its archive path
- step: worktree at origin/main after WO-20261016-b6a8 merged; run TP-1 and TP-2 exactly, from the worktree root
- step: write every case output to the path printed by `make -s artifact-new KEY=log NAME=wk3-test EXT=log`; evidence each AC with work-order.sh evidence --observed and that path
- step: a red case: work-order.sh note on WO-20261016-b6a8 with its output and stop with DESIGN-GAP; never edit a file
- tool: cmd:podman with docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 (python:3.12-slim at pin time 2026-10-16) - fallback: registry pull refused: rerun with --pull=never on the locally cached image of the same digest; switch: timed-run.sh --fallback ... --fallback-code FB-001 (WO-20261016-d304); fallback test: the FB-001 AC below
- tool: cmd:git, cmd:gh, cmd:make - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output
- tool: make:Makefile:artifact-new (on main) - fallback: bash claude/tools/artifact/artifact.sh new with the same KEY NAME EXT; switch: timed-run.sh --fallback ... --fallback-code FB-004 (WO-20261016-d304)
- tool: script:claude/workflow/bin/timed-run.sh - on main; fallback: missing: stop with DESIGN-GAP naming it

**Out - non-goals**

- editing any file; a failing case is a note on WO-20261016-b6a8 with its output
- work-orders/INDEX.md and epic READMEs by hand or by git add
- waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* TP-1 the unit tests pass in the pinned image
  - observed `2026-10-16` 7 tests OK exit 0; /home/luna/.local/state/zenith/log/2026/10/20261016-121441-wk3-test.log
  - check: `podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_index.py` exit 0 expect /^OK/
- [x] `AC-H2` *(human)* TP-2 the FB-001 fallback path runs the cached digest
  - observed `2026-10-16` FALLBACK FB-001 wk3-t, exit 0; /home/luna/.local/state/zenith/log/2026/10/20261016-121441-wk3-test.log
  - check: `env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node wk3-t --fallback "podman run --rm --pull=never --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_index.py" --fallback-code FB-001 -- podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_index.py` exit 0 expect /FALLBACK FB-001/
- [x] `AC-H3` *(human)* the diff holds only generated work-orders files
  - observed `2026-10-16` diff outside work-orders empty (grep exit 1); /home/luna/.local/state/zenith/log/2026/10/20261016-121441-wk3-test.log
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/tools/wiki index

**Cases**

- `TP-1`
  - intent: the unit tests of claude/tools/wiki index prove the spec contract; a broken one corrupts every wiki that calls it
  - command: `podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_index.py`
  - expected: exit 0; the last line is OK
- `TP-2`
  - intent: fallback path (owner item 28): registry pull refused, the cached digest runs through the FB-001 switch
  - command: `env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node wk3-t --fallback "podman run --rm --pull=never --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_index.py" --fallback-code FB-001 -- podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_index.py`
  - expected: exit 0; output contains FALLBACK FB-001

**Isolation**

- runtime: podman
- image: `docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9`

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
