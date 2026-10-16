---
{
  "id": "WO-20261016-be8a",
  "slug": "pr-flow-json-restore-business-ci-targets-tracked",
  "title": "pr-flow.json: restore business ci targets tracked-ignored-check reverted by PR 262",
  "type": "bug",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:19:33+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design9 cut for ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-c6a5"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "jq -e '.repos[\"jkkelley/business\"].ci | .pr_targets==[\"tracked-ignored-check\"] and .main_targets==[\"tracked-ignored-check\"]' claude/workflow/pr-flow/config/pr-flow.json",
      "exit": 0,
      "expect": "^true$"
    },
    {
      "index": 2,
      "command": "jq -r '.[\"$comment\"]' claude/workflow/pr-flow/config/pr-flow.json",
      "exit": 0,
      "expect": "7325896"
    },
    {
      "index": 3,
      "command": "make -C claude/workflow pr-flow-test CASES=\"records consume\"",
      "exit": 0,
      "expect": "ok  consume"
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/pr-flow/config/pr-flow\\.json)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": []
}
---

# WO-20261016-be8a - pr-flow.json: restore business ci targets tracked-ignored-check reverted by PR 262

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

PR 262 (WO-20261016-448e, merge 7325896) restored pr-flow.json byte-exact from d478078 and so reverted PR 244 (ffe1b50, ORD-0806 R3), which had landed between them: repos["jkkelley/business"].ci.pr_targets and main_targets went from ["tracked-ignored-check"] back to ["none"]. Business CI renders with no target.

## Owner words

> see a bug, isolate it, and get it fixed as asap (Design principles 101 item 22)

## Context

Reproduction 2026-10-16: git diff 7325896^ 7325896 -- claude/workflow/pr-flow/config/pr-flow.json shows -"tracked-ignored-check" +"none" twice; jq -c ".repos[\"jkkelley/business\"].ci|[.pr_targets,.main_targets]" on origin/main prints [["none"],["none"]]; git show ffe1b50:... prints the tracked-ignored-check pair. PR 270 (c48a266) touched the file after 262 but not these keys.

Waits on WO-20261016-c6a5 because it also edits pr-flow.json (stale_merged on jkkelley/business); disjoint files rule (item 19).

## Scope

**In**

- touches: claude/workflow/pr-flow/config/pr-flow.json (repos["jkkelley/business"].ci.pr_targets and .main_targets each set to ["tracked-ignored-check"]; the top-level "$comment" string gains one sentence as the breadcrumb, since JSON has no comments: business ci targets are tracked-ignored-check (PR 244, ORD-0806 R3); PR 262 commit 7325896 reverted them and this ticket restored them)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree after WO-20261016-c6a5 merged; make exactly the edit above with jq or an editor, keeping two-space indent
- step: run TP-1 to TP-3 of the test plan and the AC checks only; CI runs the rest
- step: commit 'fix(pr-flow): restore business ci targets reverted by PR 262 (ORD-0806 R3)' with the ticket id; no Bump trailer (no file under claude/skills changes)
- tool: make:claude/workflow/Makefile:pr-flow-test - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any other key in pr-flow.json
- work-orders/INDEX.md and epic READMEs by hand or by git add
- waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* business ci targets are tracked-ignored-check
  - check: `jq -e '.repos["jkkelley/business"].ci | .pr_targets==["tracked-ignored-check"] and .main_targets==["tracked-ignored-check"]' claude/workflow/pr-flow/config/pr-flow.json` exit 0 expect /^true$/
- [ ] `AC-H2` *(human)* the breadcrumb is in the comment
  - check: `jq -r '.["$comment"]' claude/workflow/pr-flow/config/pr-flow.json` exit 0 expect /7325896/
- [ ] `AC-H3` *(human)* the record and consume suites pass
  - check: `make -C claude/workflow pr-flow-test CASES="records consume"` exit 0 expect /ok consume/
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/pr-flow/config/pr-flow\.json)$'` exit 1

## Test plan

{"scope":"pr-flow.json business ci pr_targets and main_targets restored to tracked-ignored-check","cases":[
{"id":"TP-1","intent":"PR 262 commit 7325896 restored pr-flow.json from d478078 and silently reverted PR 244 ffe1b50 (ORD-0806 R3), so business CI renders with target none; the values must be back exactly","command":"jq -e '.repos[\"jkkelley/business\"].ci | .pr_targets==[\"tracked-ignored-check\"] and .main_targets==[\"tracked-ignored-check\"]' claude/workflow/pr-flow/config/pr-flow.json","expected":"exit 0; prints true"},
{"id":"TP-2","intent":"nothing else in the config moved: the diff against main is the two target lines and the comment","command":"git diff --numstat origin/main...HEAD -- claude/workflow/pr-flow/config/pr-flow.json","expected":"exit 0; prints 3 additions and 3 deletions"},
{"id":"TP-3","intent":"the record and consume suites still read the config","command":"make -C claude/workflow pr-flow-test CASES=\"records consume\"","expected":"exit 0; prints ok  records and ok  consume"}],
"isolation":{"runtime":"podman","image":"docker.io/library/debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251"},
"out_of_scope":["the full claude/workflow suite: CI runs it"]}

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
