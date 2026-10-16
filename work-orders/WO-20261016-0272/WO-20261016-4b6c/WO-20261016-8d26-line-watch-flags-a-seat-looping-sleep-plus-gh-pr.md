---
{
  "id": "WO-20261016-8d26",
  "slug": "line-watch-flags-a-seat-looping-sleep-plus-gh-pr",
  "title": "line-watch flags a seat looping sleep plus gh pr or gh run as LW-ALERT-BLOCKED code CI-POLL",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:33:20+00:00",
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
  "depends_on": [
    "WO-20261016-f228"
  ],
  "blocks": [
    "WO-20261016-b639"
  ]
}
---

# WO-20261016-8d26 - line-watch flags a seat looping sleep plus gh pr or gh run as LW-ALERT-BLOCKED code CI-POLL

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

ORD-0628 P1 prevention (orchestrator 2026-10-16T06:31Z): "a2a-guard or stuck-watch flags any seat process loop of sleep plus gh pr or gh run as LW-ALERT-BLOCKED code CI-POLL. Cut the ticket." ORD-0542 O2: "push, open the PR, write the result, leave; never wait on CI, never merge". Inventory: LW-ALERT-BLOCKED is emitted only by claude/workflow/bin/line-watch.sh check_seat (line 174), so the check lands there; stuck-watch emits STK-* codes only. herdr pane list carries no pid, but every process a seat starts inherits HERDR_PANE_ID in /proc/<pid>/environ, which maps a process to its pane. Same files as WO-20261016-f228, so this ticket waits on it (item 19).

## Scope

**In**

- touches: claude/workflow/bin/line-watch.sh
- touches: claude/workflow/config/line-watch.json
- touches: claude/workflow/tests/unit/test_line_watch.sh
- touches: claude/workflow/tests/unit/fixtures/ps-ci-poll.txt
- touches: claude/workflow/tests/unit/fixtures/ps-no-poll.txt
- step: config/line-watch.json: add `"ci_poll": {"sleep_re": "^sleep( |$)", "poll_re": "gh (pr|run) ", "depth": 8}`
- step: line-watch.sh: add `ci_poll_of <pane>`: list processes with `${LW_PS:-ps -eo pid=,ppid=,args=}`; for each pid whose args match sleep_re, read HERDR_PANE_ID from `${LW_PROC:-/proc}/<pid>/environ` (tr '\0' '\n'); when it equals <pane>, walk ppid up at most depth steps and print `CI-POLL pid <ancestor pid>: <ancestor args cut to 100>` for the first ancestor whose args match poll_re; print nothing otherwise
- step: check_seat: after the BLOCKED dialog check and before the idle check, `p="$(ci_poll_of "$pane")"; [ -n "$p" ] && { printf 'LW-ALERT-BLOCKED\t%s' "$p"; return; }`; update the precedence comment to: exited, done, blocked, ci-poll, idle
- step: breadcrumb at ci_poll_of: ORD-0628 P1 and ORD-0542 O2 quoted, why the environ map (herdr pane list has no pid), rejected: matching pane text, which reads code on screen as a loop (F15)
- step: fixtures: ps-ci-poll.txt (a claude pid, its `zsh -c ... while :; do gh pr checks 194; sleep 30; done` child, and that child's `sleep 30`), ps-no-poll.txt (a claude pid with a plain `sleep 5` child under `zsh -c sleep 5`); test_line_watch.sh builds a fake proc root in $T with environ files carrying HERDR_PANE_ID and sets LW_PS=`cat <fixture>` and LW_PROC=$T/proc
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

- [ ] `AC-H1` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'` exits 0 and its output matches /ok a sleep plus gh pr loop raises LW-ALERT-BLOCKED CI-POLL/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'` exits 0 and its output matches /ok a plain sleep raises no CI-POLL/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H3` *(human)* `jq -r .ci_poll.poll_re claude/workflow/config/line-watch.json` exits 0 and its output matches /gh \(pr\|run\) / (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

line-watch.sh CI-POLL process check against ps fixtures and a fake proc root

**Cases**

- `TP-1`
  - intent: a seat polling CI blocks the line and breaks ORD-0542 O2 (ORD-0628 P1)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
  - expected: exit 0; prints `ok  a sleep plus gh pr loop raises LW-ALERT-BLOCKED CI-POLL`
- `TP-2`
  - intent: gh run in the loop is caught the same way
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
  - expected: exit 0; prints `ok  a sleep plus gh run loop raises LW-ALERT-BLOCKED CI-POLL`
- `TP-3`
  - intent: a plain sleep is not a CI poll, or every short wait pages the orchestrator
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
  - expected: exit 0; prints `ok  a plain sleep raises no CI-POLL`
- `TP-4`
  - intent: fallback path: ps or /proc unreadable leaves the seat unflagged and the sweep running
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
  - expected: exit 0; prints `ok  unreadable proc raises no CI-POLL and the sweep continues`

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
