---
{
  "id": "WO-20261016-cdd4",
  "slug": "close-wo-20261016-168d-wk2-wiki-process-pr-306-m",
  "title": "Close WO-20261016-168d (WK2 wiki-process, PR 306 merged): re-run its checks under this ticket, move its edges here and cancel 168d as superseded",
  "type": "chore",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:38:54+00:00",
  "parent": "WO-20261016-35de",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-0f38"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_process.py",
      "exit": 0,
      "expect": "^OK"
    },
    {
      "index": 2,
      "command": "env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node wk2 --fallback \"podman run --rm --pull=never --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_process.py\" --fallback-code FB-001 -- podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_process.py",
      "exit": 0,
      "expect": "FALLBACK FB-001"
    },
    {
      "index": 3,
      "command": "make -n wiki-process WIKI=/tmp/wk SRC=/tmp/src",
      "exit": 0,
      "expect": "wiki_process\\.py"
    },
    {
      "index": 4,
      "command": "make -s wiki-process WIKI= SRC=/tmp/src",
      "exit": 2,
      "expect": "WIKI"
    },
    {
      "index": 5,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 6,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/tools/wiki/wiki_process\\.py|claude/tools/wiki/mk/process\\.mk|claude/tools/wiki/tests/test_process\\.py)$'",
      "exit": 1,
      "expect": null
    },
    {
      "index": 7,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-168d --json | jq -r '.status + \" \" + (.superseded_by // \"-\")'",
      "exit": 0,
      "expect": "^cancelled WO-"
    },
    {
      "index": 8,
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

# WO-20261016-cdd4 - Close WO-20261016-168d (WK2 wiki-process, PR 306 merged): re-run its checks under this ticket, move its edges here and cancel 168d as superseded

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

WO-20261016-168d shipped in PR 306 (merged) but its ticket is still ready on main and cannot close: start refuses branch_exists: feat/wk2-wiki-process-wiki-writes-page-skeletons-from is held by /home/luna/.cache/wt-wk2, whose uncommitted ticket edit holds off-by-one evidence; main holds no evidence, so no evidence-clear verb is needed

## Owner words

> close-outs fb99 3327 168d (F45-F47) (orchestrator brief BR-20261016-infra-design15)

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

## Context

Order brief BR-20261016-infra-design15, ORD-0830 RR-orch-14; F35. Pattern: WO-20261016-bcb4 (A2A-ST close). The original ticket's checks are copied here verbatim as this ticket's checks, so done re-proves the merged code on main. THIS-TICKET-ID is this ticket's own id, the .id in its frontmatter. Steps on the branch, after start: for id in $(bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-168d --json | jq -r '.blocks[]'): bash claude/skills/work-order/scripts/work-order.sh link --id $id --depends-on THIS-TICKET-ID --no-depends-on WO-20261016-168d; then bash claude/skills/work-order/scripts/work-order.sh cancel --id WO-20261016-168d --reason 'code merged in PR 306; close-out blocked (start refuses branch_exists: feat/wk2-wiki-process-wiki-writes-page-skeletons-from is held by /home/luna/.cache/wt-wk2, whose uncommitted ticket edit holds off-by-one evidence; main holds no evidence, so no evidence-clear verb is needed); checks re-run under THIS-TICKET-ID' --superseded-by THIS-TICKET-ID; then bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID (check ticks every passing criterion; never tick by hand with evidence); commit those generated moves.

## Scope

**In**

- touches (generated, by work-order.sh link and cancel only): the WO-20261016-168d ticket file and its archive path, the ticket files of every id in its blocks list
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: run the link loop and the cancel exactly as in Context, then work-order.sh check --id THIS-TICKET-ID, submit --pr <this PR>, done
- step: commit 'chore(work-orders): close WO-20261016-168d under its re-checked successor' with the ticket id; no Bump trailer
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any code, test or doc file: PR 306 shipped them
- the stale seat worktree and branch named in Problem: the orchestrator retires them (line operation)
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* WO-20261016-168d check 1 passes on main
  - check: `podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_process.py` exit 0 expect /^OK/
- [ ] `AC-H2` *(human)* WO-20261016-168d check 2 passes on main
  - check: `env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node wk2 --fallback "podman run --rm --pull=never --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_process.py" --fallback-code FB-001 -- podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_process.py` exit 0 expect /FALLBACK FB-001/
- [ ] `AC-H3` *(human)* WO-20261016-168d check 3 passes on main
  - check: `make -n wiki-process WIKI=/tmp/wk SRC=/tmp/src` exit 0 expect /wiki_process\.py/
- [ ] `AC-H4` *(human)* WO-20261016-168d check 4 passes on main
  - check: `make -s wiki-process WIKI= SRC=/tmp/src` exit 2 expect /WIKI/
- [ ] `AC-H5` *(human)* WO-20261016-168d check 5 passes on main
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H6` *(human)* WO-20261016-168d check 6 passes on main
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/tools/wiki/wiki_process\.py|claude/tools/wiki/mk/process\.mk|claude/tools/wiki/tests/test_process\.py)$'` exit 1
- [ ] `AC-H7` *(human)* WO-20261016-168d is cancelled and superseded by this ticket
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-168d --json | jq -r '.status + " " + (.superseded_by // "-")'` exit 0 expect /^cancelled WO-/
- [ ] `AC-H8` *(human)* the diff holds only generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

```sh
{"scope":"WO-20261016-168d checks re-run on main","cases":[{"id":"TP-1","intent":"merged code still meets every criterion of WO-20261016-168d","command":"bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID","expected":"exit 0; one AC-PASS line per criterion"}],"isolation":{"runtime":"podman","image":"as each copied check names"},"out_of_scope":["full suites: CI runs them"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` draft until WO-20261016-0f38 merges: approve refused tool_missing wiki-process (resolver skips the wildcard include in claude/tools/wiki/wiki.mk; make -n wiki-process exits 0 on main). Approve after WO-20261016-0f38 is on main.

## Outcome

_Written by `work-order done`. Empty until then._
