---
{
  "id": "WO-20261016-f963",
  "slug": "close-wo-20261016-168d-wk2-wiki-process-code-pr-",
  "title": "Close WO-20261016-168d (WK2 wiki-process, code PR 306 and close-out PR 314 merged): re-run its checks 1,2,3,4,5 on main under this ticket, move its 6803, b6a8, 2013 edges here and cancel 168d as superseded",
  "type": "chore",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:31:12+00:00",
  "parent": "WO-20261016-35de",
  "branch": "feat/f963-close-wo-20261016-168d-wk2-wiki-process-code-pr-",
  "pr": 335,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design18 cut for ORD-1114 close-outs; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-6803",
    "WO-20261016-b6a8",
    "WO-20261016-2013",
    "WO-20261016-168d"
  ],
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
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-168d --json | jq -r '.status + \" \" + (.superseded_by // \"-\")'",
      "exit": 0,
      "expect": "^cancelled WO-"
    },
    {
      "index": 7,
      "command": "grep -rlE '\"WO-20261016-168d\"' work-orders --include='WO-*.md' | xargs -r grep -L -E '\"status\": \"(done|cancelled)\"' | grep -v -- '-168d-'",
      "exit": 1,
      "expect": null
    },
    {
      "index": 8,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "make:wiki-process"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-f963 - Close WO-20261016-168d (WK2 wiki-process, code PR 306 and close-out PR 314 merged): re-run its checks 1,2,3,4,5 on main under this ticket, move its 6803, b6a8, 2013 edges here and cancel 168d as superseded

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

WO-20261016-168d is listed ready by work-order.sh next on origin/main (11:12Z) although its code PR 306 and close-out PR 314 merged; the close-out never stamped it, so WO-20261016-6803, WO-20261016-b6a8 and WO-20261016-2013 wait on a ticket that will never close.

## Owner words

> design seat infra-design: ORD-1114 code_repo for every verb (reconcile 1b46 with e297 and 1099), stranded close-outs 9fc7 and 168d, DESIGN-GAP 168e test plan, F44 close-outs; keep the 6-leaf buffer (orchestrator brief BR-20261016-infra-design18)

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

## Context

Order brief BR-20261016-infra-design18; pattern WO-20261016-bcb4 and WO-20261016-aa46 (close successor). The scope check of WO-20261016-168d is dropped, not copied: on a close branch the diff is work-orders files only, which the last criterion asserts. This ticket already blocks WO-20261016-6803, WO-20261016-b6a8, WO-20261016-2013, so they wait on it from the moment it merges as ready.

Steps on the branch, after start, each exactly as written: bash claude/skills/work-order/scripts/work-order.sh link --id WO-20261016-6803 --no-depends-on WO-20261016-168d; bash claude/skills/work-order/scripts/work-order.sh link --id WO-20261016-b6a8 --no-depends-on WO-20261016-168d; bash claude/skills/work-order/scripts/work-order.sh link --id WO-20261016-2013 --no-depends-on WO-20261016-168d; bash claude/skills/work-order/scripts/work-order.sh cancel --id WO-20261016-168d --reason 'WK2 wiki-process, code PR 306 and close-out PR 314 merged; re-checked under THIS-TICKET-ID' --superseded-by THIS-TICKET-ID; bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID (check ticks every passing criterion; never tick by hand with evidence); commit those generated moves; open the PR; submit --pr <N>; done; commit and push. THIS-TICKET-ID is this ticket's own id, the .id in its frontmatter.

## Scope

**In**

- touches (generated, by work-order.sh link and cancel only): the WO-20261016-168d ticket file and its archive path, and the ticket files of WO-20261016-6803, WO-20261016-b6a8, WO-20261016-2013
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone
- step: run the links, the cancel and the check exactly as in Context, then submit --pr <this PR> and done
- step: commit 'chore(work-orders): close WO-20261016-168d under its re-checked successor' with the ticket id; no Bump trailer
- tool: script:claude/workflow/bin/timed-run.sh, make:Makefile:wiki-process - on main (PR 306); fallback: missing: stop with DESIGN-GAP naming it; the python image pull fails: retry 3 times, then stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: script:claude/skills/work-order/scripts/work-order.sh - on main; fallback: a verb refuses: stop with its status code and output, never edit a ticket by hand
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any code, test or doc file: the merged PR shipped them
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* WO-20261016-168d check 1 passes on main (copied from WO-20261016-168d check 1)
  - observed `2026-10-16` check: podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_process.py exit 0 output: test_missing_source_exits_3_and_writes_nothing (claude.tools.wiki.tests.test_process.ProcessTest.test_missing_source_exits_3_and_writes_nothing) ... ok test_rerun_is_byte_identical_and_unchanged (claude.tools.wiki.tests.test_process.ProcessTest.test_rerun_is_byte_identical_and_unchanged) ... ok test_skeleton_has_structure_and_citation (claude.tools.wiki.tests.test_process.ProcessTest.test_skeleton_has_structure_and_citation) ... ok test_usage_and_bad_pages_json (claude.tools.wiki.tests.test_process.ProcessTest.test_usage_and_bad_pages_json) ... ok test_written_prose_survives_and_sections_append (claude.tools.wiki.tests.test_process.ProcessTest.test_written_prose_survives_and_sections_append) ... ok ---------------------------------------------------------------------- Ran 5 tests in 0.615s OK
  - check: `podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_process.py` exit 0 expect /^OK/
- [x] `AC-H2` *(human)* WO-20261016-168d check 2 passes on main (copied from WO-20261016-168d check 2)
  - observed `2026-10-16` check: env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node wk2 --fallback "podman run --rm --pull=never --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_process.py" --fallback-code FB-001 -- podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_process.py exit 0 output: test_missing_source_exits_3_and_writes_nothing (claude.tools.wiki.tests.test_process.ProcessTest.test_missing_source_exits_3_and_writes_nothing) ... ok test_rerun_is_byte_identical_and_unchanged (claude.tools.wiki.tests.test_process.ProcessTest.test_rerun_is_byte_identical_and_unchanged) ... ok test_skeleton_has_structure_and_citation (claude.tools.wiki.tests.test_process.ProcessTest.test_skeleton_has_structure_and_citation) ... ok test_usage_and_bad_pages_json (claude.tools.wiki.tests.test_process.ProcessTest.test_usage_and_bad_pages_json) ... ok test_written_prose_survives_and_sections_append (claude.tools.wiki.tests.test_process.ProcessTest.test_written_prose_survives_and_sections_append) ... ok ---------------------------------------------------------------------- Ran 5 tests in 0.484s OK FALLBACK FB-001 wk2
  - check: `env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node wk2 --fallback "podman run --rm --pull=never --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_process.py" --fallback-code FB-001 -- podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_process.py` exit 0 expect /FALLBACK FB-001/
- [x] `AC-H3` *(human)* WO-20261016-168d check 3 passes on main (copied from WO-20261016-168d check 3)
  - observed `2026-10-16` check: make -n wiki-process WIKI=/tmp/wk SRC=/tmp/src exit 0 output: if [ -z "/tmp/wk" ]; then echo "usage: WIKI=<root> is required" >&2; exit 2; fi python3 claude/tools/wiki/wiki_process.py "/tmp/wk"
  - check: `make -n wiki-process WIKI=/tmp/wk SRC=/tmp/src` exit 0 expect /wiki_process\.py/
- [x] `AC-H4` *(human)* WO-20261016-168d check 4 passes on main (copied from WO-20261016-168d check 4)
  - observed `2026-10-16` check: make -s wiki-process WIKI= SRC=/tmp/src exit 2 output: usage: WIKI=<root> is required make: *** [claude/tools/wiki/mk/process.mk:6: wiki-process] Error 2
  - check: `make -s wiki-process WIKI= SRC=/tmp/src` exit 2 expect /WIKI/
- [x] `AC-H5` *(human)* WO-20261016-168d check 5 passes on main (copied from WO-20261016-168d check 5)
  - observed `2026-10-16` check: make rolodex-check BASE=origin/main exit 0 output: python3 scripts/rolodex.py check --root . --base origin/main rolodex-check: 0 script(s) checked, all have headers
  - check: `make rolodex-check BASE=origin/main` exit 0
- [x] `AC-H6` *(human)* WO-20261016-168d is cancelled and superseded
  - observed `2026-10-16` check: bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-168d --json | jq -r '.status + " " + (.superseded_by // "-")' exit 0 output: cancelled WO-20261016-f963
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-168d --json | jq -r '.status + " " + (.superseded_by // "-")'` exit 0 expect /^cancelled WO-/
- [x] `AC-H7` *(human)* no open ticket still depends on WO-20261016-168d
  - observed `2026-10-16` check: grep -rlE '"WO-20261016-168d"' work-orders --include='WO-*.md' | xargs -r grep -L -E '"status": "(done|cancelled)"' | grep -v -- '-168d-' exit 1 output:
  - check: `grep -rlE '"WO-20261016-168d"' work-orders --include='WO-*.md' | xargs -r grep -L -E '"status": "(done|cancelled)"' | grep -v -- '-168d-'` exit 1
- [x] `AC-H8` *(human)* the diff holds only generated work-orders files
  - observed `2026-10-16` check: git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$' exit 1 output:
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

WO-20261016-168d checks 1-5 re-run on main under its close successor

**Cases**

- `TP-1`
  - intent: merged PR 306 still meets every criterion of WO-20261016-168d, and 6803, b6a8 and 2013 stop waiting on a ticket that will never close
  - command: `bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID`
  - expected: exit 0; one AC-PASS line per criterion

**Isolation**

- runtime: podman
- image: `docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9` (python:3.12-slim)

**Out of scope - CI covers**

- lint and the full suite: CI runs them (Design principles 101 item 6)

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` provides make:wiki-process only because approve's make resolver misses the -include $(wildcard claude/tools/wiki/mk/*.mk) in Makefile (WO-20261016-0f38, PR 321 open); the target is on main via that include and this ticket builds nothing

## Outcome

_Written by `work-order done`. Empty until then._
