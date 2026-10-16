---
{
  "id": "WO-20261016-7ca5",
  "slug": "timed-run-every-target-of-claude-workflow-mk-res",
  "title": "timed-run: every target of claude/workflow/mk/resources.mk runs through the timing wrapper",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:05:55+00:00",
  "parent": "WO-20261016-af17",
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
    "WO-20261016-8590"
  ]
}
---

# WO-20261016-7ca5 - timed-run: every target of claude/workflow/mk/resources.mk runs through the timing wrapper

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

Item 37 amended, owner 2026-10-16 UTC: "time out everything logically, you'll ID the bottlenecks, and it'll get things thru faster" - "One shared wrapper script does the timing, the timeout and the bus events for every Make target, so no step can run untimed." stuck-watch brief v2: one work order per Makefile owner (resources) to route its targets through claude/workflow/bin/timed-run.sh.

## Scope

**In**

- touches: claude/workflow/mk/resources.mk
- step: near the top of claude/workflow/mk/resources.mk: `TIMED = bash $(abspath bin/timed-run.sh) --node $@ --kind make --` with a breadcrumb comment (item 37; a down bus only warns; rejected: a SHELL override, which also times recipe-internal shell calls)
- step: prefix the command line of every target's recipe that runs a script, podman or make with `$(TIMED) ` (after any leading `@`); leave `help` and recipes that only echo or check $(call need,...) unwrapped
- step: run `make -n -C $(dirname claude/workflow/mk/resources.mk) <each wrapped target> <its required VAR=x>` and check each prints timed-run.sh
- step: run the owner's relevant test target once (`make -C claude/workflow test` for workflow files, `make rolodex-test` for the root)
- tool: path:claude/workflow/bin/timed-run.sh - on main; fallback: bus down: timed-run warns `WARN bus unreachable` and the step runs with its own exit code (tm_event); covered by the bus-down case
- tool: path:claude/workflow/tests/container/Containerfile - on main; fallback: no fallback permitted (dotfiles Rule 14, never the host): podman or the image missing stops the node with ENV-MISSING podman

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `grep -c '$(TIMED)' claude/workflow/mk/resources.mk` equals the number of wrapped targets listed in the PR body (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* `make -n` of every wrapped target of claude/workflow/mk/resources.mk prints `timed-run.sh --node <target> --kind make` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H3` *(human)* with the bus down (no NATS on the port) a wrapped target exits with its own exit code and prints only a WARN line (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/mk/resources.mk recipes routed through timed-run.sh

**Cases**

- `TP-1`
  - intent: an untimed target is an invisible bottleneck (item 37)
  - command: `grep -cE '^[[:space:]]+@?[$][(]TIMED[)] ' claude/workflow/mk/resources.mk`
  - expected: exit 0; prints the wrapped-target count listed in the PR body
- `TP-2`
  - intent: the bus must never be a build dependency
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'SW_NATS_URL=127.0.0.1:1 bash claude/workflow/bin/timed-run.sh --node probe --kind make -- true; echo rc=$?'`
  - expected: prints a `WARN bus unreachable` line and rc=0

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the owner's full suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
