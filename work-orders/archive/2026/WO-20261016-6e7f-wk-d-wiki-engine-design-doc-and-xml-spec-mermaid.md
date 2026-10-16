---
{
  "id": "WO-20261016-6e7f",
  "slug": "wk-d-wiki-engine-design-doc-and-xml-spec-mermaid",
  "title": "WK-D: wiki engine design doc and XML spec - mermaid pipeline, status codes, GOOD/NEVER per rule",
  "type": "chore",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:18:30+00:00",
  "parent": "WO-20261016-35de",
  "branch": "feat/wk-d-wiki-engine-design-doc-and-xml-spec-mermaid",
  "pr": 285,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design10 cut for ORD-0830 RR-orch-14 and ORD-0921; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-d304"
  ],
  "blocks": [
    "WO-20261016-7a8f",
    "WO-20261016-96c4"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash scripts/spec-check.sh docs/design/wiki.spec.xml",
      "exit": 0,
      "expect": "^ok"
    },
    {
      "index": 2,
      "command": "bash scripts/md-contents.sh check docs/design/wiki.md",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "grep -c '^## Design principles 101' docs/design/wiki.md",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 4,
      "command": "awk '/^## Design principles 101/{f=1;next} /^## /{f=0} f && /^[0-9]+\\. /' docs/design/wiki.md | wc -l",
      "exit": 0,
      "expect": "^40$"
    },
    {
      "index": 5,
      "command": "grep -oE 'WIKI-0[0-9]{2}' docs/design/wiki.spec.xml | sort -u | wc -l",
      "exit": 0,
      "expect": "^16$"
    },
    {
      "index": 6,
      "command": "grep -c '<fallback' docs/design/wiki.spec.xml",
      "exit": 0,
      "expect": "^([5-9]|[1-9][0-9]+)$"
    },
    {
      "index": 7,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|docs/design/wiki[.]md|docs/design/wiki[.]spec[.]xml)$'",
      "exit": 1,
      "expect": null
    }
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

