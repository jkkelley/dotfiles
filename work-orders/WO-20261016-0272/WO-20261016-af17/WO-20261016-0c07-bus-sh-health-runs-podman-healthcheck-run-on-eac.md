---
{
  "id": "WO-20261016-0c07",
  "slug": "bus-sh-health-runs-podman-healthcheck-run-on-eac",
  "title": "bus.sh health runs podman healthcheck run on each configured container and publishes HEALTHY, UNHEALTHY or HEALTHCHECK-NOT-RUN; bus.sh status and the bus monitor report it each tick",
  "type": "bug",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:39:48+00:00",
  "parent": "WO-20261016-af17",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design15 cut for ORD-0830 RR-orch-14 F35; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-2092"
  ],
  "blocks": [
    "WO-20261016-5ee5"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_bus_health.sh",
      "exit": 0,
      "expect": "^ok "
    },
    {
      "index": 2,
      "command": "jq -r '.monitors[] | select(.name==\"bus\") | .command' claude/workflow/config/monitors.json",
      "exit": 0,
      "expect": "bus-health-loop"
    },
    {
      "index": 3,
      "command": "make -C claude/workflow -n bus-health bus-health-loop",
      "exit": 0,
      "expect": "bus.sh health"
    },
    {
      "index": 4,
      "command": "grep -c 'systemd' claude/workflow/bin/bus.sh",
      "exit": 0,
      "expect": "^[1-9]"
    },
    {
      "index": 5,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 6,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/bus\\.sh|config/(line-watch|monitors)\\.json|mk/line-watch\\.mk|tests/unit/test_bus_health\\.sh))$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "make:bus-health",
    "make:bus-health-loop",
    "script:claude/workflow/tests/unit/test_bus_health.sh"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-0c07 - bus.sh health runs podman healthcheck run on each configured container and publishes HEALTHY, UNHEALTHY or HEALTHCHECK-NOT-RUN; bus.sh status and the bus monitor report it each tick

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

podman schedules a container healthcheck with a transient systemd timer, and on this WSL host no such timer exists, so zenith-nats ran its check once since 04:43Z (interval 30s) and State.Health never moves: bus.sh status prints that stale value (a fresh container reads starting forever, a dead server keeps its last healthy). Evidence ~/.local/state/zenith/evidence/2026/10/20261016-103641-podman-health-no-timer.txt (runs=1, 0 timers for the container id)

## Owner words

> ORD-1020 H1 ... health reflects reality; bus.sh status reports UNHEALTHY or HEALTHCHECK-NOT-RUN instead of a stale starting. Breadcrumb at the fix site naming the systemd-timer cause. Test: a container whose check fails reads unhealthy within one tick. (orchestrator brief BR-20261016-infra-design15)

> One pattern for everything that watches ... is a script behind a Make target, runs in a labeled pane of the line's monitoring tab, publishes to the bus (Design principles 101 item 27)

## Context

Order brief BR-20261016-infra-design15, ORD-1020 H1. Edit 1, config/line-watch.json: add .health = {"containers": ["zenith-nats"], "interval": 30} with a $comment saying any podman service with a healthcheck is one more containers entry. Edit 2, bin/bus.sh: new function health_of <name> that runs 'podman healthcheck run <name>' and maps rc 0 -> HEALTHY, rc 1 -> UNHEALTHY, a container absent from 'podman container exists' -> ABSENT, any other rc (125: no healthcheck defined) -> HEALTHCHECK-NOT-RUN; new verb 'health' that, for each name in .health.containers, prints '<code> <name>' and publishes '{"at":<UTC>,"container":<name>,"status_code":<code>}' to subject line.${LINE:-system}.health.<name> via the existing pub path (a failed publish prints BUS-PUB-FAILED and does not change the exit), exiting 0 when all are HEALTHY and 3 otherwise; new verb 'health-loop' that runs health every .health.interval seconds forever and never exits on a non-zero tick; the status verb's 'container' line keeps State.Status but its health= comes from health_of, never from State.Health; usage lines 10-13 list health and health-loop. Breadcrumb comment above health_of naming the systemd-timer cause, the evidence path, the rejected alternative (a systemd --user timer per container: absent on this host, which is the bug) and the cost (one podman exec per container per tick). Edit 3, mk/line-watch.mk: targets bus-health and bus-health-loop (TIMED like bus-status) added to .PHONY. Edit 4, config/monitors.json bus entry command (line 11) becomes 'make -C ${repo} bus-up && make -C ${repo} bus-health-loop' (bus-logs stays a target). Edit 5, new tests/unit/test_bus_health.sh in the test_bus_bind.sh shape (stub podman and BUS_NATS on PATH): healthcheck rc 1 -> 'UNHEALTHY zenith-nats', exit 3 and one pub of status_code UNHEALTHY within one health call; rc 0 -> HEALTHY exit 0; rc 125 -> HEALTHCHECK-NOT-RUN; container missing -> ABSENT; status prints health=UNHEALTHY when the stub inspect says healthy but healthcheck run fails.

