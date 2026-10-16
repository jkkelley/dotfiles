---
{
  "id": "WO-20261016-88d3",
  "slug": "rolodex-headers-with-no-file-drafts-exactly-the-",
  "title": "rolodex headers with no FILE drafts exactly the files check flags: same base, same file set",
  "type": "bug",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T07:22:04+00:00",
  "parent": "WO-20261016-0272",
  "branch": "feat/rolodex-headers-with-no-file-drafts-exactly-the-",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design3 cut for ORD-0715; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-6cff"
  ]
}
---

# WO-20261016-88d3 - rolodex headers with no FILE drafts exactly the files check flags: same base, same file set

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

ORD-0715 C3 (orchestrator brief BR-20261016-infra-design3): "fix ticket for the rolodex drafter: headers WRITE=1 with no FILE must draft exactly the files check would flag (same base and same file set), never others; test case included." Cause, scripts/rolodex.py on main: cmd_check (line 216) with no FILE and no --all takes `git diff --name-only --diff-filter=A <base>...HEAD` plus `git ls-files --others --exclude-standard`, filtered by skipped() and is_script(); cmd_headers (line 198) with no FILE takes header_roots_scripts() (line 185), every tracked script under the header_root dirs of config/rolodex.conf (scripts, tools, claude/tools, .github/scripts, workflows). So the fix hint check prints at line 231, 'make rolodex-headers WRITE=1', rewrites every old headerless script in those dirs, files the PR never touched, and misses a flagged new script outside them. Make: rolodex-headers (Makefile line 62) passes no --base; GNU make exports command-line variables to the recipe environment (verified in podman 2026-10-16: `make t BASE=origin/x` gives the recipe BASE=origin/x, unset without it), so reading env BASE makes `make rolodex-headers BASE=x WRITE=1` use the same base as `make rolodex-check BASE=x` without touching the root Makefile, which four ready tickets hold (item 19). Owner, item 22: "see a bug, isolate it, and get it fixed as asap".

## Scope

**In**

- touches: scripts/rolodex.py
- touches: tools/rolodex/tests/test_rolodex.sh
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-0272/README.md
- step: rolodex.py: new function `changed_scripts(root, base)` holding cmd_check's current no-FILE, no --all body (diff --diff-filter=A base...HEAD, plus ls-files --others --exclude-standard, filtered by skipped(), is_file() and is_script()), returned as a list; cmd_check's else branch calls it; behaviour of check unchanged
- step: rolodex.py cmd_headers: `files = a.files or (tracked_scripts(root) if a.all else changed_scripts(root, a.base))`; headers subparser gains `--all` (store_true) and `--base` with default `os.environ.get('BASE') or 'origin/main'`; check's --base default becomes the same expression so the two can never drift; usage line 15 becomes 'rolodex.py headers [--write] [--all] [--base REF] [--root DIR] [FILE...]'
- step: rolodex.py: delete header_roots_scripts() (no caller remains); breadcrumb comment above cmd_headers: what broke (headers drafted the header_root set, check flags the diff set, so the hint rewrote untouched files), why this fix (one function feeds both), rejected (keeping header_root as the default: it is the bug), cost (header_root lines in config/rolodex.conf are now unread; removal is held by WO-20261016-6cff - Rolodex points at the PR index: one pointer line, never the index itself, which holds that file)
- step: test_rolodex.sh, after the existing headers block: build $tmp/g, a git repo (git init -q -b main, user.email t@example.com, user.name t), commit scripts/old.sh headerless on main, `git checkout -q -b f`, commit scripts/new.sh headerless and bin/far.sh headerless (outside every header_root dir, so the old default missed it; both added on the branch), leave scripts/untracked.sh headerless untracked; snapshot old.sh; run `BASE=main python3 $R headers --root $tmp/g --write`; assert old.sh byte-identical (cmp), new.sh, far.sh and untracked.sh each pass `check --root $tmp/g --base main <file>`, and `python3 $R check --root $tmp/g --base main` exits 0; pass line 'headers WRITE with no FILE drafts exactly the files check flags'
- step: test_rolodex.sh: second case on a fresh copy of the same repo: `python3 $R headers --root <copy> --all` dry run lists exactly the files `check --root <copy> --all` names as lacking keys (compare the sorted '--- <file>' lines with the sorted 'rolodex-check: <file> lacks' file names); pass line 'headers --all drafts the same set check --all flags'
- step: run `make rolodex-test` and `make rolodex-check BASE=origin/main` (only these; CI runs the rest)
- tool: make:Makefile:rolodex-test - on main; fallback: target missing: stop with DESIGN-GAP naming it
- tool: make:Makefile:rolodex-check - on main; fallback: target missing: stop with DESIGN-GAP naming it
- tool: cmd:podman (rolodex-test runs in localhost/dotfiles-workflow-test:1, which has git and python3) - fallback: missing: stop with ENV-MISSING naming it

**Out - non-goals**

- the root Makefile: held by four ready tickets; env BASE carries the base instead
- config/rolodex.conf: held by WO-20261016-6cff - Rolodex points at the PR index: one pointer line, never the index itself
- work-orders/INDEX.md, the ticket file or the parent README by hand: work-order.sh writes them; their close-out diff is allowed
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make rolodex-test` exits 0 and its output matches /PASS: headers WRITE with no FILE drafts exactly the files check flags/ (proof: command, exit code and output pasted by work-order.sh evidence)
- [ ] `AC-H2` *(human)* `make rolodex-test` output matches /PASS: headers --all drafts the same set check --all flags/ and has no line matching /^FAIL/ (proof: command, exit code and output pasted by work-order.sh evidence)
- [ ] `AC-H3` *(human)* `make rolodex-check BASE=origin/main` exits 0 (proof: command, exit code and output pasted by work-order.sh evidence)
- [ ] `AC-H4` *(human)* `grep -c header_roots_scripts scripts/rolodex.py` prints 0 (proof: command and output pasted by work-order.sh evidence)
- [ ] `AC-H5` *(human)* `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/|scripts/rolodex\.py|tools/rolodex/tests/test_rolodex\.sh)$'` exits 1 and prints nothing

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

scripts/rolodex.py headers: the default file set with no FILE equals check's file set

**Cases**

- `TP-1`
  - intent: the fix hint "make rolodex-headers WRITE=1" must draft exactly the scripts check flagged, never rewrite old scripts in other files of the PR's repo
  - command: `make rolodex-test`
  - expected: exit 0; prints `PASS: headers WRITE with no FILE drafts exactly the files check flags`; old.sh (headerless, committed on base) is byte-identical after the run; new.sh (added on branch) and untracked.sh got headers; check --base then exits 0
- `TP-2`
  - intent: the existing drafting, check and build behaviour must not regress
  - command: `make rolodex-test`
  - expected: exit 0; the four existing PASS lines still print
- `TP-3`
  - intent: ALL=1 keeps a way to draft every tracked script, matching check --all
  - command: `make rolodex-test`
  - expected: exit 0; prints `PASS: headers --all drafts the same set check --all flags`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- rolodex-check.yml runs make rolodex-check on the PR

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
