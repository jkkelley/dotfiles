---
{
  "id": "WO-20261016-b9ba",
  "slug": "wk1-wiki-intake-wiki-src-captures-sources-into-r",
  "title": "WK1: wiki-intake WIKI= SRC= captures sources into raw by content hash, idempotent, blobs to the artifact store",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:18:51+00:00",
  "parent": "WO-20261016-35de",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-d304",
    "WO-20261016-96c4"
  ],
  "blocks": [
    "WO-20261016-712e",
    "WO-20261016-168d",
    "WO-20261016-6584",
    "WO-20261016-2013"
  ]
}
---

# WO-20261016-b9ba - WK1: wiki-intake WIKI= SRC= captures sources into raw by content hash, idempotent, blobs to the artifact store

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

Owner words, verbatim: "MAKE SURE A KNOWLEDGE BASE WIKI OF YIELDPOINT AI IS BUILT AND USING DOC DESIGN FIRST AND PUT THAT SHIT IN THE ~/PROJECTS/YIELDPOINT/WIKI/<ALL SUB DIRS HERE INTAKE|RAW|PROCESS|I'M JUST MAKING SHIT UP TO SHOW>"; "good never examples"; "get everything centrally located for this yieldpoint stuff, i have a directory already in ~/projects". Architect ruling BR-20261016-yp-wiki: the wiki is ~/projects/yieldpoint-ai/wiki. ORD-0556 O1: the engine is a generic, config-driven dotfiles tool at claude/tools/wiki/, called as `make -C ~/dotfiles wiki-<verb> WIKI=<root>`; the YieldPoint wiki holds only config and content. This replaces business tickets YW0-YW7 (cancelled, superseded). Line node: WO-20261016-35de - Line build L2 - yp-wiki and wiki-review. Brief: 'make wiki-intake SRC= (capture to raw by content hash, a second run adds nothing)'; 'raw blobs over 1 MB go to the artifact store and are linked, never committed'. Engine layout (fixed by design): claude/tools/wiki/wiki.mk (included from the dotfiles root Makefile; it includes claude/tools/wiki/mk/*.mk, one per verb), claude/tools/wiki/wikilib.py, claude/tools/wiki/wiki_<verb>.py, claude/tools/wiki/tests/test_<verb>.py, claude/tools/wiki/secret-patterns.json (default, overridable by <WIKI>/secret-patterns.json). Wiki root layout read from <WIKI>/wiki.json: intake_dir intake, raw_dir raw, processed_dir processed, index_dir index, blob_limit_bytes 1048576, max_page_lines 200, review_dir. Raw capture raw/<sha12>-<slug>.md: frontmatter source (~ for $HOME), captured_at UTC Z, sha256, bytes, blob (artifact store path, only over the limit). Processed page processed/<id>.md: frontmatter id, title, topic, sources (raw file names), updated; '# title'; '## Contents'; one '## <a id="anchor"></a>Heading' per section of <WIKI>/pages.json; every section links ../raw/<file> at least once. Orchestrator orders 2026-10-16 (MSG-20261016T061019Z-yp-design): ORD-0552 O2 'write each AC as command + expected exit code + expected output in the ticket text, and carry owner words verbatim and full context in Problem'; ORD-0555 O1 'before a ticket goes ready, list every tool, script, Make target and fixture its steps and AC checks call; any not on main gets a tooling ticket first'; ORD-0556 O1 'every tooling ticket builds a generic, config-driven tool in dotfiles'; ORD-0558 O1 'every design and ready ticket names the fallback for each tool and dependency it uses, the scripted switch with its status code, and a test case for the fallback path'.

## Scope

**In**

- claude/tools/wiki/wiki_intake.py ROOT SRC...: a directory recurses over *.md, *.xml, *.json sorted; sha256 each; target raw/<sha[:12]>-<slug(basename)>.md; a raw file already carrying that sha256 prints `WIKI-002 <path>` and writes nothing; else frontmatter source, captured_at, sha256, bytes and the text (WIKI-001); over blob_limit_bytes the bytes go to the path printed by `make -s -C ~/dotfiles artifact-new KEY=context NAME=wiki-<sha12> EXT=<ext>` (the command is <WIKI>/wiki.json artifact_new, so tests set a fake) and the raw file holds frontmatter with blob: and no body (WIKI-003)
- claude/tools/wiki/mk/intake.mk: `wiki-intake: ; python3 $(WIKI_DIR)wiki_intake.py $(WIKI) $(SRC)`, exit 2 when SRC is empty
- claude/tools/wiki/tests/test_intake.py: second run adds nothing; changed source adds one; 2 MB fixture goes to the fake artifact command; no body left in raw
- Tool: podman with a digest-pinned image (python image pinned above). Fallback: rerun with --pull=never on the locally cached image of the same digest. Switch: timed-run.sh --fallback ... --fallback-code FB-001 (status code FB-001; switch from WO-20261016-d304 - TR-FB: timed-run.sh --fallback CMD --fallback-code FB-NNN, the one scripted fallback switch, with the FB code catalog)
- Tool: make -C ~/dotfiles artifact-new (make artifact-new on main). Fallback: bash ~/dotfiles/claude/tools/artifact/artifact.sh new with the same KEY NAME EXT. Switch: timed-run.sh --fallback ... --fallback-code FB-004 (status code FB-004; switch from WO-20261016-d304 - TR-FB: timed-run.sh --fallback CMD --fallback-code FB-NNN, the one scripted fallback switch, with the FB code catalog)

**Out - non-goals**

- Any other verb
- Any wiki content

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `podman run --rm --network=none -v ~/dotfiles:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_intake.py` -> exit 0, output ends `OK`. Proof: command output
- [ ] `AC-H2` *(human)* `FORCE_FALLBACK=1 bash ~/dotfiles/claude/workflow/bin/timed-run.sh --node wk1 --fallback "podman run --rm --pull=never --network=none -v ~/dotfiles:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_intake.py" --fallback-code FB-001 -- podman run --rm --network=none -v ~/dotfiles:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_intake.py` -> exit 0, stderr contains `FALLBACK FB-001`. Proof: command output

## Test plan

```sh
podman run --rm --network=none -v ~/dotfiles:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_intake.py
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
