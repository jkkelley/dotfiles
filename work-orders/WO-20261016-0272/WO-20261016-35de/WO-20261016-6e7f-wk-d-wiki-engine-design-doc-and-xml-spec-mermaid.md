---
{
  "id": "WO-20261016-6e7f",
  "slug": "wk-d-wiki-engine-design-doc-and-xml-spec-mermaid",
  "title": "WK-D: wiki engine design doc and XML spec - mermaid pipeline, status codes, GOOD/NEVER per rule",
  "type": "chore",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:18:30+00:00",
  "parent": "WO-20261016-35de",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-d304"
  ],
  "blocks": [
    "WO-20261016-7a8f",
    "WO-20261016-96c4"
  ]
}
---

# WO-20261016-6e7f - WK-D: wiki engine design doc and XML spec - mermaid pipeline, status codes, GOOD/NEVER per rule

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

Owner words, verbatim: "MAKE SURE A KNOWLEDGE BASE WIKI OF YIELDPOINT AI IS BUILT AND USING DOC DESIGN FIRST AND PUT THAT SHIT IN THE ~/PROJECTS/YIELDPOINT/WIKI/<ALL SUB DIRS HERE INTAKE|RAW|PROCESS|I'M JUST MAKING SHIT UP TO SHOW>"; "good never examples"; "get everything centrally located for this yieldpoint stuff, i have a directory already in ~/projects". Architect ruling BR-20261016-yp-wiki: the wiki is ~/projects/yieldpoint-ai/wiki. ORD-0556 O1: the engine is a generic, config-driven dotfiles tool at claude/tools/wiki/, called as `make -C ~/dotfiles wiki-<verb> WIKI=<root>`; the YieldPoint wiki holds only config and content. This replaces business tickets YW0-YW7 (cancelled, superseded). Line node: WO-20261016-35de - Line build L2 - yp-wiki and wiki-review. Doc design first: this ticket writes down the design fixed in the WK and YW tickets, adding nothing. Engine layout (fixed by design): claude/tools/wiki/wiki.mk (included from the dotfiles root Makefile; it includes claude/tools/wiki/mk/*.mk, one per verb), claude/tools/wiki/wikilib.py, claude/tools/wiki/wiki_<verb>.py, claude/tools/wiki/tests/test_<verb>.py, claude/tools/wiki/secret-patterns.json (default, overridable by <WIKI>/secret-patterns.json). Wiki root layout read from <WIKI>/wiki.json: intake_dir intake, raw_dir raw, processed_dir processed, index_dir index, blob_limit_bytes 1048576, max_page_lines 200, review_dir. Raw capture raw/<sha12>-<slug>.md: frontmatter source (~ for $HOME), captured_at UTC Z, sha256, bytes, blob (artifact store path, only over the limit). Processed page processed/<id>.md: frontmatter id, title, topic, sources (raw file names), updated; '# title'; '## Contents'; one '## <a id="anchor"></a>Heading' per section of <WIKI>/pages.json; every section links ../raw/<file> at least once. Orchestrator orders 2026-10-16 (MSG-20261016T061019Z-yp-design): ORD-0552 O2 'write each AC as command + expected exit code + expected output in the ticket text, and carry owner words verbatim and full context in Problem'; ORD-0555 O1 'before a ticket goes ready, list every tool, script, Make target and fixture its steps and AC checks call; any not on main gets a tooling ticket first'; ORD-0556 O1 'every tooling ticket builds a generic, config-driven tool in dotfiles'; ORD-0558 O1 'every design and ready ticket names the fallback for each tool and dependency it uses, the scripted switch with its status code, and a test case for the fallback path'.

## Scope

**In**

- docs/design/wiki.md: '## Contents', '## Design principles 101' (one line per principle 1 to 40), then Purpose, Inventory (reused: md-contents.sh, spec-check.sh, artifact.mk, golden-rules.sh, timed-run.sh; sources listed in YW-C), Layout, Pipeline, Page format, Verbs, Status codes, Fallbacks, Gates dev/UAT/stable, Migration; every rule with a GOOD and a NEVER line
- Pipeline mermaid: `graph LR; I[intake] --&gt; R[raw]; R --&gt; P[processed]; P --&gt; X[index]; P --&gt; V[review]; X --&gt; C[check]`
- Status codes: WIKI-000 ok; WIKI-001 captured; WIKI-002 already captured; WIKI-003 blob sent to the artifact store; WIKI-010 skeleton written; WIKI-011 page unchanged; WIKI-020 index written; WIKI-030 check failed; WIKI-031 no contents list; WIKI-032 broken link; WIKI-033 orphan raw; WIKI-034 uncited section; WIKI-035 page over size; WIKI-036 secret pattern; WIKI-037 TODO-WRITE left; WIKI-040 review page written; exits 0 ok, 2 usage, 3 check failed, 4 io
- docs/design/wiki.spec.xml: at most 1000 lines, first child <contents>, one element per verb with inputs, outputs, codes, idempotency and fallback
- Tool: scripts/spec-check.sh (on main). Fallback: none needed, the tool is a file on main read locally; a missing file stops the step with exit 4
- Tool: scripts/md-contents.sh (on main). Fallback: none needed, the tool is a file on main read locally; a missing file stops the step with exit 4

**Out - non-goals**

- Changing a decision fixed in the WK or YW tickets; a gap is a note with DESIGN-GAP
- Code

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `bash scripts/spec-check.sh docs/design/wiki.spec.xml` -> exit 0, output contains `ok`. Proof: command output
- [ ] `AC-H2` *(human)* `bash scripts/md-contents.sh check docs/design/wiki.md` -> exit 0. Proof: command output
- [ ] `AC-H3` *(human)* `grep -c '^## Design principles 101' docs/design/wiki.md` -> exit 0, output `1`. Proof: command output

## Test plan

```sh
bash scripts/spec-check.sh docs/design/wiki.spec.xml
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
