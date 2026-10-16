---
{
  "id": "WO-20261016-96c4",
  "slug": "wk0-wiki-engine-skeleton-wiki-mk-with-per-verb-i",
  "title": "WK0: wiki engine skeleton - wiki.mk with per-verb includes, wikilib.py, default secret patterns",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:18:41+00:00",
  "parent": "WO-20261016-35de",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
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

- claude/tools/wiki/wiki.mk: `WIKI ?=` (required by every verb, usage error exit 2 when empty), `WIKI_DIR := $(dir $(lastword $(MAKEFILE_LIST)))`, `include $(wildcard $(WIKI_DIR)mk/*.mk)`, target `wiki-test` running every tests/test_*.py in the python image
- Makefile (dotfiles root): one line `include claude/tools/wiki/wiki.mk` after the artifact include
- claude/tools/wiki/wikilib.py (stdlib only): utc_now() -> 'YYYY-MM-DDTHH:MM:SSZ'; sha256_file(path); slug(text) lowercase [a-z0-9-] max 40; read_frontmatter(path) -> (dict, body) and write_frontmatter(path, dict, body) for 'key: value' and 'key: [a, b]' lines; load_config(root) reading <root>/wiki.json with the defaults above; atomic_write(path, text) via tmp and os.replace; secret_patterns(root) merging the default file with <root>/secret-patterns.json
- claude/tools/wiki/secret-patterns.json: AKIA[0-9A-Z]{16}, ghp_[A-Za-z0-9]{36}, github_pat_[A-Za-z0-9_]{40,}, -----BEGIN [A-Z ]*PRIVATE KEY-----, xox[baprs]-[A-Za-z0-9-]+, sk-[A-Za-z0-9]{20,}
- claude/tools/wiki/tests/test_wikilib.py: one case per function; frontmatter round trip byte identical
- claude/tools/wiki/README.md: contents list, verbs, config keys, fallbacks
- Tool: podman with a digest-pinned image (python image pinned above). Fallback: rerun with --pull=never on the locally cached image of the same digest. Switch: timed-run.sh --fallback ... --fallback-code FB-001 (status code FB-001; switch from WO-20261016-d304 - TR-FB: timed-run.sh --fallback CMD --fallback-code FB-NNN, the one scripted fallback switch, with the FB code catalog)

**Out - non-goals**

- Any verb
- Any wiki content

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `podman run --rm --network=none -v ~/dotfiles:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_wikilib.py` -> exit 0, output ends `OK`. Proof: command output
- [ ] `AC-H2` *(human)* `FORCE_FALLBACK=1 bash ~/dotfiles/claude/workflow/bin/timed-run.sh --node wk0 --fallback "podman run --rm --pull=never --network=none -v ~/dotfiles:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_wikilib.py" --fallback-code FB-001 -- podman run --rm --network=none -v ~/dotfiles:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_wikilib.py` -> exit 0, stderr contains `FALLBACK FB-001`. Proof: command output
- [ ] `AC-H3` *(human)* `make -C ~/dotfiles help | grep -c wiki-test` -> exit 0, output `1`. Proof: command output

## Test plan

```sh
podman run --rm --network=none -v ~/dotfiles:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_wikilib.py
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
