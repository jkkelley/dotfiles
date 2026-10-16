---
{
  "id": "WO-20261016-ea9e",
  "slug": "close-wo-20261016-6e7f-wk-d-pr-285-merged-start-",
  "title": "Close WO-20261016-6e7f (WK-D, PR 285 merged): start, submit, check, done, so WK-Dt and WK0 can start",
  "type": "chore",
  "status": "cancelled",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:54:21+00:00",
  "parent": "WO-20261016-35de",
  "branch": null,
  "pr": null,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design12 cut for ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-6e7f --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 2,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [],
  "superseded_by": null
}
---

# WO-20261016-ea9e - Close WO-20261016-6e7f (WK-D, PR 285 merged): start, submit, check, done, so WK-Dt and WK0 can start

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

WO-20261016-6e7f - WK-D: wiki engine design doc and XML spec - mermaid pipeline, status codes, GOOD/NEVER per rule - shipped in PR 285 (merged, da04432) but still reads ready, so work-order.sh next lists merged work and WO-20261016-7a8f - WK-Dt: test plan and script for the wiki engine design doc and spec - and WO-20261016-96c4 - WK0 - wait on it forever. Its seven ac_checks all pass on main today (spec-check ok, md-contents ok), so work-order.sh check ticks them and plain done closes it.

## Owner words

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

## Context

Order ORD-0830 RR-orch-14, brief BR-20261016-infra-design12 item WK chain after 6e7f; precedent WO-20261016-4925 (close 6e8e at PR 174).

Checks re-run on origin/main 8890822 by infra-design12: bash scripts/spec-check.sh docs/design/wiki.spec.xml printed ok (145 lines); bash scripts/md-contents.sh check docs/design/wiki.md exit 0.

## Scope

**In**

- touches: none outside work-orders: the 6e7f ticket file moves to work-orders/archive/2026/ by work-order.sh done only
- touches (generated, written only by work-order.sh start/submit/check/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree; `bash claude/skills/work-order/scripts/work-order.sh start --id WO-20261016-6e7f`; then submit --id WO-20261016-6e7f --pr 285
- step: `bash claude/skills/work-order/scripts/work-order.sh check --id WO-20261016-6e7f` runs and ticks AC-H1 to AC-H7; any failed check: stop with DESIGN-GAP and its output, never tick by hand
- step: `bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-6e7f`; commit chore(work-orders): close WO-20261016-6e7f at PR 285 with this ticket id; no Bump trailer
- tool: cmd:git, cmd:jq, cmd:gh, cmd:make, cmd:podman, script:scripts/spec-check.sh, script:scripts/md-contents.sh - on main; fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output; a red check: stop with DESIGN-GAP and its output, never tick

**Out - non-goals**

- any edit to docs/design/wiki.md or docs/design/wiki.spec.xml
- any edit to the closed ticket content beyond what work-order.sh start, submit, check and done write
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* WO-20261016-6e7f is done and archived
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-6e7f --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H2` *(human)* the diff holds only work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

```sh
{"scope":"close-out of WO-20261016-6e7f (PR 285 merged)","cases":[{"id":"TP-1","intent":"the WK-D criteria hold on main: spec within limits with contents","command":"bash scripts/spec-check.sh docs/design/wiki.spec.xml","expected":"exit 0; a line starting ok"},{"id":"TP-2","intent":"PR 285 is merged","command":"gh pr view 285 --json state -q .state","expected":"exit 0; MERGED"},{"id":"TP-3","intent":"the ticket is archived as done","command":"bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-6e7f --json","expected":"exit 0; .status is done"}],"isolation":{"runtime":"podman","image":"docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd"},"out_of_scope":["CI checks of PR 285: CI ran them"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

Cancelled `2026-10-16` - nothing shipped.

- reason: superseded: 6e7f closed on main by the land-6e7f PR 294 (3285e3b); ea9e's start of 6e7f failed on branch_exists (seats/close-6e7f.result.json). infra-design14, ORD-0830 RR-orch-14 F36

No branch, no PR and no merge commit exist for this work order.

