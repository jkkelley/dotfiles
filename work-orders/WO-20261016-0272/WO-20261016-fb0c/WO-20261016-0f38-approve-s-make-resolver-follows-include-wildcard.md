---
{
  "id": "WO-20261016-0f38",
  "slug": "approve-s-make-resolver-follows-include-wildcard",
  "title": "approve's make resolver follows -include $(wildcard DIR/*.mk) when DIR is the including makefile's own directory, so wiki-process resolves",
  "type": "bug",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:44:16+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design15 cut for ORD-0830 RR-orch-14 F35; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-cdd4"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "430-approve-make-wildcard-include"
    },
    {
      "index": 2,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\\.sh|testing/SOP\\.md|testing/cases/430-approve-make-wildcard-include\\.sh))$'",
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

# WO-20261016-0f38 - approve's make resolver follows -include $(wildcard DIR/*.mk) when DIR is the including makefile's own directory, so wiki-process resolves

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

make_has_target (work-order.sh:982-1000) skips every include path containing $, so a target defined in claude/tools/wiki/mk/process.mk, reached from the root Makefile via claude/tools/wiki/wiki.mk line '-include $(wildcard $(WIKI_DIR)mk/*.mk)', reads as tool_missing: approve of the 168d close-out refused 'tool_missing wiki-process: make target not found in Makefile on origin/main' while 'make -n wiki-process WIKI=/tmp/wk SRC=/tmp/src' exits 0 on main 6b1af2d

## Owner words

> see a bug, isolate it, and get it fixed as asap (Design principles 101 item 22)

> close-outs fb99 3327 168d (F45-F47) (orchestrator brief BR-20261016-infra-design15)

## Context

Order brief BR-20261016-infra-design15; found by infra-design15 cutting the 168d close-out. Repro: on origin/main, a draft ticket whose ac_check is 'make -n wiki-process WIKI=/tmp/wk SRC=/tmp/src' -> work-order.sh approve refuses tool_missing wiki-process. Edit 1, make_has_target: before the include loop, collect self-dir variables, every line matching '^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*:?=[[:space:]]*$\(dir $\(lastword $\(MAKEFILE_LIST\)\)\)' maps NAME to the directory of mf (dirname, with a trailing /, '' for the root); in each include path replace $(NAME) by that directory; an include of the form '$(wildcard GLOB)' whose GLOB then holds no $ expands to the files under the ref (git -C "$project" ls-tree --name-only "$ref" -- "$(dirname GLOB)/" when ref is set, else the files on disk) whose path matches GLOB as a bash pattern; each match recurses exactly like a literal include; any include still holding $ is skipped as today. Breadcrumb comment naming the 168d refusal, the rejected alternative (run make -n: executes the project's makefile at approve, which approve must not do) and the cost (only the self-dir idiom and wildcard are understood). Edit 2, new testing/cases/430-approve-make-wildcard-include.sh: a project whose Makefile includes sub/s.mk, which sets D := $(dir $(lastword $(MAKEFILE_LIST))) and '-include $(wildcard $(D)mk/*.mk)', and sub/mk/p.mk defines target pt: a draft ticket with ac_check 'make -n pt' approves; one with 'make -n absent' still refuses tool_missing. Edit 3, testing/SOP.md: one entry for 430.

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (make_has_target include loop and its breadcrumb only)
- touches: claude/skills/work-order/testing/cases/430-approve-make-wildcard-include.sh (new)
- touches: claude/skills/work-order/testing/SOP.md (one entry for 430)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: make exactly the three edits in Context
- step: run the AC checks only; CI runs the rest
- step: commit 'fix(work-order): approve resolves make targets behind a self-dir wildcard include' with the ticket id; the PR body ends with 'Bump: work-order=patch'
- tool: script:claude/skills/work-order/testing/run-tests.sh - on main; fallback: missing: stop with DESIGN-GAP naming it; its image fails to build: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any other make syntax (variables other than the self-dir idiom, conditionals, eval)
- approve --code-dir: WO-20261016-e297 owns it
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* a target behind a self-dir wildcard include resolves, and a missing one still refuses
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /430-approve-make-wildcard-include/
- [ ] `AC-H2` *(human)* rolodex pointers hold
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H3` *(human)* the diff holds only the In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\.sh|testing/SOP\.md|testing/cases/430-approve-make-wildcard-include\.sh))$'` exit 1

## Test plan

```sh
{"scope":"approve make target resolution through wildcard includes","cases":[{"id":"TP-1","intent":"a real target behind wiki.mk's include idiom is never tool_missing","command":"bash claude/skills/work-order/testing/run-tests.sh","expected":"exit 0; 430-approve-make-wildcard-include listed as passed"}],"isolation":{"runtime":"podman","image":"the digest-pinned image run-tests.sh builds"},"out_of_scope":["other skills' suites: CI runs them"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
