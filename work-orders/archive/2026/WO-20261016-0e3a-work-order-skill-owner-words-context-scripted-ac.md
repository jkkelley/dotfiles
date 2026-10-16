---
{
  "id": "WO-20261016-0e3a",
  "slug": "work-order-skill-owner-words-context-scripted-ac",
  "title": "work-order skill: owner words, context, scripted AC checks, check verb, approve resolves tools",
  "type": "feature",
  "status": "cancelled",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:05:07+00:00",
  "parent": "WO-20261016-0272",
  "branch": null,
  "pr": null,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "superseded_by": "WO-20261016-6ef4"
}
---

# WO-20261016-0e3a - work-order skill: owner words, context, scripted AC checks, check verb, approve resolves tools

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

ORD-0552 O1 (architect, relayed 2026-10-16T05:56Z): "upgrade the work-order skill upstream in dotfiles (claude/skills/work-order, bump intent in PR body): new --owner-words (verbatim, repeatable) and --context sections; every --ac takes a scripted check: --ac-check \"<command>\" --ac-exit <code> [--ac-expect <regex>]; new verb work-order.sh check --id runs every AC check, ticks evidence with the command, exit code and output automatically, and refuses done while any check fails; new tickets without owner words, context or an AC check are refused (exit 3)." ORD-0555 O2: "approve refuses a ticket whose steps or AC checks call a command or Make target that does not resolve on main (exit 3, names the missing tool)". Owner, item 30: "every acceptance criterion is a scripted check with its exit condition (command, expected exit code, expected output), run by script to tick the box, every time". The one machine caller of `new` outside the skill is claude/workflow/timing/lib.sh tm_wo, which must pass the new flags in the same PR.

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh
- touches: claude/skills/work-order/scripts/lib/wo.sh
- touches: claude/skills/work-order/references/ticket.tmpl
- touches: claude/skills/work-order/references/lifecycle.md
- touches: claude/skills/work-order/SKILL.md
- touches: claude/skills/work-order/testing/SOP.md
- touches: claude/skills/work-order/testing/cases/260-owner-words-context.sh
- touches: claude/skills/work-order/testing/cases/270-ac-check.sh
- touches: claude/skills/work-order/testing/cases/280-approve-resolves-tools.sh
- touches: claude/workflow/timing/lib.sh
- step: new: `--owner-words T` (repeatable, rendered verbatim under a new `## Owner words` H2 as `> T` lines) and `--context T` (repeatable, `## Context` H2); ticket.tmpl gets both sections after Problem; a `new` without --owner-words exits 3 with error `missing_owner_words`, without --context `missing_context`
- step: new and amend: `--ac-check CMD --ac-exit N [--ac-expect REGEX]` binds to the --ac given just before it; an --ac with no --ac-check exits 3 `missing_ac_check`; frontmatter gains `ac_checks: [{index, command, exit, expect}]`; each criterion line renders a sub-bullet `check: \`CMD\` exit N expect /REGEX/`
- step: new and amend: `--provides T` (repeatable): a tool, script or Make target this ticket itself creates; frontmatter `provides`
- step: new verb `check --id ID [--index N]`: legal in in-progress and in-review; runs each AC check with `bash -c CMD` from the project root under `timeout 600`; pass = exit equals N and (no expect or output matches REGEX); a pass ticks the criterion through the same code path as `evidence` with observed `check: CMD exit RC output: <first 20 lines>`; prints `AC-PASS <i>` or `AC-FAIL <i> rc=<rc>`; exits 0 when all pass, 1 otherwise
- step: done: runs `check` first and refuses (exit 3, `ac_check_failed <i>`) while any check fails
- step: approve: collects every backticked command in In lines starting `step:` plus every ac_check command; for `make [-C D] [-f F] T` the target must exist in F (default D/Makefile) on `origin/main` of the project (read with `git show origin/main:<file>`) or be listed in provides; for `bash P` P must exist on origin/main or be in provides; other first words must resolve with `command -v`; any miss exits 3 `tool_missing <tool>` and the ticket stays draft
- step: timing/lib.sh tm_wo: pass `--owner-words "Every DAG node, seat, job, CI run and merge records its start and end in UTC on the bus by script"`, `--context <the evidence json>` and `--ac-check "true" --ac-exit 0` (the bottleneck ticket's AC is cut by the architect on promotion)
- step: lifecycle.md and SKILL.md: document the three flags, check, provides and the approve resolution; testing/SOP.md: one paragraph per new case
- step: cases 260 270 280 in the skill's own harness; run `bash claude/skills/work-order/testing/run-tests.sh`
- step: PR body ends with `Bump: work-order=major` (required flags break existing callers)
- tool: path:claude/skills/work-order/testing/run-tests.sh - on main; fallback: missing: stop with ENV-MISSING naming it
- tool: make:claude/workflow/timing/timing.mk:timing-test - on main; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute
- tool: cmd:git - on main; fallback: missing: stop with ENV-MISSING naming it
- tool: cmd:jq - on main; fallback: missing: stop with ENV-MISSING naming it

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `bash claude/skills/work-order/testing/run-tests.sh` exits 0 and its output matches /260-owner-words-context.*ok/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* `bash claude/skills/work-order/testing/run-tests.sh` exits 0 and its output matches /270-ac-check.*ok/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H3` *(human)* `bash claude/skills/work-order/testing/run-tests.sh` exits 0 and its output matches /280-approve-resolves-tools.*ok/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H4` *(human)* `make -C claude/workflow timing-test` exits 0 and its output matches /fail=0/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/skills/work-order: new flags, check verb, done gate, approve tool resolution

**Cases**

- `TP-1`
  - intent: a ticket without the owner's words loses ideas between design and build (item 30)
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0; case 260 prints ok: new without --owner-words exits 3 missing_owner_words
- `TP-2`
  - intent: an AC ticked by hand is a claim, not a proof
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0; case 270 prints ok: check ticks a passing AC with command, exit code and output and done refuses a failing one
- `TP-3`
  - intent: a ready ticket naming a tool that is not on main sends a seat to invent it (ORD-0555)
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0; case 280 prints ok: approve exits 3 tool_missing for an unresolved make target and passes one listed in --provides
- `TP-4`
  - intent: the bottleneck filer must keep filing after the flags become required
  - command: `make -C claude/workflow timing-test`
  - expected: exit 0; fail=0

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

Cancelled `2026-10-16` - nothing shipped.

- reason: DESIGN-GAP: In list omitted testing/assert.sh and cases 150, 250; AC regexes never matched run-tests.sh output; recut
- superseded by: `WO-20261016-6ef4`

No branch, no PR and no merge commit exist for this work order.

