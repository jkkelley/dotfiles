---
{
  "id": "WO-20261016-3a66",
  "slug": "work-order-sh-approve-skips-leading-var-value-as",
  "title": "work-order.sh approve skips leading VAR=value assignments and env in a step or AC check before resolving the command",
  "type": "bug",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:54:57+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design12 cut for ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-4710"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "380-approve-env-prefix"
    },
    {
      "index": 2,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\\.sh|testing/SOP\\.md|testing/cases/380-approve-env-prefix\\.sh))$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "path:claude/skills/work-order/testing/cases/380-approve-env-prefix.sh"
  ]
}
---

# WO-20261016-3a66 - work-order.sh approve skips leading VAR=value assignments and env in a step or AC check before resolving the command

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

approve (resolve_tool in claude/skills/work-order/scripts/work-order.sh) takes the first word of a backticked step or ac_check command as the tool, so a check written 'FORCE_FALLBACK=1 bash scripts/x.sh' is refused with tool_missing FORCE_FALLBACK=1: command does not resolve. A shell runs that line fine; only approve misreads it, so design seats rewrite every such check as 'env FORCE_FALLBACK=1 ...', and 'env' itself then becomes the tool name, so the script after it is never checked.

## Owner words

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in, thats a prereq for the ticket ready then (Design principles 101 item 30)

> see a bug, isolate it, and get it fixed as asap (Design principles 101 item 22)

## Context

Order ORD-0830 RR-orch-14, brief BR-20261016-infra-design12 item DESIGN-GAP work-order.sh approve env-prefix; evidence seats/yp-design7.result.json facts.tool_gap (repro: approve on a ticket whose AC check starts FORCE_FALLBACK=1 bash ... -> tool_missing FORCE_FALLBACK=1).

Fold: the brief folds this into the approve cross-repo ticket WO-20261016-e297 (same function). e297 is ready and amend refuses a ready ticket (wo_require_status draft), and the work-order.sh chain 67c7 -> f57d -> e297 -> 2eb1 -> 25f7 -> 4710 is serial on this file, with 2eb1 owned by infra-design8 (do not touch). So this is cut as the next link after 4710: it depends on WO-20261016-4710 and runs on top of e297's resolve_tool.

Behaviour, fixed: in resolve_tool, after the word split and before first is taken, drop leading words matching ^[A-Za-z_][A-Za-z0-9_]*= ; then if the first word is env, drop it and any following words that match the same pattern or start with -; then first is the next word. No word left: return 0 (a bare assignment names no tool). Everything after that point (make, bash <path>, provides, command -v) is unchanged, so 'env X=1 bash scripts/a.sh' now checks scripts/a.sh exists. Breadcrumb comment at the change names this ticket and seats/yp-design7.result.json.

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (resolve_tool only: the leading-assignment and env skip, plus its breadcrumb comment)
- touches: claude/skills/work-order/testing/cases/380-approve-env-prefix.sh (new, modelled on 280-approve-resolves-tools.sh: fixture with tool.sh committed and pushed; ticket whose ac_check is 'FORCE_FALLBACK=1 bash tool.sh' -> approve exit 0 ready; 'env A=1 B=2 bash tool.sh' -> exit 0; 'FORCE_FALLBACK=1 bash missing.sh' -> exit 3 tool_missing missing.sh; 'env -i A=1 nosuchcmd' -> exit 3 tool_missing nosuchcmd; 'A=1' alone -> exit 0)
- touches: claude/skills/work-order/testing/SOP.md (one entry for 380-approve-env-prefix.sh)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree after WO-20261016-4710 merged; make exactly the three edits above to the design in Context
- step: run `bash claude/skills/work-order/testing/run-tests.sh` and the AC checks only; CI runs the rest
- step: commit 'fix(work-order): approve skips leading env assignments before resolving a tool' with the ticket id; the PR body ends with 'Bump: work-order=patch'
- tool: script:claude/skills/work-order/testing/run-tests.sh and make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it; its image fails to build: stop with ENV-MISSING podman
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any other change to approve or to resolve_tool, including the --code-dir logic of WO-20261016-e297
- SKILL.md and references/lifecycle.md: no doc edit beyond the SOP entry
- rewriting existing tickets' env-prefixed checks: they keep working
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the work-order suite passes with the new case
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /380-approve-env-prefix/
- [ ] `AC-H2` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H3` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\.sh|testing/SOP\.md|testing/cases/380-approve-env-prefix\.sh))$'` exit 1

## Test plan

```sh
{"scope":"work-order.sh approve resolves the command after leading VAR=value words and env","cases":[{"id":"TP-1","intent":"approve refused FORCE_FALLBACK=1 bash ... as tool_missing FORCE_FALLBACK=1 (seats/yp-design7.result.json), forcing env-prefixed checks whose script approve then never resolved","command":"bash claude/skills/work-order/testing/run-tests.sh","expected":"exit 0; the 380-approve-env-prefix.sh block prints only ok lines and case 280 still passes"},{"id":"TP-2","intent":"the changed script keeps its rolodex header","command":"make rolodex-check BASE=origin/main","expected":"exit 0"}],"isolation":{"runtime":"podman","image":"docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd"},"out_of_scope":["the full work-order suite on CI and the skill gates: CI runs them"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
