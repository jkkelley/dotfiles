---
{
  "id": "WO-20261016-318d",
  "slug": "work-order-sh-approve-check-evidence-and-done-co",
  "title": "work-order.sh approve, check, evidence and done --code-dir run in a detached worktree of the code repo at freshly fetched origin/main or the ticket's open code PR head, never the checkout's HEAD or working tree",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T12:06:32+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design20 recut of ef1b for its DESIGN-GAP (370, 420); design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-1099"
  ],
  "blocks": [
    "WO-20261016-3d4d"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "450-code-dir-worktree"
    },
    {
      "index": 2,
      "command": "grep -c 'cd \"${CODE_TREE:-$project}\"' claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 3,
      "command": "grep -c '^code_tree()' claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 4,
      "command": "grep -c -F -- '[--code-dir DIR [--code-ref REF]]' claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^4$"
    },
    {
      "index": 5,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 6,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "all cases passed"
    },
    {
      "index": 7,
      "command": "grep -c 'config --get remote.origin.url' claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 8,
      "command": "grep -nE 'remote set-url origin [^ ]*github' claude/skills/work-order/testing/cases/370-approve-code-dir.sh claude/skills/work-order/testing/cases/420-code-dir-checks.sh claude/skills/work-order/testing/cases/450-code-dir-worktree.sh",
      "exit": 1,
      "expect": null
    },
    {
      "index": 9,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\\.sh|testing/SOP\\.md|testing/assert\\.sh|testing/cases/(370-approve-code-dir|420-code-dir-checks|450-code-dir-worktree)\\.sh))$'",
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

# WO-20261016-318d - work-order.sh approve, check, evidence and done --code-dir run in a detached worktree of the code repo at freshly fetched origin/main or the ticket's open code PR head, never the checkout's HEAD or working tree

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

After WO-20261016-e297 and WO-20261016-1099 a cross-repo ticket's approve, check and done read the --code-dir checkout as it stands: whatever HEAD, branch and uncommitted files the seat left there, possibly behind origin. A stale copy passes approve for tools not on main (the WO-20261016-1b46 finding), and a seat running done from the wrong tree is how WO-20261016-64f2 failed (F44, seats/lineops-img.result.json: AC-FAIL 1-3 in dotfiles while the same checks pass in gitops-builder). evidence takes no --code-dir at all, so a cross-repo ticket's evidence names no commit. ORD-1114 C1: code_repo applies to every verb that resolves tools or runs AC checks.

## Owner words

> WO-20261016-ef1b - work-order.sh approve, check, evidence and done --code-dir run in a detached worktree of the code repo at freshly fetched origin/main: code_tree must die on fetch failure, but existing cases 370-approve-code-dir.sh and 420-code-dir-checks.sh run --network=none against fake github origins, so they fail and AC6 forbids editing them. Add 370 and 420 to In with a local bare-repo origin fixture. (orchestrator brief BR-20261016-infra-design20)

> code_repo applies to every verb that resolves tools or runs AC checks (approve, check, evidence, done), which cd into a worktree of code_repo origin/main or the ticket branch there (ORD-1114 C1, orchestrator brief BR-20261016-infra-design18)

> design seat infra-design: ORD-1114 code_repo for every verb (reconcile 1b46 with e297 and 1099), stranded close-outs 9fc7 and 168d, DESIGN-GAP 168e test plan, F44 close-outs; keep the 6-leaf buffer (orchestrator brief BR-20261016-infra-design18)

> worktrees and feature branches with the whole process DAG when getting work so it follows a deterministic path (Design principles 101 item 20)

## Context

