---
{
  "id": "WO-20261016-a4da",
  "slug": "wk5t-test-plan-and-script-for-make-wiki-review",
  "title": "WK5t: test plan and script for make wiki-review",
  "type": "test",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:19:37+00:00",
  "parent": "WO-20261016-35de",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-6584"
  ],
  "blocks": []
}
---

# WO-20261016-a4da - WK5t: test plan and script for make wiki-review

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

Test sibling of WK5. The tester runs exactly this plan from ~/dotfiles on the WK5 branch and nothing else. Orchestrator orders 2026-10-16 (MSG-20261016T061019Z-yp-design): ORD-0552 O2 'write each AC as command + expected exit code + expected output in the ticket text, and carry owner words verbatim and full context in Problem'; ORD-0555 O1 'before a ticket goes ready, list every tool, script, Make target and fixture its steps and AC checks call; any not on main gets a tooling ticket first'; ORD-0556 O1 'every tooling ticket builds a generic, config-driven tool in dotfiles'; ORD-0558 O1 'every design and ready ticket names the fallback for each tool and dependency it uses, the scripted switch with its status code, and a test case for the fallback path'.

## Scope

**In**

- Run every case below from ~/dotfiles
- Evidence: the output of every case, written to the path printed by `make -s -C ~/dotfiles artifact-new KEY=log NAME=wk5-test EXT=log` (fallback FB-004: `bash ~/dotfiles/claude/tools/artifact/artifact.sh new` with the same KEY NAME EXT)

**Out - non-goals**

- Editing any file; a failing case is a note on the build ticket with its output

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* Every case passes: each case's command exits as its expected line says. Proof: the evidence log path on this ticket

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

make wiki-review

**Cases**

- `TP-1`
  - intent: wiki-review is part of the YieldPoint wiki's AC chain (BR-20261016-yp-wiki AC2-AC4)
  - command: `podman run --rm --network=none -v ~/dotfiles:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_review.py`
  - expected: exit 0, OK
- `TP-2`
  - intent: fallback path: registry unreachable, the cached digest runs
  - command: `FORCE_FALLBACK=1 bash ~/dotfiles/claude/workflow/bin/timed-run.sh --node wk5-t --fallback "podman run --rm --pull=never --network=none -v ~/dotfiles:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_review.py" --fallback-code FB-001 -- podman run --rm --network=none -v ~/dotfiles:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_review.py`
  - expected: exit 0, stderr contains FALLBACK FB-001

**Isolation**

- runtime: podman
- image: `docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9` (python:3.12-slim at pin time 2026-10-16)

**Out of scope - CI covers**

- lint and the full suite run in CI

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` DRAFT until tool WO-20261016-d304 - TR-FB (timed-run.sh --fallback) is on main (ORD-0555 O1); then approve --no-lavish --reason "architect ruled design approvals done, ORD-0550 O4"

## Outcome

_Written by `work-order done`. Empty until then._
