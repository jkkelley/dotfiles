---
{
  "id": "WO-20261016-1b46",
  "slug": "work-order-sh-approve-code-dir-dir-resolves-a-cr",
  "title": "work-order.sh approve --code-dir DIR resolves a cross-repo ticket's step and AC tools on DIR's freshly fetched origin/main only, never HEAD, the working tree or an old copy",
  "type": "feature",
  "status": "cancelled",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:08:26+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design17 cut for ORD-1053 / ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4; Lavish prohibited for Claude seats (global rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "all cases passed"
    },
    {
      "index": 2,
      "command": "grep -c -- '--code-dir) ' claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 3,
      "command": "grep -c code_fetch_failed claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^[1-9]"
    },
    {
      "index": 4,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 5,
      "command": "bash -c '! git diff --name-only origin/main...HEAD | grep -vE \"^(work-orders/.*|claude/skills/work-order/scripts/work-order[.]sh|claude/skills/work-order/testing/cases/370-approve-code-dir[.]sh)$\"'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [
    "claude/skills/work-order/testing/cases/370-approve-code-dir.sh"
  ],
  "labels": [
    "line:inbox-triage"
  ],
  "superseded_by": "WO-20261016-ef1b"
}
---

# WO-20261016-1b46 - work-order.sh approve --code-dir DIR resolves a cross-repo ticket's step and AC tools on DIR's freshly fetched origin/main only, never HEAD, the working tree or an old copy

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

approve resolves make targets and scripts against the ticket project. A business ticket whose code lives in ypli-01-src or ypconsult-01-src names targets of that repo's Makefile, so every such ticket refuses: bash ~/dotfiles/claude/skills/work-order/scripts/work-order.sh approve --project <business worktree> --id WO-20261016-e351 --no-lavish --reason x -> error: tool_missing lint (evidence ~/.local/state/zenith/inbox-triage/20261015/seats/yp-design6.result.json tool_gap; again seats/yp-design11.result.json design_gap[0], repro approve WO-20261016-ae26 -> tool_missing lint). Design seats then approved with zwo, an older copy, which is the gate silently off.

## Owner words

> ORD-1053 A1 (L0 top): fix ticket at L0 top: a ticket declares code_repo (default the ticket repo) and work-order.sh approve resolves named tools on that repo origin/main. Ruling: no gate bypass through an old tool copy (zwo refreshed from dotfiles main 10:52Z). (orchestrator brief BR-20261016-infra-design17)

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in, thats a prereq for the ticket ready then, you feel me? (Design principles 101 item 30)

> Have fallbacks too (Design principles 101 item 28)

## Context

