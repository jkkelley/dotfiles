---
{
  "id": "WO-20261016-7a8f",
  "slug": "wk-dt-test-plan-and-script-for-the-wiki-engine-d",
  "title": "WK-Dt: test plan and script for the wiki engine design doc and spec",
  "type": "test",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:18:35+00:00",
  "parent": "WO-20261016-35de",
  "branch": "feat/wk-dt-test-plan-and-script-for-the-wiki-engine-d",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design11 cut for ORD-0932-next Q2 and the ORD-0830 RR-orch-14 DESIGN-GAPs; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-6e7f"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash scripts/spec-check.sh docs/design/wiki.spec.xml",
      "exit": 0,
      "expect": null
    },
    {
      "index": 2,
      "command": "bash scripts/md-contents.sh check docs/design/wiki.md",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "grep -c fallback docs/design/wiki.spec.xml",
      "exit": 0,
      "expect": "^([5-9]|[1-9][0-9]+)$"
    }
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-7a8f - WK-Dt: test plan and script for the wiki engine design doc and spec

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

Test sibling of WK-D. The tester runs exactly this plan from ~/dotfiles on the WK-D branch and nothing else. Orchestrator orders 2026-10-16 (MSG-20261016T061019Z-yp-design): ORD-0552 O2 'write each AC as command + expected exit code + expected output in the ticket text, and carry owner words verbatim and full context in Problem'; ORD-0555 O1 'before a ticket goes ready, list every tool, script, Make target and fixture its steps and AC checks call; any not on main gets a tooling ticket first'; ORD-0556 O1 'every tooling ticket builds a generic, config-driven tool in dotfiles'; ORD-0558 O1 'every design and ready ticket names the fallback for each tool and dependency it uses, the scripted switch with its status code, and a test case for the fallback path'.

## Scope

**In**

- touches: nothing; the tester edits no file. Evidence goes to the artifact store only
- step: check out the WK-D branch of WO-20261016-6e7f - WK-D: wiki engine design doc and XML spec - mermaid pipeline, status codes, GOOD/NEVER per rule in your own worktree from ~/dotfiles (its PR head), after WK-D submitted
- step: run every AC check below in that worktree, in order; write their combined output to the path printed by `make -s artifact-new KEY=log NAME=wk-d-test EXT=log`; record each result with work-order.sh evidence
- tool: path:scripts/spec-check.sh, path:scripts/md-contents.sh - on main; fallback: python3 missing on the host: run the same command in the pinned python image of the test plan, status FB-001 when the pull fails and the cached digest is used
- tool: make:artifact-new - on main; fallback FB-004: bash claude/tools/artifact/artifact.sh new with the same KEY NAME EXT
- tool: cmd:grep, cmd:git - fallback: missing on the host: stop with ENV-MISSING naming it

**Out - non-goals**

- Editing any file; a failing case is a note on WO-20261016-6e7f with its output, then A2A-003
- Waiting on CI or merging WK-D: run, evidence, result, leave (ORD-0542 O2)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* TP-1 the spec passes spec-check (1000 lines or less, parses, contents first)
  - observed `2026-10-16` check: bash scripts/spec-check.sh docs/design/wiki.spec.xml exit 0 output: ok docs/design/wiki.spec.xml (145 lines)
  - check: `bash scripts/spec-check.sh docs/design/wiki.spec.xml` exit 0
- [x] `AC-H2` *(human)* TP-2 the design doc opens with its contents list
  - observed `2026-10-16` check: bash scripts/md-contents.sh check docs/design/wiki.md exit 0 output: npm notice npm notice New major version of npm available! 10.9.9 -> 12.2.0 npm notice Changelog: https://github.com/npm/cli/releases/tag/v12.2.0 npm notice To update run: npm install -g npm@12.2.0 npm notice md-contents: 1 file(s) ok
  - check: `bash scripts/md-contents.sh check docs/design/wiki.md` exit 0
- [x] `AC-H3` *(human)* TP-3 the spec names a fallback at least five times (ORD-0558 O1)
  - observed `2026-10-16` check: grep -c fallback docs/design/wiki.spec.xml exit 0 output: 13
  - check: `grep -c fallback docs/design/wiki.spec.xml` exit 0 expect /^([5-9]|[1-9][0-9]+)$/

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the wiki engine design doc and spec

**Cases**

- `TP-1`
  - intent: a spec over 1000 lines or without contents breaks item 28
  - command: `bash scripts/spec-check.sh docs/design/wiki.spec.xml`
  - expected: exit 0
- `TP-2`
  - intent: a design without a contents list breaks the owner Markdown rule
  - command: `bash scripts/md-contents.sh check docs/design/wiki.md`
  - expected: exit 0
- `TP-3`
  - intent: fallback path: a design names a fallback for every verb (ORD-0558 O1)
  - command: `grep -c 'fallback' docs/design/wiki.spec.xml`
  - expected: exit 0, count at least 5

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
