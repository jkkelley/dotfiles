---
{
  "id": "WO-20261016-fb99",
  "slug": "pr-flow-sweep-verb-autofix-red-prs-with-a-tracke",
  "title": "pr-flow sweep verb autofix: red PRs with a tracked-ignored path or a stale contents list get the mechanical fix pushed, post AUTOFIX, make pr-autofix",
  "type": "feature",
  "status": "in-review",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:28:38+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": "feat/pr-flow-sweep-verb-autofix-red-prs-with-a-tracke",
  "pr": 270,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design6 cut for ORD-0814 P1 P2; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-5082",
    "WO-20261016-b211"
  ],
  "blocks": [
    "WO-20261016-acbe"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow pr-flow-test CASES=\"autofix consume regen-index rerun-stale-red records\"",
      "exit": 0,
      "expect": "ok  autofix"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow pr-flow-lint",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "make -C claude/workflow pr-autofix",
      "exit": 2,
      "expect": "pr-autofix needs REPO="
    },
    {
      "index": 4,
      "command": "jq -r .defaults.autofix.mode claude/workflow/pr-flow/config/pr-flow.json",
      "exit": 0,
      "expect": "^on$"
    },
    {
      "index": 5,
      "command": "bash -c python3\\ -c\\ \\'import\\ xml.dom.minidom\\,sys\\;\\ xml.dom.minidom.parse\\(sys.argv\\[1\\]\\)\\'\\ claude/workflow/docs/pr-process/pr-process.spec.xml\\ \\&\\&\\ grep\\ -c\\ \\'value=\\\"AUTOFIX\\\"\\'\\ claude/workflow/docs/pr-process/pr-process.spec.xml",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 6,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 7,
      "command": "bash -c \\!\\ git\\ diff\\ --name-only\\ origin/main...HEAD\\ \\|\\ grep\\ -vE\\ \\'\\^\\(work-orders/\\|claude/workflow/\\(pr-flow/\\(bin/pr-flow-consume\\\\.sh\\|pr-flow\\\\.mk\\|config/pr-flow\\\\.json\\|schemas/pr-flow-record\\\\.schema\\\\.json\\|tests/\\(autofix\\|records\\)\\\\.test\\\\.sh\\)\\|docs/pr-process/pr-process\\\\.\\(md\\|spec\\\\.xml\\)\\)\\)\\$\\'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [
    "make:pr-autofix"
  ]
}
---

# WO-20261016-fb99 - pr-flow sweep verb autofix: red PRs with a tracked-ignored path or a stale contents list get the mechanical fix pushed, post AUTOFIX, make pr-autofix

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

PRs red only on a mechanical fix wait for a seat. The sweep fixes them itself in one tick and posts AUTOFIX; content failures stay with the 422 lane and a fix seat.

## Owner words

> ORD-0814 P2: "merge-loop autofix verb for the mechanical ones: md-contents regenerate, tracked-ignored git rm --cached, commit and push to the PR branch, code AUTOFIX on the bus. Headers and Bump lines need content, so those go to a fix seat."

## Context

Evidence 2026-10-16 08:00-08:15Z: PRs 216, 219, 225, 234 red on headers or tracked-ignored-check; 213, 219, 210 red on bump intent. Each red costs a CI round and a seat; every one of those gates is local and fast.

Reference for the tracked-ignored half: the orchestrator stopgap /tmp/claude-1000/-home-luna-dotfiles/9be9946b-561d-4ae7-837e-a28f8c0aa220/scratchpad/drop-views.sh (worktree of the PR head, merge main, git rm --cached every tracked-ignored path, commit, push).

Inventory: pr-flow-consume.sh repo_pass lists open PRs, reads each head check-runs and posts ci.failed 422 once per head; regen_index shows the verb pattern (records.sh seen and post, a once-per-head key, a Make target through step-time.sh). WO-20261016-5082 - pr-flow sweep verb rerun-stale-red is ready and touches pr-flow-consume.sh, pr-flow.mk, pr-flow.json, the record schema, records.test.sh and both pr-process docs, so this ticket depends on it. Check names do not isolate the cause: CI job headers runs rolodex-check and tracked-ignored-check; job markdown contents lists runs md-contents-check, golden-rules-check, spec-check and design-drift. So the verb triggers on those job names and then detects locally in a temp worktree of the PR head: each fix declares a detect command (non-zero means a fix is needed) and a fix command; nothing detected means the failure needs content (headers, Bump lines).