Order ORD-1053 A1, brief BR-20261016-infra-design17. Supersedes WO-20261016-e297 (same scope, plus the origin/main-only and fetch rules below, so no old copy or stale clone passes the gate). code_repo is the existing ticket .repo field (OWNER/NAME, written by new/set --repo, WO-20261016-f57d via WO-20261016-9c09); .repo null means the ticket repo, so default behaviour is unchanged. No second field is added. Behaviour, fixed: approve gains --code-dir DIR. (1) .repo set and no --code-dir: exit 2 code_dir_required naming the repo. (2) DIR must be a git checkout whose raw origin url (git -C DIR config --get remote.origin.url, so url.insteadOf rewrites do not change the match), normalized from git@github.com:O/R(.git) or https://github.com/O/R(.git) to O/R, equals .repo, else exit 3 code_dir_mismatch printing both. (3) approve runs git -C DIR fetch -q origin main, up to 3 tries 2 s apart; all fail: exit 4 code_fetch_failed with the git stderr (fallback: the seat retries later or stops with A2A-003; there is no offline pass, since a stale clone is the bypass this ticket closes). (4) DIR without refs/remotes/origin/main after the fetch: exit 3 code_ref_missing. (5) Tools then resolve in DIR at origin/main exactly as resolve_tool does today in the project (tool_ref, tool_cat, make_has_target and the bash path check take a tool root instead of $project); the HEAD and working-tree fallbacks of tool_ref are not used for DIR. (6) .repo null: --code-dir refused with exit 2 code_dir_without_repo, and resolution is unchanged (project origin/main, else HEAD, else working tree, as today). Breadcrumb at require_tools_resolve citing the yp-design6 repro and this ticket. Rejected: guessing ~/projects/<name> from .repo, a guessed checkout can be stale or another clone; rejected: skipping the tool check for cross-repo tickets, the gate silently off (ORD-0555); rejected: a code_repo field beside .repo, two fields naming one fact. Cost: approve of a cross-repo ticket needs network for one fetch. Test case 370 fixture: a project with no Makefile; a bare repo /work/code.git with Makefile target lint on main; a checkout of it whose remote.origin.url is https://github.com/acme/code and whose git config has url.file:///work/code.git.insteadOf=https://github.com/acme/code, so the fetch works with --network=none. Cases: approve without --code-dir exit 2 code_dir_required; checkout whose origin is acme/other exit 3 code_dir_mismatch; right checkout -> ready; ssh form git@github.com:acme/code.git matches too; target lint present only in the checkout's working tree and an unpushed HEAD commit, not on origin/main -> exit 3 tool_missing (the old-copy bypass); bare repo moved away -> exit 4 code_fetch_failed; .repo null with --code-dir exit 2 code_dir_without_repo; .repo null without --code-dir behaves as case 280.

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (approve --code-dir parse and checks; tool root in tool_ref, tool_cat, make_has_target, resolve_tool; usage line for approve; breadcrumb at require_tools_resolve)
- touches: claude/skills/work-order/testing/cases/370-approve-code-dir.sh (new: the fixture and the eight cases in Context)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree after WO-20261016-9c09, WO-20261016-0f38, WO-20261016-9fc7 and WO-20261016-2d5b merged, never the ~/dotfiles primary clone; write exactly the two files above to the design in Context
- step: run `bash claude/skills/work-order/testing/run-tests.sh` and the AC checks only; CI runs the rest
- step: commit 'feat(work-order): approve --code-dir resolves tools on the code repo origin/main' with the ticket id; the PR body ends with 'Bump: work-order=minor'
- tool: path:claude/skills/work-order/testing/run-tests.sh - on main; fallback: its image fails to build: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- re-approving business tickets: business design seats do that with --code-dir after merge
- SKILL.md, references/lifecycle.md and testing/SOP.md: WO-20261016-2eb1 owns them and runs after this ticket
- refreshing zwo or any seat tool copy: WO-20261016-8e05 and WO-20261016-9756 (ORD-1053 A4) own it
- check and done --code-dir: WO-20261016-1099 owns them
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the work-order suite passes with case 370
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /all cases passed/
- [ ] `AC-H2` *(human)* approve parses --code-dir
  - check: `grep -c -- '--code-dir) ' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^1$/
- [ ] `AC-H3` *(human)* approve refuses a failed fetch by name
  - check: `grep -c code_fetch_failed claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^[1-9]/
- [ ] `AC-H4` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H5` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c '! git diff --name-only origin/main...HEAD | grep -vE "^(work-orders/.*|claude/skills/work-order/scripts/work-order[.]sh|claude/skills/work-order/testing/cases/370-approve-code-dir[.]sh)$"'` exit 0

## Test plan

```sh
{"scope":"approve --code-dir resolves cross-repo tools on the fetched code repo origin/main only","cases":[{"id":"TP-1","intent":"a business ticket naming ypli Makefile targets refused tool_missing lint (yp-design6); with --code-dir it must resolve on that repo origin/main and never on a stale working tree","command":"bash claude/skills/work-order/testing/run-tests.sh","expected":"exit 0; case 370 prints ok for all eight cases and the existing cases still pass"},{"id":"TP-2","intent":"rolodex header kept","command":"make rolodex-check BASE=origin/main","expected":"exit 0"}],"isolation":{"runtime":"podman","image":"localhost/work-order-test:1"},"out_of_scope":["re-approving business tickets"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` infra-design17: no depends_on edge to WO-20261016-0f38 because its file moves to archive in open PR 321 (an edge would conflict); the start step still waits for PR 321 merged, same file work-order.sh

## Outcome

Cancelled `2026-10-16` - nothing shipped.

- reason: ORD-1114 C1 reconcile (infra-design18): e297 is being built and 1099 follows it; 1b46's approve-on-origin/main ruling moves into WO-20261016-ef1b with check, evidence and done, so no two tickets carry approve --code-dir
- superseded by: `WO-20261016-ef1b`

No branch, no PR and no merge commit exist for this work order.

