---
{
  "id": "WO-20261016-ece2",
  "slug": "claude-workflow-templates-close-successor-md-the",
  "title": "claude/workflow/templates/close-successor.md: the close-successor pattern (WO-20261016-bcb4, WO-20261016-aa46) as a template a design seat fills, with its work-orders-only scope check",
  "type": "chore",
  "status": "done",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:35:27+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": "feat/ece2-claude-workflow-templates-close-successor-md-the",
  "pr": 334,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design18 cut for the stranded close-out class; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make md-contents-check",
      "exit": 0,
      "expect": null
    },
    {
      "index": 2,
      "command": "grep -c -e 'superseded-by THIS-TICKET-ID' -e 'no-depends-on' -e 'work-orders/\\.\\*' claude/workflow/templates/close-successor.md",
      "exit": 0,
      "expect": "^([3-9]|[1-9][0-9])"
    },
    {
      "index": 3,
      "command": "grep -c -E '^(GOOD|NEVER):' claude/workflow/templates/close-successor.md",
      "exit": 0,
      "expect": "^([3-9]|[1-9][0-9])"
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/templates/close-successor\\.md)$'",
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

# WO-20261016-ece2 - claude/workflow/templates/close-successor.md: the close-successor pattern (WO-20261016-bcb4, WO-20261016-aa46) as a template a design seat fills, with its work-orders-only scope check

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

Stranded close-outs recur (F36, F51: WO-20261016-9fc7, WO-20261016-168d, WO-20261016-1b7e, WO-20261016-f57d) and every design seat rebuilds the close successor by hand from the last one it saw. A hand copy carried WO-20261016-1b7e's contradicting scope check 7 into a close ticket, and done refused it. claude/workflow/templates holds scope-ac.md and test-plan.md but no close-successor template.

## Owner words

> design seat infra-design: ORD-1114 code_repo for every verb (reconcile 1b46 with e297 and 1099), stranded close-outs 9fc7 and 168d, DESIGN-GAP 168e test plan, F44 close-outs; keep the 6-leaf buffer (orchestrator brief BR-20261016-infra-design18)

> everything portable, generic, templated out so everybody gets it, NEVER REINVENT THE WHEEL (Design principles 101 item 4)

> every node has what it fucking needs up front, not later, design it that way (Design principles 101 item 30)

## Context

Order brief BR-20261016-infra-design18. New file claude/workflow/templates/close-successor.md, same frame as claude/workflow/templates/scope-ac.md: the doctoc START and END comment lines at the top (filled by make md-contents, never by hand), then '# Close-successor template', one sentence per line. Section '## When to use': a ticket whose code PR merged but which is not done on main (ready, in-progress or in-review), or whose done is refused by a broken check; a successor closes it, never a second build. Section '## Fields': the title line 'Close <OLD-ID> (<what>, PR <N> merged): re-run its checks <i,j,k> on main under this ticket, move its <dependents> edges here and cancel <OLD hex> as superseded'; type chore; same parent as the old ticket; --blocks each open dependent of the old ticket at cut time. Section '## Steps', a fenced text block a design seat copies into Context: one line per dependent 'bash claude/skills/work-order/scripts/work-order.sh link --id <DEP> --no-depends-on <OLD-ID>'; then 'bash claude/skills/work-order/scripts/work-order.sh cancel --id <OLD-ID> --reason '<what>; re-checked under THIS-TICKET-ID' --superseded-by THIS-TICKET-ID'; then 'bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID'; then commit the generated moves, open the PR, submit --pr <N>, done, commit and push.

Section '## Acceptance criteria' rules: copy every check of the old ticket verbatim as '<OLD-ID> check N passes on main (copied from <OLD-ID> check N)', except its scope check, which is dropped; add '<OLD-ID> is cancelled and superseded' with check bash claude/skills/work-order/scripts/work-order.sh show --id <OLD-ID> --json piped to jq -r '.status + " " + (.superseded_by // "-")', exit 0, expect ^cancelled WO-; add 'no open ticket still depends on <OLD-ID>' with the grep -rlE '"<OLD-ID>"' work-orders --include='WO-*.md' | xargs -r grep -L -E '"status": "(done|cancelled)"' | grep -v -- '-<OLD hex>-' check, exit 1; the last criterion is the scope check of claude/workflow/templates/scope-ac.md with the alternation work-orders/.* alone, exit 1. Section '## Test plan': one case, TP-1 bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID, expected exit 0 and one AC-PASS line per criterion, in the claude/workflow/templates/test-plan.md shape. Then 'GOOD: WO-20261016-aa46 - copies 1b7e checks 1-6 and 8, drops the contradicting 7, ends on the work-orders-only scope check.' and 'NEVER: copying the old ticket's scope check into the successor - it names code paths a close diff never touches, or contradicts the work-orders-only check (WO-20261016-1b7e check 7).' and 'NEVER: re-running start on the stranded ticket - its branch may exist and its scope check fails on a close diff.'

## Scope

**In**

- touches: claude/workflow/templates/close-successor.md (new)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone
- step: write claude/workflow/templates/close-successor.md exactly as in Context, then `make md-contents` to fill its contents list
- step: commit 'docs(workflow): close-successor template' with the ticket id; no Bump trailer; push, open the PR, leave
- tool: make:Makefile:md-contents, make:Makefile:md-contents-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- changing claude/workflow/templates/scope-ac.md or test-plan.md: the template points at them
- a generator verb that writes close successors: a later ticket if the owner orders one
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the contents list is present and fresh
  - observed `2026-10-16` make md-contents-check exit 0: md-contents: 1 file(s) ok
  - check: `make md-contents-check` exit 0
- [x] `AC-H2` *(human)* the template carries the cancel step, the edge move and the work-orders-only scope check
  - observed `2026-10-16` grep -c count 3, exit 0
  - check: `grep -c -e 'superseded-by THIS-TICKET-ID' -e 'no-depends-on' -e 'work-orders/\.\*' claude/workflow/templates/close-successor.md` exit 0 expect /^([3-9]|[1-9][0-9])/
- [x] `AC-H3` *(human)* the template carries its GOOD and NEVER examples
  - observed `2026-10-16` grep -c count 3, exit 0
  - check: `grep -c -E '^(GOOD|NEVER):' claude/workflow/templates/close-successor.md` exit 0 expect /^([3-9]|[1-9][0-9])/
- [x] `AC-H4` *(human)* the diff holds only the In files
  - observed `2026-10-16` scope grep printed nothing, exit 1
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/templates/close-successor\.md)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/templates/close-successor.md, the close-successor pattern as a template

**Cases**

- `TP-1`
  - intent: a design seat that copies the template gets a scope check that passes on a work-orders-only diff and every step it needs
  - command: `make md-contents-check`
  - expected: exit 0
- `TP-2`
  - intent: the template names the cancel step, the edge move and the work-orders-only scope check, so no close successor is cut without them
  - command: `grep -c -e 'superseded-by THIS-TICKET-ID' -e 'no-depends-on' -e 'work-orders/\.\*' claude/workflow/templates/close-successor.md`
  - expected: exit 0 and a count of 3 or more

**Isolation**

- runtime: podman
- image: `docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9` (python:3.12-slim)

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
