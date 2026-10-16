---
{
  "id": "WO-20261016-f228",
  "slug": "line-watch-alerts-blocked-matches-only-the-promp",
  "title": "line-watch alerts: BLOCKED matches only the prompt box, DISCOVERY flags an unlabelled claude pane",
  "type": "bug",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:27:53+00:00",
  "parent": "WO-20261016-4b6c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-d358"
  ]
}
---

# WO-20261016-f228 - line-watch alerts: BLOCKED matches only the prompt box, DISCOVERY flags an unlabelled claude pane

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

F15 evidence (orchestrator 2026-10-16T06:27Z): "LW-ALERT-BLOCKED fired on infra-design at 06:23Z while it was working; the alert text is line-watch.sh line 190 source shown in its pane (grep for Do you want|Enter to matched code on screen, not a prompt). Fold into the line-watch alert ticket: match only the prompt box region, not scrollback." Cause: claude/workflow/bin/line-watch.sh:189-190 greps the last 15 pane lines for `Do you want|Enter to confirm|Esc to cancel`, so any of those words printed as output (code, diffs, logs) reads as a dialog. ORD-0606 D4: "Prevention: line-sweep raises LW-ALERT-DISCOVERY for any claude pane in a line workspace without a label". Evidence: wDD:pD and wDD:pE ran unlabelled outside the grid; adopt_named (line-watch.sh:209) adopts named panes only.

## Scope

**In**

- touches: claude/workflow/bin/line-watch.sh
- touches: claude/workflow/tests/unit/test_line_watch.sh
- touches: claude/workflow/config/line-watch.json
- touches: claude/workflow/tests/unit/fixtures/pane-dialog.txt
- touches: claude/workflow/tests/unit/fixtures/pane-code-on-screen.txt
- step: BLOCKED: replace the tail -n 15 grep with a prompt-box function: take the lines from the last line starting with `╭` (box top) to the next line starting with `╰` (box bottom) inside the last 25 lines; alert only when that box contains `Do you want` and a numbered option line matching `^[│ ]*(❯ )?[0-9]+\. ` ; a pane with a spinner line (stuck-watch config pane_look.spinner_re) is never BLOCKED
- step: breadcrumb at the change: F15 06:23Z false alert on infra-design, why the box region (dialogs are boxed, output is not), rejected: a longer phrase list, which still matches code on screen
- step: DISCOVERY: after adopt_named each tick, for every `herdr agent list` entry in WS whose agent is claude, with no name and no label (or label `free R.C`), publish and log `LW-ALERT-DISCOVERY\t<pane> unlabelled claude pane (cwd <cwd>)` once per pane (dedupe in the sweep state)
- step: config/line-watch.json: add LW-ALERT-DISCOVERY to the alert codes beside LW-PERM-MISSING
- step: fixtures: pane-dialog.txt (a real permission box), pane-code-on-screen.txt (this line-watch.sh source and a spinner on screen)
- step: run `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
- tool: path:claude/workflow/tests/container/Containerfile - on main; fallback: no fallback permitted (dotfiles Rule 14, never the host): podman or the image missing stops the node with ENV-MISSING podman
- tool: path:claude/workflow/bin/line-watch.sh - on main; fallback: missing: stop with ENV-MISSING naming it

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'` exits 0 and its output matches /ok code on screen with Do you want is not BLOCKED/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'` exits 0 and its output matches /ok a permission box raises LW-ALERT-BLOCKED/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H3` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'` exits 0 and its output matches /ok an unlabelled claude pane raises LW-ALERT-DISCOVERY once/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

line-watch.sh BLOCKED prompt-box match and DISCOVERY alert against the stub herdr and fixtures

**Cases**

- `TP-1`
  - intent: a false BLOCKED on a working seat pulls the architect for nothing (F15, 06:23Z)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
  - expected: exit 0; prints `ok  code on screen with Do you want is not BLOCKED`
- `TP-2`
  - intent: a real dialog must still alert, or a seat waits forever
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
  - expected: exit 0; prints `ok  a permission box raises LW-ALERT-BLOCKED`
- `TP-3`
  - intent: a seat outside the grid is unwatched (ORD-0606 D4)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
  - expected: exit 0; prints `ok  an unlabelled claude pane raises LW-ALERT-DISCOVERY once`
- `TP-4`
  - intent: fallback path: a labelled or named pane raises no discovery alert
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
  - expected: exit 0; prints `ok  a labelled seat raises no discovery alert`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full workflow suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
