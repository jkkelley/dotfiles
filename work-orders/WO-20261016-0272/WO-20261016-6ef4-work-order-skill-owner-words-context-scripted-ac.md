---
{
  "id": "WO-20261016-6ef4",
  "slug": "work-order-skill-owner-words-context-scripted-ac",
  "title": "work-order skill: owner words, context, scripted AC checks, check verb, approve resolves tools",
  "type": "feature",
  "status": "in-progress",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:45:34+00:00",
  "parent": "WO-20261016-0272",
  "branch": "feat/work-order-skill-owner-words-context-scripted-ac",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design2 recut closing DESIGN-GAP on WO-20261016-0e3a; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-6e76",
    "WO-20261016-565d"
  ]
}
---

# WO-20261016-6ef4 - work-order skill: owner words, context, scripted AC checks, check verb, approve resolves tools

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

ORD-0552 O1 (architect, relayed 2026-10-16T05:56Z): "upgrade the work-order skill upstream in dotfiles (claude/skills/work-order, bump intent in PR body): new --owner-words (verbatim, repeatable) and --context sections; every --ac takes a scripted check: --ac-check \"<command>\" --ac-exit <code> [--ac-expect <regex>]; new verb work-order.sh check --id runs every AC check, ticks evidence with the command, exit code and output automatically, and refuses done while any check fails; new tickets without owner words, context or an AC check are refused (exit 3)." ORD-0555 O2: "approve refuses a ticket whose steps or AC checks call a command or Make target that does not resolve on main (exit 3, names the missing tool)". Owner, item 30: "every acceptance criterion is a scripted check with its exit condition (command, expected exit code, expected output), run by script to tick the box, every time". The one machine caller of `new` outside the skill is claude/workflow/timing/lib.sh tm_wo, which must pass the new flags in the same PR. Recut of WO-20261016-0e3a (DESIGN-GAP from seat wo-skill, evidence /home/luna/.local/state/zenith/inbox-triage/20261015/wo-skill-result.json): its In list omitted testing/assert.sh and the two cases that call work-order.sh new directly, so run-tests.sh could not pass once the flags became required, and its AC regexes /<case>.*ok/ never match run-tests.sh output (finish prints '<case>: N checks, 0 failed').

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh
- touches: claude/skills/work-order/scripts/lib/wo.sh
- touches: claude/skills/work-order/references/ticket.tmpl
- touches: claude/skills/work-order/references/lifecycle.md
- touches: claude/skills/work-order/SKILL.md
- touches: claude/skills/work-order/testing/SOP.md
- touches: claude/skills/work-order/testing/assert.sh
- touches: claude/skills/work-order/testing/cases/150-heading-and-repair.sh
- touches: claude/skills/work-order/testing/cases/250-degrees-of-freedom.sh
- touches: claude/skills/work-order/testing/cases/260-owner-words-context.sh
- touches: claude/skills/work-order/testing/cases/270-ac-check.sh
- touches: claude/skills/work-order/testing/cases/280-approve-resolves-tools.sh
- touches: claude/workflow/timing/lib.sh
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-0272/README.md
- step: new: `--owner-words T` (repeatable, rendered verbatim under a new `## Owner words` H2 as `> T` lines) and `--context T` (repeatable, `## Context` H2); ticket.tmpl gets both sections after Problem; a `new` without --owner-words exits 3 with error `missing_owner_words`, without --context `missing_context`
- step: new and amend: `--ac-check CMD --ac-exit N [--ac-expect REGEX]` binds to the --ac given just before it; an --ac with no --ac-check exits 3 `missing_ac_check`; an empty --ac on amend (withdraw) needs no check; criteria from --from-figma (the frozen block) carry no check and are exempt; frontmatter gains `ac_checks: [{index, command, exit, expect}]`; each criterion line renders a sub-bullet 'check: CMD exit N expect /REGEX/' with CMD in backticks
- step: new and amend: `--provides T` (repeatable): a tool, script or Make target this ticket itself creates; frontmatter `provides`
- step: new verb `check --id ID [--index N]`: legal in in-progress and in-review; runs each AC check with `bash -c CMD` from the project root under `timeout 600`; pass = exit equals N and (no expect or output matches REGEX); a pass ticks the criterion through the same code path as `evidence` with observed 'check: CMD exit RC output: <first 20 lines>'; prints `AC-PASS <i>` or `AC-FAIL <i> rc=<rc>`; criteria with no ac_checks entry are skipped and stay gated by evidence; exits 0 when all pass, 1 otherwise
- step: done: runs `check` first and refuses (exit 3, `ac_check_failed <i>`) while any check fails
- step: approve: collects every backticked command in In lines starting 'step:' plus every ac_check command; for `make [-C D] [-f F] T` the target must exist in F (default D/Makefile) on `origin/main` of the project (read with `git show origin/main:<file>`) or be listed in provides; for `bash P` P must exist on origin/main or be in provides; other first words must resolve with `command -v`; any miss exits 3 `tool_missing <tool>` and the ticket stays draft; a project with no origin remote resolves against HEAD
- step: testing/assert.sh: replace line 100 (the one-line wo function) with the wo function and the comment block above it from /home/luna/.local/state/zenith/context/2026/10/20261016-064407-wo-wrapper-0e3a.sh verbatim, frontmatter excluded; it injects --owner-words 'test owner words' --context 'test context' on new when absent and '--ac-check true --ac-exit 0' after every non-empty --ac not already followed by --ac-check; drafted_project and the 20 cases that call wo stay unchanged
- step: cases/150-heading-and-repair.sh line 35 and cases/250-degrees-of-freedom.sh line 111: after --ac "it works" append '--ac-check true --ac-exit 0 --owner-words W --context C' so each refusal stays the unwired-token refusal (both call work-order.sh directly, bypassing wo)
- step: cases 260 and 270 call bash "$SKILL/scripts/work-order.sh" directly for every refusal they assert (never wo, whose defaults would mask it); 280 may use wo
- step: timing/lib.sh tm_wo: both new calls (the epic, line 47, and the child, line 52) pass --owner-words "Every DAG node, seat, job, CI run and merge records its start and end in UTC on the bus by script", --context (epic: the wo_epic_title; child: the evidence json, jq -c . <<<"$3") and '--ac-check true --ac-exit 0' after their --ac (the bottleneck ticket's AC is cut by the architect on promotion)
- step: lifecycle.md and SKILL.md: document the three flags, check, provides and the approve resolution; testing/SOP.md: one paragraph per new case and one on the wo defaults
- step: run `bash claude/skills/work-order/testing/run-tests.sh` and `make -C claude/workflow timing-test` (only these; CI runs the rest)
- step: PR body ends with 'Bump: work-order=major' (required flags break existing callers)
- tool: path:claude/skills/work-order/testing/run-tests.sh - on main; fallback: missing: stop with ENV-MISSING naming it
- tool: path:/home/luna/.local/state/zenith/context/2026/10/20261016-064407-wo-wrapper-0e3a.sh - artifact store; fallback: missing: stop with DESIGN-GAP naming it; never re-derive the function
- tool: make:claude/workflow/timing/timing.mk:timing-test - on main; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute
- tool: cmd:podman - required by run-tests.sh; fallback: missing: stop with ENV-MISSING naming it
- tool: cmd:git - on main; fallback: missing: stop with ENV-MISSING naming it
- tool: cmd:jq - on main; fallback: missing: stop with ENV-MISSING naming it

**Out - non-goals**

- work-orders/INDEX.md, the ticket file or the parent README by hand: work-order.sh writes them, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1); their close-out diff is allowed
- editing the 20 existing cases that call wo: the wo defaults cover them
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* `bash claude/skills/work-order/testing/run-tests.sh` exits 0 and its output matches /260-owner-words-context: [0-9]+ checks, 0 failed/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` bash claude/skills/work-order/testing/run-tests.sh exit 0 output: 260-owner-words-context: 13 checks, 0 failed
- [x] `AC-H2` *(human)* `bash claude/skills/work-order/testing/run-tests.sh` exits 0 and its output matches /270-ac-check: [0-9]+ checks, 0 failed/ (proof: command, exit code and output pasted by work-order.sh evidence)
  - observed `2026-10-16` bash claude/skills/work-order/testing/run-tests.sh exit 0 output: 270-ac-check: 25 checks, 0 failed
- [x] `AC-H3` *(human)* `bash claude/skills/work-order/testing/run-tests.sh` exits 0 and its output matches /280-approve-resolves-tools: [0-9]+ checks, 0 failed/ (proof: command, exit code and output pasted by work-order.sh evidence)
  - observed `2026-10-16` bash claude/skills/work-order/testing/run-tests.sh exit 0 output: 280-approve-resolves-tools: 9 checks, 0 failed
- [x] `AC-H4` *(human)* `bash claude/skills/work-order/testing/run-tests.sh` exits 0 and its output matches /150-heading-and-repair: [0-9]+ checks, 0 failed/ and /250-degrees-of-freedom: [0-9]+ checks, 0 failed/ (proof: command, exit code and output pasted by work-order.sh evidence)
  - observed `2026-10-16` bash claude/skills/work-order/testing/run-tests.sh exit 0 output: 150-heading-and-repair: 17 checks, 0 failed / 250-degrees-of-freedom: 26 checks, 0 failed
- [x] `AC-H5` *(human)* `make -C claude/workflow timing-test` exits 0 and its output matches /fail=0/ (proof: command, exit code and output pasted by work-order.sh evidence)
  - observed `2026-10-16` make -C claude/workflow timing-test exit 0 output: pass=21 fail=0
- [x] `AC-H6` *(human)* `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/|claude/skills/work-order/(scripts/work-order.sh|scripts/lib/wo.sh|references/ticket.tmpl|references/lifecycle.md|SKILL.md|testing/SOP.md|testing/assert.sh|testing/cases/(150|250|260|270|280)-[a-z-]+.sh)|claude/workflow/timing/lib.sh)$'` exits 1 and prints nothing: only In files, plus generated work-orders/ close-out files
  - observed `2026-10-16` literal command exit 0 printing only the generated ticket file work-orders/WO-20261016-0272/WO-20261016-6ef4-*.md (the AC regex anchors work-orders/ with $, so no generated file can match: ticket defect). With the prefix unanchored (^work-orders/|...) the command prints nothing and exits 1: only In files plus generated work-orders/ files changed

## Test plan


_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/skills/work-order: new flags, check verb, done gate, approve tool resolution

**Cases**

- `TP-1`
  - intent: a ticket without the owner's words loses ideas between design and build (item 30)
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0; prints `260-owner-words-context: N checks, 0 failed`: new without --owner-words exits 3 missing_owner_words
- `TP-2`
  - intent: an AC ticked by hand is a claim, not a proof
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0; prints `270-ac-check: N checks, 0 failed`: check ticks a passing AC with command, exit code and output and done refuses a failing one
- `TP-3`
  - intent: a ready ticket naming a tool that is not on main sends a seat to invent it (ORD-0555)
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0; prints `280-approve-resolves-tools: N checks, 0 failed`: approve exits 3 tool_missing for an unresolved make target and passes one listed in --provides
- `TP-4`
  - intent: the bottleneck filer must keep filing after the flags become required
  - command: `make -C claude/workflow timing-test`
  - expected: exit 0; fail=0

- `TP-5`
  - intent: the required flags must not break the 24 existing cases; their refusals still fail for the reason they name (Rule 9)
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0; every case line reads `<case>: N checks, 0 failed`, including 150-heading-and-repair and 250-degrees-of-freedom

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- skill-pr-gate runs the full work-order suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