pr-flow.json defaults.autofix, exactly: {"mode": "on", "on_checks": "^(headers|markdown contents lists)$", "fixes": [{"name": "tracked-ignored", "detect": "test -z \"$(git ls-files -ci --exclude-standard)\"", "fix": "git ls-files -ci -z --exclude-standard | xargs -0r git rm --cached -q"}, {"name": "md-contents", "detect": "BASE=origin/$PR_BASE bash \"$DOTFILES/scripts/md-contents.sh\" check", "fix": "BASE=origin/$PR_BASE bash \"$DOTFILES/scripts/md-contents.sh\" write"}]}

pr-process.md section 9 row, exactly, after the RERUN row: | AUTOFIX | `ci.autofix` | a red PR on headers or markdown contents lists with a tracked-ignored path or a stale contents list; untracked or regenerated, committed, pushed; once per head | nobody; CI runs on the new head |. pr-process.spec.xml codes, after the RERUN code: <code value="AUTOFIX" kind="ci.autofix" acts="none; CI runs on the new head"/>

## Scope

**In**

- touches: claude/workflow/pr-flow/bin/pr-flow-consume.sh
- touches: claude/workflow/pr-flow/pr-flow.mk
- touches: claude/workflow/pr-flow/config/pr-flow.json
- touches: claude/workflow/pr-flow/schemas/pr-flow-record.schema.json
- touches: claude/workflow/pr-flow/tests/autofix.test.sh (new)
- touches: claude/workflow/pr-flow/tests/records.test.sh
- touches: claude/workflow/docs/pr-process/pr-process.md
- touches: claude/workflow/docs/pr-process/pr-process.spec.xml
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-ebe4/README.md
- step: start only after WO-20261016-5082 is done and merged; branch from origin/main
- step: pr-flow-record.schema.json: append "ci.autofix" to properties.kind.enum and "AUTOFIX" to properties.code.enum; nothing else
- step: pr-flow.json: add defaults.autofix exactly as in Context, and extend defaults.$comment by one clause: autofix.mode on or off; a red PR whose failed check names match on_checks gets each fix whose detect exits non-zero, run in a temp worktree of its head, committed and pushed once per head. No per-repo override
- step: pr-flow-consume.sh: the open-PR list adds headRefName and isCrossRepository to its --json fields (5082 adds baseRefName). New function autofix_pr SLUG LINE N HEAD HEADREF BASEREF FORK TICKET FAILED CFG CLONE: return 0 when autofix.mode is not on, when no name in FAILED (comma list) matches on_checks, when records.sh seen --key AUTOFIX/SLUG/N/HEAD, or when the marker STATE/autofix-none/<SLUG with / as _>-N-HEAD exists. FORK true: print "SLUG PR N autofix-skip fork" and return 0. Else W=STATE/autofix/<SLUG with / as _>-N; git -C CLONE worktree remove --force W (errors ignored); git -C CLONE fetch -q origin HEADREF BASEREF; git -C CLONE worktree add -q --detach W origin/HEADREF; for each fix in config order run detect with cwd W and env PR_BASE=BASEREF and DOTFILES=<dotfiles root, four levels up from bin>; on non-zero run its fix the same way and keep its name; then git -C W add -u. Nothing staged: create the autofix-none marker and print "SLUG PR N autofix-none: needs content (fix seat)". Staged: git -C W commit -q -m "chore: pr-flow autofix <names joined by +> (AUTOFIX)" then git -C W push -q origin HEAD:HEADREF; a failed push prints "SLUG PR N autofix-fail push" and posts nothing; success prints "SLUG PR N autofix: <names>" and posts kind ci.autofix code AUTOFIX key AUTOFIX/SLUG/N/HEAD with note "fixed: <names>". Always git -C CLONE worktree remove --force W at the end (item 11)
- step: pr-flow-consume.sh repo_pass: in the failed branch, after the 422 post and before continue, call autofix_pr with the PR fields, the failed list, cfg and clone. New verb autofix in the case statement: for each slug in REPO or pr-flow-config.sh --list, for each open PR (only PR when set) read check-runs as repo_pass does and call autofix_pr for each red one. The header inputs line gains autofix
- step: pr-flow.mk: add pr-autofix to .PHONY and the target "pr-autofix: ## make pr-autofix REPO=owner/name [PR=N]: the sweep autofix verb for one repository, posts AUTOFIX", recipe line 1 the guard test -n "$(REPO)" or echo "pr-autofix needs REPO=" and exit 2, line 2 $(PF_TIME) --node autofix --budget 60 --timeout 240 --retries 1 -- env REPO=$(REPO) PR=$(PR) $(PF)/pr-flow-consume.sh autofix; add autofix to the default CASES list of pr-flow-test
- step: tests/autofix.test.sh (new; rolodex header; the consume.test.sh and regen-index.test.sh pattern): mktemp W, a real fixture clone with a bare origin, a fake gh answering pr list (with headRefName, baseRefName, isCrossRepository) and check-runs from fixture files, a stub publisher PR_FLOW_PUB, and DOTFILES pointing at a fixture scripts/md-contents.sh whose check exits 1 while a marker file exists and whose write removes the marker and edits a tracked .md; cases exactly TP-1 to TP-4 of the test plan; the last line in the pass=N fail=M shape the pr-flow-test target greps
- step: tests/records.test.sh: two cases: post --kind ci.autofix --code AUTOFIX exits 0; post --kind ci.autofix --code NOPE exits 3
- step: pr-process.md and pr-process.spec.xml: the row and the code in Context; pr-process.md section 10 gains one sentence on autofix.mode, on_checks and fixes
- step: run only TP-1 to TP-7 and the AC checks; CI runs the rest
- tool: path:scripts/md-contents.sh check and write - on main, honours BASE; fallback: npx missing on the sweep host: the md-contents fix fails, the commit carries only tracked-ignored, the 422 lane keeps the rest
- tool: path:claude/workflow/pr-flow/bin/records.sh seen and post - on main; fallback: bus down: the records.sh dir backend (records: dir in pr-flow.json, item 28 file queue), no code change
- tool: path:claude/workflow/bin/step-time.sh - on main; fallback: missing: stop with DESIGN-GAP, never an untimed target
- tool: rerun-stale-red verb and the baseRefName field - land with WO-20261016-5082; fallback: missing on main: stop with DESIGN-GAP naming WO-20261016-5082
- tool: make:claude/workflow/Makefile:pr-flow-test and pr-flow-lint - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:gh - fallback: gh or GitHub down: the pass logs io and retries next tick; a refused push prints autofix-fail push and the 422 record stands for the worker
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it

