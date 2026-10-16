---
{
  "id": "WO-20261016-fa5f",
  "slug": "mk-inct-test-plan-and-script-for-scripts-mk-incl",
  "title": "MK-INCt: test plan and script for scripts/mk-include.sh",
  "type": "test",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:18:25+00:00",
  "parent": "WO-20261016-0272",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-474f"
  ],
  "blocks": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-fa5f - MK-INCt: test plan and script for scripts/mk-include.sh

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

Test sibling of MK-INC. The tester runs exactly this plan from ~/dotfiles on the MK-INC branch and nothing else. Orchestrator orders 2026-10-16 (MSG-20261016T061019Z-yp-design): ORD-0552 O2 'write each AC as command + expected exit code + expected output in the ticket text, and carry owner words verbatim and full context in Problem'; ORD-0555 O1 'before a ticket goes ready, list every tool, script, Make target and fixture its steps and AC checks call; any not on main gets a tooling ticket first'; ORD-0556 O1 'every tooling ticket builds a generic, config-driven tool in dotfiles'; ORD-0558 O1 'every design and ready ticket names the fallback for each tool and dependency it uses, the scripted switch with its status code, and a test case for the fallback path'.

## Scope

**In**

- Run every case below from ~/dotfiles
- Evidence: the output of every case, written to the path printed by `make -s -C ~/dotfiles artifact-new KEY=log NAME=mk-inc-test EXT=log` (fallback FB-004: `bash ~/dotfiles/claude/tools/artifact/artifact.sh new` with the same KEY NAME EXT)

**Out - non-goals**

- Editing any file; a failing case is a note on the build ticket with its output

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* Every case passes: each case's command exits as its expected line says. Proof: the evidence log path on this ticket

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

scripts/mk-include.sh

**Cases**

- `TP-1`
  - intent: two installs must leave one block, or a rerun corrupts a product Makefile
  - command: `podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash scripts/tests/test_mk_include.sh`
  - expected: exit 0
- `TP-2`
  - intent: fallback path: make unavailable, the script runs directly
  - command: `FORCE_FALLBACK=1 bash ~/dotfiles/claude/workflow/bin/timed-run.sh --node mk-inc-t --fallback "podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash scripts/tests/test_mk_include.sh" --fallback-code FB-008 -- make -C ~/dotfiles mk-include-test`
  - expected: exit 0, stderr contains FALLBACK FB-008

**Isolation**

- runtime: podman
- image: `docker.io/library/debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, the FROM of claude/workflow/tests/container/Containerfile, built as localhost/dotfiles-workflow-test:1 by make -C ~/dotfiles/claude/workflow image)

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
