---
{
  "id": "WO-20261016-0b9c",
  "slug": "wk4-wiki-check-wiki-fails-on-missing-contents-br",
  "title": "WK4: wiki-check WIKI= fails on missing contents, broken links, orphans, uncited sections, size, secrets and TODO-WRITE",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:19:22+00:00",
  "parent": "WO-20261016-35de",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
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

- claude/tools/wiki/wiki_check.py ROOT over processed/*.md and index/README.md: WIKI-031 first H2 is not Contents; WIKI-032 relative link target file or #anchor missing; WIKI-033 raw file cited by no page; WIKI-034 section without a ../raw/ link; WIKI-035 page over max_page_lines; WIKI-036 a line in raw/ or processed/ matching secret_patterns(root); WIKI-037 TODO-WRITE left; one 'CODE path:line' per finding, exit 3 on any, else WIKI-000 exit 0
- claude/tools/wiki/mk/check.mk: `wiki-check: ; python3 $(WIKI_DIR)wiki_check.py $(WIKI)`
- claude/tools/wiki/tests/test_check.py: one fixture per code failing with exactly that code; one clean fixture passing
- Tool: podman with a digest-pinned image (python image pinned above). Fallback: rerun with --pull=never on the locally cached image of the same digest. Switch: timed-run.sh --fallback ... --fallback-code FB-001 (status code FB-001; switch from WO-20261016-d304 - TR-FB: timed-run.sh --fallback CMD --fallback-code FB-NNN, the one scripted fallback switch, with the FB code catalog)

**Out - non-goals**

- Any other verb
- Any wiki content

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `podman run --rm --network=none -v ~/dotfiles:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_check.py` -> exit 0, output ends `OK`. Proof: command output
- [ ] `AC-H2` *(human)* `FORCE_FALLBACK=1 bash ~/dotfiles/claude/workflow/bin/timed-run.sh --node wk4 --fallback "podman run --rm --pull=never --network=none -v ~/dotfiles:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_check.py" --fallback-code FB-001 -- podman run --rm --network=none -v ~/dotfiles:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_check.py` -> exit 0, stderr contains `FALLBACK FB-001`. Proof: command output

## Test plan

```sh
podman run --rm --network=none -v ~/dotfiles:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_check.py
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