**Out - non-goals**

- headers (rolodex) and Bump lines: they need content; they stay with the 422 lane and a fix seat
- merging main into the PR: regen-index and rerun-stale-red own that
- fork PRs: skipped, the sweep cannot push to a fork
- consume.test.sh, regen-conflicts.sh, merge.sh, gate.sh: unchanged
- waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* autofix and every sweep case beside it pass
  - observed `2026-10-16` check: make -C claude/workflow pr-flow-test CASES="autofix consume regen-index rerun-stale-red records" exit 0 output: make: Entering directory '/home/luna/.cache/wt-pr-autofix/claude/workflow' ok image: localhost/dotfiles-workflow-test:1 ok autofix ok consume ok regen-index ok rerun-stale-red ok records make: Leaving directory '/home/luna/.cache/wt-pr-autofix/claude/workflow'
  - check: `make -C claude/workflow pr-flow-test CASES="autofix consume regen-index rerun-stale-red records"` exit 0 expect /ok autofix/
- [x] `AC-H2` *(human)* pr-flow scripts stay shellcheck clean
  - observed `2026-10-16` check: make -C claude/workflow pr-flow-lint exit 0 output: make: Entering directory '/home/luna/.cache/wt-pr-autofix/claude/workflow' ok image: localhost/dotfiles-workflow-test:1 make: Leaving directory '/home/luna/.cache/wt-pr-autofix/claude/workflow'
  - check: `make -C claude/workflow pr-flow-lint` exit 0
- [x] `AC-H3` *(human)* the target refuses without REPO
  - observed `2026-10-16` check: make -C claude/workflow pr-autofix exit 2 output: make: Entering directory '/home/luna/.cache/wt-pr-autofix/claude/workflow' pr-autofix needs REPO= make: *** [pr-flow/pr-flow.mk:48: pr-autofix] Error 2 make: Leaving directory '/home/luna/.cache/wt-pr-autofix/claude/workflow'
  - check: `make -C claude/workflow pr-autofix` exit 2 expect /pr-autofix needs REPO=/
- [x] `AC-H4` *(human)* autofix is on by default in config
  - observed `2026-10-16` check: jq -r .defaults.autofix.mode claude/workflow/pr-flow/config/pr-flow.json exit 0 output: on
  - check: `jq -r .defaults.autofix.mode claude/workflow/pr-flow/config/pr-flow.json` exit 0 expect /^on$/
- [x] `AC-H5` *(human)* the spec parses and carries the AUTOFIX code once
  - observed `2026-10-16` check: bash -c python3 -c 'import xml.dom.minidom,sys; xml.dom.minidom.parse(sys.argv[1])' claude/workflow/docs/pr-process/pr-process.spec.xml && grep -c 'value="AUTOFIX"' claude/workflow/docs/pr-process/pr-process.spec.xml exit 0 output: 1
  - check: `bash -c python3\ -c\ \'import\ xml.dom.minidom\,sys\;\ xml.dom.minidom.parse\(sys.argv\[1\]\)\'\ claude/workflow/docs/pr-process/pr-process.spec.xml\ \&\&\ grep\ -c\ \'value=\"AUTOFIX\"\'\ claude/workflow/docs/pr-process/pr-process.spec.xml` exit 0 expect /^1$/