## Scope

**In**

- touches: claude/workflow/bin/bus.sh (health_of, health and health-loop verbs, status health field, usage lines, breadcrumb)
- touches: claude/workflow/config/line-watch.json (.health block only)
- touches: claude/workflow/mk/line-watch.mk (bus-health, bus-health-loop, .PHONY)
- touches: claude/workflow/config/monitors.json (bus entry command line only)
- touches: claude/workflow/tests/unit/test_bus_health.sh (new)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree after WO-20261016-2092 merged, never the ~/dotfiles primary clone
- step: make exactly the five edits in Context
- step: run the AC checks only; CI runs the rest
- step: commit 'fix(workflow): bus health runs the podman healthcheck each tick' with the ticket id; no Bump trailer
- tool: localhost/dotfiles-workflow-test:1 image - fallback: missing: make -C claude/workflow image, then retry once; build fails: stop with ENV-MISSING podman
- tool: make:claude/workflow/mk/line-watch.mk:bus-status - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- bus.sh up, bind or file mode: WO-20261016-2092 owns them
- a new monitors.json slot or entry: the bus entry's command only
- a systemd --user timer or unit for healthchecks
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* a container whose check fails reads UNHEALTHY within one tick, and every code is mapped
  - check: `podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_bus_health.sh` exit 0 expect /^ok/
- [ ] `AC-H2` *(human)* the bus monitor runs the health loop
  - check: `jq -r '.monitors[] | select(.name=="bus") | .command' claude/workflow/config/monitors.json` exit 0 expect /bus-health-loop/
- [ ] `AC-H3` *(human)* the Make targets exist
  - check: `make -C claude/workflow -n bus-health bus-health-loop` exit 0 expect /bus.sh health/
- [ ] `AC-H4` *(human)* the breadcrumb names the systemd timer cause
  - check: `grep -c 'systemd' claude/workflow/bin/bus.sh` exit 0 expect /^[1-9]/
- [ ] `AC-H5` *(human)* rolodex pointers hold
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H6` *(human)* the diff holds only the In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/bus\.sh|config/(line-watch|monitors)\.json|mk/line-watch\.mk|tests/unit/test_bus_health\.sh))$'` exit 1

## Test plan

```sh
{"scope":"bus health tick","cases":[{"id":"TP-1","intent":"dev gate: a failing healthcheck reads UNHEALTHY in one call, hermetic stubs","command":"podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_bus_health.sh","expected":"exit 0; ok lines for UNHEALTHY, HEALTHY, HEALTHCHECK-NOT-RUN, ABSENT, status"},{"id":"TP-2","intent":"UAT gate: a real container with a failing check reads UNHEALTHY","command":"bash -c 'podman run -d --name zh-test --health-cmd false --health-interval 1h docker.io/library/nats@sha256:2ae57dfba3063d5e25fecb75256118c0882a1a2d2cf7d0fba17a7c701df956f6 >/dev/null; c=$(mktemp); sed s/zenith-nats/zh-test/g claude/workflow/config/line-watch.json > $c; LW_BUS=$c LINE=test bash claude/workflow/bin/bus.sh health; rc=$?; podman rm -f zh-test >/dev/null; rm -f $c; exit $rc'","expected":"exit 3; prints UNHEALTHY zh-test; publishes to line.test.health.zh-test, never an owner channel"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["workflow full suite: CI runs it"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