- touches: docs/design/wiki.md (new) and docs/design/wiki.spec.xml (new); nothing else
- touches (generated, written only by work-order.sh start/submit/evidence/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- docs/design/wiki.md: '## Contents', '## Design principles 101' (one line per principle 1 to 40), then Purpose, Inventory (reused: md-contents.sh, spec-check.sh, artifact.mk, golden-rules.sh, timed-run.sh; sources listed in YW-C), Layout, Pipeline, Page format, Verbs, Status codes, Fallbacks, Gates dev/UAT/stable, Migration; every rule with a GOOD and a NEVER line
- Pipeline mermaid: `graph LR; I[intake] --&gt; R[raw]; R --&gt; P[processed]; P --&gt; X[index]; P --&gt; V[review]; X --&gt; C[check]`
- Status codes: WIKI-000 ok; WIKI-001 captured; WIKI-002 already captured; WIKI-003 blob sent to the artifact store; WIKI-010 skeleton written; WIKI-011 page unchanged; WIKI-020 index written; WIKI-030 check failed; WIKI-031 no contents list; WIKI-032 broken link; WIKI-033 orphan raw; WIKI-034 uncited section; WIKI-035 page over size; WIKI-036 secret pattern; WIKI-037 TODO-WRITE left; WIKI-040 review page written; exits 0 ok, 2 usage, 3 check failed, 4 io
- docs/design/wiki.spec.xml: at most 1000 lines, first child <contents>, one element per verb with inputs, outputs, codes, idempotency and fallback
- Tool: scripts/spec-check.sh (on main). Fallback: none needed, the tool is a file on main read locally; a missing file stops the step with exit 4
- Tool: scripts/md-contents.sh (on main). Fallback: none needed, the tool is a file on main read locally; a missing file stops the step with exit 4
- step: branch from origin/main in your own worktree; write the two files exactly as the bullets above fix them, taking every decision from this Problem and the WK and YW tickets under WO-20261016-35de; nothing invented: a missing fact is DESIGN-GAP
- step: run bash scripts/md-contents.sh write docs/design/wiki.md, then the AC checks only; commit 'docs(design): wiki engine design doc and XML spec (WO-20261016-6e7f)'; no Bump trailer
- tool: cmd:git, cmd:gh - fallback: missing on the host: stop with ENV-MISSING; GitHub down: retry 3 times, then stop with A2A-003 and its output
- spec element names, fixed: <contents> first, then one <verb name="intake|process|index|review|check"> each holding <inputs>, <outputs>, <codes>, <idempotency> and <fallback> children (AC-H6 counts <fallback)

**Out - non-goals**

- Changing a decision fixed in the WK or YW tickets; a gap is a note with DESIGN-GAP
- Code

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the spec is 1000 lines or less, parses and opens with contents
  - observed `2026-10-16` check: bash scripts/spec-check.sh docs/design/wiki.spec.xml exit 0 output: ok docs/design/wiki.spec.xml (145 lines)
  - check: `bash scripts/spec-check.sh docs/design/wiki.spec.xml` exit 0 expect /^ok/
- [x] `AC-H2` *(human)* the design opens with a contents list
  - observed `2026-10-16` check: bash scripts/md-contents.sh check docs/design/wiki.md exit 0 output: npm notice npm notice New major version of npm available! 10.9.9 -> 12.2.0 npm notice Changelog: https://github.com/npm/cli/releases/tag/v12.2.0 npm notice To update run: npm install -g npm@12.2.0 npm notice md-contents: 1 file(s) ok
  - check: `bash scripts/md-contents.sh check docs/design/wiki.md` exit 0
- [x] `AC-H3` *(human)* Design principles 101 sits in the design once
  - observed `2026-10-16` check: grep -c '^## Design principles 101' docs/design/wiki.md exit 0 output: 1
  - check: `grep -c '^## Design principles 101' docs/design/wiki.md` exit 0 expect /^1$/
- [x] `AC-H4` *(human)* one line per principle 1 to 40
  - observed `2026-10-16` check: awk '/^## Design principles 101/{f=1;next} /^## /{f=0} f && /^[0-9]+. /' docs/design/wiki.md | wc -l exit 0 output: 40
  - check: `awk '/^## Design principles 101/{f=1;next} /^## /{f=0} f && /^[0-9]+\. /' docs/design/wiki.md | wc -l` exit 0 expect /^40$/
- [x] `AC-H5` *(human)* the 16 fixed status codes WIKI-000 to WIKI-040 are in the spec
  - observed `2026-10-16` check: grep -oE 'WIKI-0[0-9]{2}' docs/design/wiki.spec.xml | sort -u | wc -l exit 0 output: 16
  - check: `grep -oE 'WIKI-0[0-9]{2}' docs/design/wiki.spec.xml | sort -u | wc -l` exit 0 expect /^16$/
- [x] `AC-H6` *(human)* every verb names its fallback
  - observed `2026-10-16` check: grep -c '<fallback' docs/design/wiki.spec.xml exit 0 output: 10
  - check: `grep -c '<fallback' docs/design/wiki.spec.xml` exit 0 expect /^([5-9]|[1-9][0-9]+)$/
- [x] `AC-H7` *(human)* the diff holds only the two design files and work-orders files
  - observed `2026-10-16` check: git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|docs/design/wiki[.]md|docs/design/wiki[.]spec[.]xml)$' exit 1 output:
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|docs/design/wiki[.]md|docs/design/wiki[.]spec[.]xml)$'` exit 1

## Test plan

{"scope":"the wiki engine design doc and XML spec","cases":[
{"id":"TP-1","intent":"a spec over 1000 lines, unparsed or without a first <contents> child breaks item 28","command":"bash scripts/spec-check.sh docs/design/wiki.spec.xml","expected":"exit 0; ok line"},
{"id":"TP-2","intent":"a design without a contents list breaks the owner Markdown rule","command":"bash scripts/md-contents.sh check docs/design/wiki.md","expected":"exit 0"},
{"id":"TP-3","intent":"Design principles 101 right below the contents list, one line per principle 1 to 40","command":"awk '/^## Design principles 101/{f=1;next} /^## /{f=0} f && /^[0-9]+\\. /' docs/design/wiki.md | wc -l","expected":"exit 0; 40"},
{"id":"TP-4","intent":"every fixed status code is carried by the spec","command":"grep -oE 'WIKI-0[0-9]{2}' docs/design/wiki.spec.xml | sort -u | wc -l","expected":"exit 0; 16"},
{"id":"TP-5","intent":"fallback path: every verb names its fallback (ORD-0558 O1)","command":"grep -c '<fallback' docs/design/wiki.spec.xml","expected":"exit 0; 5 or more"}],
"isolation":{"runtime":"podman","image":"docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd"},
"out_of_scope":["engine code: WK0 to WK5","lint and the full suite: CI"]}

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` DRAFT until tool WO-20261016-d304 - TR-FB (timed-run.sh --fallback) is on main (ORD-0555 O1); then approve --no-lavish --reason "architect ruled design approvals done, ORD-0550 O4"

## Outcome

_Written by `work-order done`. Empty until then._
