---
{
  "id": "WO-20261016-b1b7",
  "slug": "yw-rt-test-plan-and-script-for-the-yieldpoint-wi",
  "title": "YW-Rt: test plan and script for the YieldPoint wiki repo config",
  "type": "test",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:19:49+00:00",
  "parent": "WO-20261016-35de",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-7784"
  ],
  "blocks": []
}
---

# WO-20261016-b1b7 - YW-Rt: test plan and script for the YieldPoint wiki repo config

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

Test sibling of YW-R. The tester runs exactly this plan from ~/projects/yieldpoint-ai/wiki on the YW-R branch and nothing else. Orchestrator orders 2026-10-16 (MSG-20261016T061019Z-yp-design): ORD-0552 O2 'write each AC as command + expected exit code + expected output in the ticket text, and carry owner words verbatim and full context in Problem'; ORD-0555 O1 'before a ticket goes ready, list every tool, script, Make target and fixture its steps and AC checks call; any not on main gets a tooling ticket first'; ORD-0556 O1 'every tooling ticket builds a generic, config-driven tool in dotfiles'; ORD-0558 O1 'every design and ready ticket names the fallback for each tool and dependency it uses, the scripted switch with its status code, and a test case for the fallback path'.

## Scope

**In**

- Run every case below from ~/projects/yieldpoint-ai/wiki
- Evidence: the output of every case, written to the path printed by `make -s -C ~/dotfiles artifact-new KEY=log NAME=yw-r-test EXT=log` (fallback FB-004: `bash ~/dotfiles/claude/tools/artifact/artifact.sh new` with the same KEY NAME EXT)

**Out - non-goals**

- Editing any file; a failing case is a note on the build ticket with its output

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* Every case passes: each case's command exits as its expected line says. Proof: the evidence log path on this ticket

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the YieldPoint wiki repo config

**Cases**

- `TP-1`
  - intent: a wiki repo without a remote cannot carry PRs
  - command: `git -C ~/projects/yieldpoint-ai/wiki remote get-url origin`
  - expected: exit 0
- `TP-2`
  - intent: config the engine reads must parse
  - command: `jq -e . ~/projects/yieldpoint-ai/wiki/wiki.json ~/projects/yieldpoint-ai/wiki/pages.json ~/projects/yieldpoint-ai/wiki/review.json`
  - expected: exit 0
- `TP-3`
  - intent: fallback path: gh down parks the PR step with its code
  - command: `FORCE_FALLBACK=1 bash ~/dotfiles/claude/workflow/bin/timed-run.sh --node yw-r-t --fallback "echo parked" --fallback-code FB-003 -- false`
  - expected: exit 0, stderr contains FALLBACK FB-003

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

- `2026-10-16` DESIGN-GAP (infra-design12): stays draft; its build ticket WO-20261016-7784 - YW-R is draft (see its note)
- `2026-10-16` DRAFT until tool WO-20261016-d304 - TR-FB (timed-run.sh --fallback) is on main (ORD-0555 O1); then approve --no-lavish --reason "architect ruled design approvals done, ORD-0550 O4"

## Outcome

_Written by `work-order done`. Empty until then._
