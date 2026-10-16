---
{
  "id": "WO-20261016-96c4",
  "slug": "wk0-wiki-engine-skeleton-wiki-mk-with-per-verb-i",
  "title": "WK0: wiki engine skeleton - wiki.mk with per-verb includes, wikilib.py, default secret patterns",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:18:41+00:00",
  "parent": "WO-20261016-35de",
  "branch": "feat/wk0-wiki-engine-skeleton-wiki-mk-with-per-verb-i",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "design seat infra-design12 cut from wiki.spec.xml (PR 285), ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4; owner surface is Bearings, lavish prohibited for Claude seats",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-d304",
    "WO-20261016-6e7f"
  ],
  "blocks": [
    "WO-20261016-d6b3",
    "WO-20261016-b9ba",
    "WO-20261016-168d",
    "WO-20261016-b6a8",
    "WO-20261016-0b9c",
    "WO-20261016-6584"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_wikilib.py",
      "exit": 0,
      "expect": "^OK"
    },
    {
      "index": 2,
      "command": "env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node wk0 --fallback \"podman run --rm --pull=never --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_wikilib.py\" --fallback-code FB-001 -- podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_wikilib.py",
      "exit": 0,
      "expect": "FALLBACK FB-001"
    },
    {
      "index": 3,
      "command": "make -n wiki-test",
      "exit": 0,
      "expect": "podman"
    },
    {
      "index": 4,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 5,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|Makefile|claude/tools/wiki/wiki\\.mk|claude/tools/wiki/wikilib\\.py|claude/tools/wiki/secret-patterns\\.json|claude/tools/wiki/tests/test_wikilib\\.py|claude/tools/wiki/README\\.md)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "make:wiki-test"
  ]
}
---

# WO-20261016-96c4 - WK0: wiki engine skeleton - wiki.mk with per-verb includes, wikilib.py, default secret patterns

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

