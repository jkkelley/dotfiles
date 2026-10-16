---
{
  "id": "WO-20261016-0b9c",
  "slug": "wk4-wiki-check-wiki-fails-on-missing-contents-br",
  "title": "WK4: wiki-check WIKI= fails on missing contents, broken links, orphans, uncited sections, size, secrets and TODO-WRITE",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:19:22+00:00",
  "parent": "WO-20261016-35de",
  "branch": null,
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
    "WO-20261016-96c4",
    "WO-20261016-96c4"
  ],
  "blocks": [
    "WO-20261016-b335",
    "WO-20261016-7784"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_check.py",
      "exit": 0,
      "expect": "^OK"
    },
    {
      "index": 2,
      "command": "env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node wk4 --fallback \"podman run --rm --pull=never --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_check.py\" --fallback-code FB-001 -- podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_check.py",
      "exit": 0,
      "expect": "FALLBACK FB-001"
    },
    {
      "index": 3,
      "command": "make -n wiki-check WIKI=/tmp/wk SRC=/tmp/src",
      "exit": 0,
      "expect": "wiki_check\\.py"
    },
    {
      "index": 4,
      "command": "make -s wiki-check WIKI= SRC=/tmp/src",
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
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/tools/wiki/wiki_check\\.py|claude/tools/wiki/mk/check\\.mk|claude/tools/wiki/tests/test_check\\.py)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "make:wiki-check"
  ]
}
---

# WO-20261016-0b9c - WK4: wiki-check WIKI= fails on missing contents, broken links, orphans, uncited sections, size, secrets and TODO-WRITE

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

Owner words, verbatim: "MAKE SURE A KNOWLEDGE BASE WIKI OF YIELDPOINT AI IS BUILT AND USING DOC DESIGN FIRST AND PUT THAT SHIT IN THE ~/PROJECTS/YIELDPOINT/WIKI/<ALL SUB DIRS HERE INTAKE|RAW|PROCESS|I'M JUST MAKING SHIT UP TO SHOW>"; "good never examples"; "get everything centrally located for this yieldpoint stuff, i have a directory already in ~/projects". Architect ruling BR-20261016-yp-wiki: the wiki is ~/projects/yieldpoint-ai/wiki. ORD-0556 O1: the engine is a generic, config-driven dotfiles tool at claude/tools/wiki/, called as `make -C ~/dotfiles wiki-<verb> WIKI=<root>`; the YieldPoint wiki holds only config and content. This replaces business tickets YW0-YW7 (cancelled, superseded). Line node: WO-20261016-35de - Line build L2 - yp-wiki and wiki-review. Brief: 'make wiki-check (contents list, broken links, orphan pages, uncited claims, page size)'; 'no secrets in the wiki: a check fails a page matching secret patterns'. Engine layout (fixed by design): claude/tools/wiki/wiki.mk (included from the dotfiles root Makefile; it includes claude/tools/wiki/mk/*.mk, one per verb), claude/tools/wiki/wikilib.py, claude/tools/wiki/wiki_<verb>.py, claude/tools/wiki/tests/test_<verb>.py, claude/tools/wiki/secret-patterns.json (default, overridable by <WIKI>/secret-patterns.json). Wiki root layout read from <WIKI>/wiki.json: intake_dir intake, raw_dir raw, processed_dir processed, index_dir index, blob_limit_bytes 1048576, max_page_lines 200, review_dir. Raw capture raw/<sha12>-<slug>.md: frontmatter source (~ for $HOME), captured_at UTC Z, sha256, bytes, blob (artifact store path, only over the limit). Processed page processed/<id>.md: frontmatter id, title, topic, sources (raw file names), updated; '# title'; '## Contents'; one '## <a id="anchor"></a>Heading' per section of <WIKI>/pages.json; every section links ../raw/<file> at least once. Orchestrator orders 2026-10-16 (MSG-20261016T061019Z-yp-design): ORD-0552 O2 'write each AC as command + expected exit code + expected output in the ticket text, and carry owner words verbatim and full context in Problem'; ORD-0555 O1 'before a ticket goes ready, list every tool, script, Make target and fixture its steps and AC checks call; any not on main gets a tooling ticket first'; ORD-0556 O1 'every tooling ticket builds a generic, config-driven tool in dotfiles'; ORD-0558 O1 'every design and ready ticket names the fallback for each tool and dependency it uses, the scripted switch with its status code, and a test case for the fallback path'.

## Scope

**In**

- touches: claude/tools/wiki/wiki_check.py
- touches: claude/tools/wiki/mk/check.mk
- touches: claude/tools/wiki/tests/test_check.py
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path
- exact behaviour: docs/design/wiki.spec.xml and docs/design/wiki.md (PR 285); the Problem section of this ticket carries the same contract verbatim
- step: branch from origin/main in your own worktree after every depends_on ticket is merged; write exactly the files above
- step: run `podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_check.py` then the AC checks only; CI runs the rest
- step: commit 'feat(wiki): wiki-check fails on contents, links, orphans, citations, size, secrets, TODO-WRITE (WO-20261016-0b9c)'; no Bump trailer (no file under claude/skills changes); push, open the PR, write the result, leave
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

- [ ] `AC-H1` *(human)* the unit tests pass in the pinned image
  - check: `podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_check.py` exit 0 expect /^OK/
- [ ] `AC-H2` *(human)* the FB-001 fallback path runs the cached digest
  - check: `env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node wk4 --fallback "podman run --rm --pull=never --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_check.py" --fallback-code FB-001 -- podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_check.py` exit 0 expect /FALLBACK FB-001/
- [ ] `AC-H3` *(human)* the make target wraps the verb script
  - check: `make -n wiki-check WIKI=/tmp/wk SRC=/tmp/src` exit 0 expect /wiki_check\.py/
- [ ] `AC-H4` *(human)* an empty WIKI is a usage error
  - check: `make -s wiki-check WIKI= SRC=/tmp/src` exit 2 expect /WIKI/
- [ ] `AC-H5` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H6` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/tools/wiki/wiki_check\.py|claude/tools/wiki/mk/check\.mk|claude/tools/wiki/tests/test_check\.py)$'` exit 1

## Test plan

```sh
{"scope":"claude/tools/wiki check","cases":[{"id":"TP-1","intent":"the unit tests of claude/tools/wiki check prove the spec contract; a broken one corrupts every wiki that calls it","command":"podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_check.py","expected":"exit 0; the last line is OK"},{"id":"TP-2","intent":"fallback path (owner item 28): registry pull refused, the cached digest runs through the FB-001 switch","command":"env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node wk4-t --fallback \"podman run --rm --pull=never --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_check.py\" --fallback-code FB-001 -- podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_check.py","expected":"exit 0; output contains FALLBACK FB-001"}],"isolation":{"runtime":"podman","image":"docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9"},"out_of_scope":["lint and the full suite: CI runs them"]}
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