- [x] `AC-H6` *(human)* every new script has a rolodex header
  - observed `2026-10-16` check: make rolodex-check BASE=origin/main exit 0 output: python3 scripts/rolodex.py check --root . --base origin/main rolodex-check: 1 script(s) checked, all have headers
  - check: `make rolodex-check BASE=origin/main` exit 0
- [x] `AC-H7` *(human)* the diff holds only In files and generated work-orders files
  - observed `2026-10-16` check: bash -c ! git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/|claude/workflow/(pr-flow/(bin/pr-flow-consume\.sh|pr-flow\.mk|config/pr-flow\.json|schemas/pr-flow-record\.schema\.json|tests/(autofix|records)\.test\.sh)|docs/pr-process/pr-process\.(md|spec\.xml)))$' exit 0 output:
  - check: `bash -c \!\ git\ diff\ --name-only\ origin/main...HEAD\ \|\ grep\ -vE\ \'\^\(work-orders/\|claude/workflow/\(pr-flow/\(bin/pr-flow-consume\\.sh\|pr-flow\\.mk\|config/pr-flow\\.json\|schemas/pr-flow-record\\.schema\\.json\|tests/\(autofix\|records\)\\.test\\.sh\)\|docs/pr-process/pr-process\\.\(md\|spec\\.xml\)\)\)\$\'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

pr-flow-consume.sh verb autofix, its call from every sweep tick, the AUTOFIX record, config key autofix and the Make target pr-autofix

**Cases**

- `TP-1`
  - intent: a PR red only on a mechanical fix waits on a seat for minutes; the sweep fixes it in one tick (08:00-08:15Z: PRs 216, 219, 225, 234 red on headers or tracked-ignored-check; orchestrator stopgap drop-views.sh)
  - command: `make -C claude/workflow pr-flow-test CASES="autofix"`
  - expected: exit 0; prints `ok  autofix`; a fixture PR head tracking an ignored path and a stale contents list gets one commit that untracks the path and rewrites the list, pushed to its head branch on the fixture bare remote, and pub.log holds exactly one `ci.autofix` line with code AUTOFIX and key AUTOFIX/o/r/1/<head>
- `TP-2`
  - intent: once per head sha, or the sweep pushes on every tick (item 1)
  - command: `make -C claude/workflow pr-flow-test CASES="autofix"`
  - expected: exit 0; a second tick on the same head pushes nothing and posts nothing
- `TP-3`
  - intent: content failures (headers, Bump lines) are never guessed; they stay with the 422 lane and a fix seat
  - command: `make -C claude/workflow pr-flow-test CASES="autofix"`
  - expected: exit 0; a red PR with nothing mechanical to fix prints `o/r PR 1 autofix-none`, pushes nothing, posts no AUTOFIX, and its 422 record is still posted
- `TP-4`
  - intent: the fallbacks are coded: push refused or a fork PR leaves the PR to the worker lane; mode off disables the verb with no code change
  - command: `make -C claude/workflow pr-flow-test CASES="autofix"`
  - expected: exit 0; a refused push prints `o/r PR 1 autofix-fail push` and posts no AUTOFIX; isCrossRepository true prints `autofix-skip fork`; autofix.mode off makes no git call; the temp worktree is gone after every case
- `TP-5`
  - intent: the sweep, regen-index, rerun-stale-red and record cases still hold
  - command: `make -C claude/workflow pr-flow-test CASES="consume regen-index rerun-stale-red records"`
  - expected: exit 0
- `TP-6`
  - intent: the Make target refuses without REPO (item 17)
  - command: `make -C claude/workflow pr-autofix; echo rc=$?`
  - expected: prints `pr-autofix needs REPO=` and `rc=2`
- `TP-7`
  - intent: scripts stay shellcheck clean
  - command: `make -C claude/workflow pr-flow-lint`
  - expected: exit 0

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- UAT and stable: the P2 test ticket cut beside this one
- the full claude/workflow suite: CI runs it

## Assumptions

1. whole-verb fallback: autofix.mode off in pr-flow.json disables it with no code change; the 422 worker lane is the path it falls back to
1. the sweep host has npx (doctoc) like the seats; where it does not, only the tracked-ignored fix applies

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` depends on WO-20261016-b211 too: it also touches claude/workflow/pr-flow/config/pr-flow.json (item 19)

## Outcome

_Written by `work-order done`. Empty until then._