Owner words, verbatim: "MAKE SURE A KNOWLEDGE BASE WIKI OF YIELDPOINT AI IS BUILT AND USING DOC DESIGN FIRST AND PUT THAT SHIT IN THE ~/PROJECTS/YIELDPOINT/WIKI/<ALL SUB DIRS HERE INTAKE|RAW|PROCESS|I'M JUST MAKING SHIT UP TO SHOW>"; "good never examples"; "get everything centrally located for this yieldpoint stuff, i have a directory already in ~/projects". Architect ruling BR-20261016-yp-wiki: the wiki is ~/projects/yieldpoint-ai/wiki. ORD-0556 O1: the engine is a generic, config-driven dotfiles tool at claude/tools/wiki/, called as `make -C ~/dotfiles wiki-<verb> WIKI=<root>`; the YieldPoint wiki holds only config and content. This replaces business tickets YW0-YW7 (cancelled, superseded). Line node: WO-20261016-35de - Line build L2 - yp-wiki and wiki-review. Tooling for WK1-WK5: every verb uses wikilib and the include pattern. Engine layout (fixed by design): claude/tools/wiki/wiki.mk (included from the dotfiles root Makefile; it includes claude/tools/wiki/mk/*.mk, one per verb), claude/tools/wiki/wikilib.py, claude/tools/wiki/wiki_<verb>.py, claude/tools/wiki/tests/test_<verb>.py, claude/tools/wiki/secret-patterns.json (default, overridable by <WIKI>/secret-patterns.json). Wiki root layout read from <WIKI>/wiki.json: intake_dir intake, raw_dir raw, processed_dir processed, index_dir index, blob_limit_bytes 1048576, max_page_lines 200, review_dir. Raw capture raw/<sha12>-<slug>.md: frontmatter source (~ for $HOME), captured_at UTC Z, sha256, bytes, blob (artifact store path, only over the limit). Processed page processed/<id>.md: frontmatter id, title, topic, sources (raw file names), updated; '# title'; '## Contents'; one '## <a id="anchor"></a>Heading' per section of <WIKI>/pages.json; every section links ../raw/<file> at least once. Orchestrator orders 2026-10-16 (MSG-20261016T061019Z-yp-design): ORD-0552 O2 'write each AC as command + expected exit code + expected output in the ticket text, and carry owner words verbatim and full context in Problem'; ORD-0555 O1 'before a ticket goes ready, list every tool, script, Make target and fixture its steps and AC checks call; any not on main gets a tooling ticket first'; ORD-0556 O1 'every tooling ticket builds a generic, config-driven tool in dotfiles'; ORD-0558 O1 'every design and ready ticket names the fallback for each tool and dependency it uses, the scripted switch with its status code, and a test case for the fallback path'.

## Scope

**In**

- touches: Makefile
- touches: claude/tools/wiki/wiki.mk
- touches: claude/tools/wiki/wikilib.py
- touches: claude/tools/wiki/secret-patterns.json
- touches: claude/tools/wiki/tests/test_wikilib.py
- touches: claude/tools/wiki/README.md
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path
- exact behaviour: docs/design/wiki.spec.xml and docs/design/wiki.md (PR 285); the Problem section of this ticket carries the same contract verbatim
- step: branch from origin/main in your own worktree after every depends_on ticket is merged; write exactly the files above
- step: run `podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_wikilib.py` then the AC checks only; CI runs the rest
- step: commit 'feat(wiki): engine skeleton, wiki.mk, wikilib, secret patterns (WO-20261016-96c4)'; no Bump trailer (no file under claude/skills changes); push, open the PR, write the result, leave
- tool: cmd:podman with docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 (python:3.12-slim at pin time 2026-10-16) - fallback: registry pull refused: rerun with --pull=never on the locally cached image of the same digest; switch: timed-run.sh --fallback ... --fallback-code FB-001 (WO-20261016-d304); fallback test: the FB-001 AC below
- tool: cmd:git, cmd:gh, cmd:make - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output
- tool: script:claude/workflow/bin/timed-run.sh and make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it

**Out - non-goals**

- work-orders/INDEX.md and epic READMEs by hand or by git add
- waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the unit tests pass in the pinned image
  - observed `2026-10-16` AC-H1 ran by script on feat/wk0-wiki-skeleton: passed with expected exit and output (unittest 10 tests OK; FALLBACK FB-001 wk0; make -n wiki-test shows podman; rolodex-check all headers; diff has only In files)
  - check: `podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_wikilib.py` exit 0 expect /^OK/
- [x] `AC-H2` *(human)* the FB-001 fallback path runs the cached digest
  - observed `2026-10-16` AC-H2 ran by script on feat/wk0-wiki-skeleton: passed with expected exit and output (unittest 10 tests OK; FALLBACK FB-001 wk0; make -n wiki-test shows podman; rolodex-check all headers; diff has only In files)
  - check: `env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node wk0 --fallback "podman run --rm --pull=never --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_wikilib.py" --fallback-code FB-001 -- podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_wikilib.py` exit 0 expect /FALLBACK FB-001/
- [x] `AC-H3` *(human)* wiki-test is included from the root Makefile and runs the pinned image
  - observed `2026-10-16` AC-H3 ran by script on feat/wk0-wiki-skeleton: passed with expected exit and output (unittest 10 tests OK; FALLBACK FB-001 wk0; make -n wiki-test shows podman; rolodex-check all headers; diff has only In files)
  - check: `make -n wiki-test` exit 0 expect /podman/
- [x] `AC-H4` *(human)* every changed script has a rolodex header
  - observed `2026-10-16` AC-H4 ran by script on feat/wk0-wiki-skeleton: passed with expected exit and output (unittest 10 tests OK; FALLBACK FB-001 wk0; make -n wiki-test shows podman; rolodex-check all headers; diff has only In files)
  - check: `make rolodex-check BASE=origin/main` exit 0
- [x] `AC-H5` *(human)* the diff holds only In files and generated work-orders files
  - observed `2026-10-16` AC-H5 ran by script on feat/wk0-wiki-skeleton: passed with expected exit and output (unittest 10 tests OK; FALLBACK FB-001 wk0; make -n wiki-test shows podman; rolodex-check all headers; diff has only In files)
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|Makefile|claude/tools/wiki/wiki\.mk|claude/tools/wiki/wikilib\.py|claude/tools/wiki/secret-patterns\.json|claude/tools/wiki/tests/test_wikilib\.py|claude/tools/wiki/README\.md)$'` exit 1

## Test plan

```sh
{"scope":"claude/tools/wiki wikilib","cases":[{"id":"TP-1","intent":"the unit tests of claude/tools/wiki wikilib prove the spec contract; a broken one corrupts every wiki that calls it","command":"podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_wikilib.py","expected":"exit 0; the last line is OK"},{"id":"TP-2","intent":"fallback path (owner item 28): registry pull refused, the cached digest runs through the FB-001 switch","command":"env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node wk0-t --fallback \"podman run --rm --pull=never --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_wikilib.py\" --fallback-code FB-001 -- podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_wikilib.py","expected":"exit 0; output contains FALLBACK FB-001"}],"isolation":{"runtime":"podman","image":"docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9"},"out_of_scope":["lint and the full suite: CI runs them"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` DRAFT until tool WO-20261016-d304 - TR-FB (timed-run.sh --fallback) is on main (ORD-0555 O1); then approve --no-lavish --reason "architect ruled design approvals done, ORD-0550 O4"

## Outcome

_Written by `work-order done`. Empty until then._
