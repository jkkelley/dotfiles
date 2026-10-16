---
{
  "id": "WO-20261016-231a",
  "slug": "work-order-sh-redraft-id-reason-moves-a-ready-ti",
  "title": "work-order.sh redraft --id --reason moves a ready ticket back to draft, clears its approval and notes the reason, so amend can change it",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:07:54+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design13 cut for ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-5320"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "410-redraft"
    },
    {
      "index": 2,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(SKILL\\.md|references/lifecycle\\.md|scripts/work-order\\.sh|testing/SOP\\.md|testing/cases/410-redraft\\.sh))$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "path:claude/skills/work-order/testing/cases/410-redraft.sh"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-231a - work-order.sh redraft --id --reason moves a ready ticket back to draft, clears its approval and notes the reason, so amend can change it

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

work-order.sh has no path to amend a ready ticket: amend requires draft and no verb leads from ready back to draft, so a wrong ready ticket can only gain notes (WO-20261016-3ac1 was corrected by a note).

## Owner words

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in, thats a prereq for the ticket ready then (Design principles 101 item 30)

> DAG SHOULD BE EFFORTLESS WITH EASY MIGRATION PLANS FOR UPDATED CREATING DELETING MOVING NODES (Design principles 101 item 40)

## Context

Order ORD-0830 RR-orch-14, brief BR-20261016-infra-design13 item DESIGN-GAP amend ready ticket; evidence seats/infra-design12.result.json facts.tool_gap. Chain on work-order.sh: 67c7 -> f57d -> e297 -> 2eb1 -> 25f7 -> 4710 -> 3a66 -> WO-20261016-5afd -> WO-20261016-5320 -> this ticket. A ready->draft verb was chosen over amend-on-ready so a changed contract always passes approve (and its tool resolution) again.

Behaviour, fixed. New verb: work-order.sh redraft [--project DIR] --id WO-... --reason T [--json]. ready: set status draft, approval null, updated today, append the note 'redraft: REASON' through the same code path as the note verb, reindex; stdout 'ok redraft ID ready -> draft', exit 0. draft: stdout 'ok redraft ID already draft', exit 0, nothing written (idempotent). Any other status: exit 3 illegal_transition naming the status and that redraft only takes ready. No --reason or empty: exit 2. Add the verb to the usage text and dispatch. references/lifecycle.md and the SKILL.md lifecycle table: ready's legal next gains draft (via redraft); SKILL.md usage block gains one redraft line.

Test case claude/skills/work-order/testing/cases/410-redraft.sh: (a) ready ticket: redraft exit 0, status draft, approval null, Notes has 'redraft: REASON'; then amend --ac succeeds and approve --no-lavish --reason returns it to ready; (b) redraft on that draft again (before approve): exit 0 'already draft', file byte-identical; (c) in-progress ticket: exit 3 illegal_transition; (d) no --reason: exit 2.

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (cmd_redraft, usage text and dispatch only)
- touches: claude/skills/work-order/references/lifecycle.md (ready row and a redraft entry)
- touches: claude/skills/work-order/SKILL.md (lifecycle table ready row, one usage line)
- touches: claude/skills/work-order/testing/cases/410-redraft.sh (new, cases a to d in Context)
- touches: claude/skills/work-order/testing/SOP.md (one entry for 410)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree after WO-20261016-5320 merged; make exactly the five edits in Context
- step: run `bash claude/skills/work-order/testing/run-tests.sh` and the AC checks only; CI runs the rest
- step: commit 'feat(work-order): redraft moves a ready ticket back to draft' with the ticket id; the PR body ends with 'Bump: work-order=minor'
- tool: script:claude/skills/work-order/testing/run-tests.sh - on main; fallback: missing: stop with DESIGN-GAP naming it; its image fails to build: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- amend on a ready ticket: amend stays draft-only
- redraft from in-progress, in-review or stale
- re-cutting existing ready tickets
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the work-order suite passes with the new case
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /410-redraft/
- [ ] `AC-H2` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H3` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(SKILL\.md|references/lifecycle\.md|scripts/work-order\.sh|testing/SOP\.md|testing/cases/410-redraft\.sh))$'` exit 1

## Test plan

```sh
{"scope":"redraft returns a ready ticket to draft so amend can change it","cases":[{"id":"TP-1","intent":"a wrong ready ticket could only gain notes (3ac1); redraft must reopen the contract and force approve again","command":"bash claude/skills/work-order/testing/run-tests.sh","expected":"exit 0; 410-redraft prints only ok lines"},{"id":"TP-2","intent":"rolodex header kept","command":"make rolodex-check BASE=origin/main","expected":"exit 0"}],"isolation":{"runtime":"podman","image":"docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd"},"out_of_scope":["the skill gates: CI runs them"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