Order brief BR-20261016-infra-design18, ORD-1114 C1. Reconciliation: WO-20261016-e297 (approve --code-dir, being built by seat wo-e297 since 11:20Z) and WO-20261016-1099 (check and done --code-dir) stay as cut; this ticket follows them on work-order.sh and supersedes WO-20261016-1b46, which this design PR cancels, carrying its ruling: approve resolves tools on DIR's freshly fetched origin/main only. code_repo is the ticket's existing .repo field (WO-20261016-f57d, PR 295); .repo null means every verb behaves exactly as today and nothing is fetched. Edit 1, new function code_tree in claude/skills/work-order/scripts/work-order.sh directly above run_checks: code_tree <file> <mode>, mode main or pr. It runs the --code-dir guard 1099 adds (code_dir_required, code_dir_mismatch), moved into code_tree so all four verbs share it. Fetch: git -C "$code_dir" fetch -q origin, 3 tries 5 s apart; all fail: ps_die "$PS_IO" code_fetch_failed '<repo>: git fetch origin failed 3 times'. Ref: --code-ref REF when given (git -C "$code_dir" rev-parse --verify REF fails: ps_die "$PS_VALIDATION" code_ref_unknown); else mode main: origin/main; mode pr with .pr non-null: ${GH:-gh} pr view <pr> -R <repo> --json state,headRefName, 3 tries, OPEN gives origin/<headRefName>, MERGED or CLOSED gives origin/main, all tries fail: ps_die "$PS_IO" code_pr_lookup_failed; mode pr with .pr null: origin/main. Worktree: d=$(mktemp -d "${TMPDIR:-/tmp}/wo-code.XXXXXX"); git -C "$code_dir" worktree add -q --detach "$d" "$ref"; an EXIT trap runs git -C "$code_dir" worktree remove --force "$d" then rm -rf "$d"; sets CODE_TREE=$d and CODE_SHA=$(git -C "$d" rev-parse HEAD). Edit 2, run_checks: the line 1099 writes, 'cd "${code_dir:-$project}"', becomes 'cd "${CODE_TREE:-$project}"'. Edit 3, cmd_approve: when .repo is non-null and --code-dir is given, call code_tree "$file" main and resolve tools against $CODE_TREE (replacing e297's read of DIR as it stands). Edit 4, cmd_check and cmd_done: call code_tree "$file" pr before run_checks when .repo is non-null. Edit 5, cmd_evidence: accepts --code-dir and --code-ref (the same variables); when .repo is non-null and --code-dir is empty: the same code_dir_required refusal; with it, code_tree "$file" pr and the recorded observed text is '<observed> (at <repo>@<first 12 hex of CODE_SHA>)'. Edit 6, flag parsing: --code-ref REF next to --code-dir; usage lines of approve, check, evidence and done each end with '[--code-dir DIR [--code-ref REF]]'. Edit 7, breadcrumb comment above code_tree: what broke (64f2 F44 done in the wrong tree; 1b46 approve on an old copy), why a detached worktree (never moves the seat's branch, a dirty seat tree cannot leak into a check), the rejected alternatives (git -C DIR checkout: moves the seat's branch and fails on a dirty tree; DIR as it stands: an old copy passes), the cost (one fetch and one worktree per call, about a second). Edit 8, new claude/skills/work-order/testing/cases/450-code-dir-worktree.sh (440 is taken twice): fixture: a bare repo code.git with main (no file marker) and branch feat/x (adds marker); DIR is a clone of it whose working tree also holds an untracked marker; ticket .repo is <owner>/code (any owner, origin url ends code.git) with one ac_check 'test -f marker' exit 0. Cases: (a) .pr null, check --code-dir DIR: AC-FAIL 1, proving DIR's working tree is not read; (b) --code-ref origin/feat/x: AC-PASS 1; (c) .pr 7 and GH pointing at a fake gh printing {"state":"OPEN","headRefName":"feat/x"}: AC-PASS 1; the fake printing MERGED: AC-FAIL 1; (d) DIR's origin url set to a removed path that still ends code.git: exit with code_fetch_failed; (e) after every call git -C DIR worktree list prints exactly one line; (f) evidence on the repo ticket without --code-dir: code_dir_required; with --code-dir DIR --code-ref origin/feat/x: the ticket body holds '(at <owner>/code@' followed by 12 hex; (g) a ticket with .repo null: check passes as before with no origin configured. Edit 9, claude/skills/work-order/testing/SOP.md: one entry for 450, same shape as its neighbours. Recut by infra-design20 (BR-20261016-infra-design20) from WO-20261016-ef1b, DESIGN-GAP: code_tree must die on fetch failure (code_fetch_failed), but the existing cases 370-approve-code-dir.sh and 420-code-dir-checks.sh set the code checkout's origin to git@github.com:acme/code.git and https://github.com/acme/code(.git) so the repo guard matches, and the suite runs --network=none, so the fetch fails and both cases go red; ef1b AC6 forbade editing them. Three edits are added; Edits 1-9 above stand unchanged. Edit 10, code_repo_slug in claude/skills/work-order/scripts/work-order.sh (about line 1093): read the configured url with git -C "$1" config --get remote.origin.url instead of git -C "$1" remote get-url origin. Why: get-url applies url.<base>.insteadOf rewriting, so a fixture that redirects the github url to a local bare repo would also change the slug the guard compares; the configured url is the repo the checkout declares. Rejected: a WO_FETCH_URL test-only override in code_tree (a test seam in production code). Breadcrumb comment above the function says so. Edit 11, claude/skills/work-order/testing/assert.sh: new helper fake_origin <dir> <url>, placed directly below git_project: git -C "$dir" remote set-url origin "$url" then git -C "$dir" config --add url."${dir}.git".insteadOf "$url" (the bare repo git_project made beside the dir). Fetch then reads the local bare repo while the configured url still names the github repo. One comment line: what it is for (370, 420, 450 under --network=none). Edit 12, cases 370-approve-code-dir.sh and 420-code-dir-checks.sh: every git -C <dir> remote set-url origin <github url> line becomes fake_origin <dir> <same url> (370 lines 24, 25, 49, 53; 420 lines 22, 23). No assertion, message or other line changes. 450 uses fake_origin for its github-shaped origin as well.

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (code_tree, run_checks cd line, cmd_approve, cmd_check, cmd_done, cmd_evidence, flag parsing, usage lines, breadcrumb, code_repo_slug reads the configured url)
- touches: claude/skills/work-order/testing/cases/450-code-dir-worktree.sh (new)
- touches: claude/skills/work-order/testing/SOP.md (one entry for 450)
- touches: claude/skills/work-order/testing/assert.sh (fake_origin helper below git_project)
- touches: claude/skills/work-order/testing/cases/370-approve-code-dir.sh (remote set-url lines 24, 25, 49, 53 become fake_origin)
- touches: claude/skills/work-order/testing/cases/420-code-dir-checks.sh (remote set-url lines 22, 23 become fake_origin)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: after WO-20261016-1099 merged, branch from origin/main in your own git worktree (git worktree add; fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone
- step: make exactly the twelve edits in Context
- step: run the AC checks only; CI runs lint and the full suite
- step: commit 'feat(work-order): every code_repo verb runs in a worktree of the code repo origin' with the ticket id; the PR body ends with 'Bump: work-order=minor'
- tool: script:claude/skills/work-order/testing/run-tests.sh - on main; fallback: missing: stop with DESIGN-GAP naming it; its image fails to build: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- approve, check and done --code-dir flag parsing and the code_dir_required and code_dir_mismatch guards themselves: WO-20261016-e297 and WO-20261016-1099 ship them; this ticket only moves the guard into code_tree
- docs (SKILL.md, references): WO-20261016-2eb1 documents the final flags
- closing any F44-stranded ticket: the F44 close-out ticket runs them
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* every code_repo verb runs in a worktree of the code repo origin, never the checkout as it stands
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /450-code-dir-worktree/
- [ ] `AC-H2` *(human)* run_checks cds into the code worktree
  - check: `grep -c 'cd "${CODE_TREE:-$project}"' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^1$/
- [ ] `AC-H3` *(human)* one code_tree function serves every verb
  - check: `grep -c '^code_tree()' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^1$/
- [ ] `AC-H4` *(human)* the four verbs' usage lines name --code-dir and --code-ref
  - check: `grep -c -F -- '[--code-dir DIR [--code-ref REF]]' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^4$/
- [ ] `AC-H5` *(human)* rolodex pointers hold
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H6` *(human)* the whole work-order suite passes, 370 and 420 included, under --network=none
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /all cases passed/
- [ ] `AC-H7` *(human)* code_repo_slug reads the configured origin url, not the insteadOf-rewritten one
  - check: `grep -c 'config --get remote.origin.url' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^1$/
- [ ] `AC-H8` *(human)* no case points a code checkout at a github url without the local bare-repo redirect
  - check: `grep -nE 'remote set-url origin [^ ]*github' claude/skills/work-order/testing/cases/370-approve-code-dir.sh claude/skills/work-order/testing/cases/420-code-dir-checks.sh claude/skills/work-order/testing/cases/450-code-dir-worktree.sh` exit 1
- [ ] `AC-H9` *(human)* the diff holds only the In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\.sh|testing/SOP\.md|testing/assert\.sh|testing/cases/(370-approve-code-dir|420-code-dir-checks|450-code-dir-worktree)\.sh))$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

work-order.sh code_tree and the four verbs that use it (approve, check, evidence, done) for a ticket with .repo set

**Cases**

- `TP-1`
  - intent: a cross-repo check, evidence or done that reads the seat checkout instead of the code repo origin closes tickets on code nobody merged or refuses good work (F44)
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0; 370-approve-code-dir, 420-code-dir-checks and 450-code-dir-worktree listed and the last line reads all cases passed

**Isolation**

- runtime: podman
- image: `localhost/work-order-test:1`
- build: `podman build -t localhost/work-order-test:1 -f claude/skills/work-order/testing/Containerfile claude/skills/work-order/testing`
- containerfile: claude/skills/work-order/testing/Containerfile

**Out of scope - CI covers**

- lint and the full suite: CI runs them (Design principles 101 item 6)

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
