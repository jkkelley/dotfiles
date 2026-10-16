---
{
  "id": "WO-20261016-168e",
  "slug": "line-ops-pr-sweep-gates-make-test-pr-sweep-and-m",
  "title": "line-ops pr-sweep gates: make test-pr-sweep and make gate-uat-pr-sweep, gate-uat-pr-sweep.sh U0-U4 and docs/line-ops/test-plan-pr-sweep.md",
  "type": "test",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:54:52+00:00",
  "parent": "WO-20261016-ab87",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "ops-design1 cut for ORD-1042 G1 cluster-ops; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-c315"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "shellcheck -S warning apps/line-ops/scripts/gate-uat-pr-sweep.sh",
      "exit": 0,
      "expect": null
    },
    {
      "index": 2,
      "command": "make -n -C apps/line-ops test-pr-sweep gate-uat-pr-sweep",
      "exit": 0,
      "expect": "scripts/test-pr-sweep\\.sh[\\s\\S]*scripts/gate-uat-pr-sweep\\.sh"
    },
    {
      "index": 3,
      "command": "env APP=no-such-app-gate bash apps/line-ops/scripts/gate-uat-pr-sweep.sh",
      "exit": 2,
      "expect": "GATE-FAIL uat U0 app=no-such-app-gate absent"
    },
    {
      "index": 4,
      "command": "head -12 docs/line-ops/test-plan-pr-sweep.md | grep -c -iE 'contents|dev|uat|stable|rollback'",
      "exit": 0,
      "expect": "^[5-9]"
    },
    {
      "index": 5,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(apps/line-ops/(Makefile|scripts/gate-uat-pr-sweep\\.sh)|docs/line-ops/test-plan-pr-sweep\\.md)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "make:test-pr-sweep",
    "make:gate-uat-pr-sweep",
    "path:apps/line-ops/scripts/gate-uat-pr-sweep.sh"
  ],
  "labels": [
    "line:inbox-triage"
  ],
  "repo": "jkkelley/homelab-gitops"
}
---

# WO-20261016-168e - line-ops pr-sweep gates: make test-pr-sweep and make gate-uat-pr-sweep, gate-uat-pr-sweep.sh U0-U4 and docs/line-ops/test-plan-pr-sweep.md

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

The cluster pr-sweep needs scripted dev, UAT and stable gates (item 34) and Make targets that drive them (item 3). line-ops has gates for the deadman only (scripts/gate-dev.sh, gate-uat.sh, gate-stable.sh, docs/line-ops/test-plan-deadman.md).

## Owner words

> ORD-1042 G1 (brief BR-20261016-ops-design1): L1 cluster-ops deploy: homelab-gitops app for the bus, merge-on-green sweeps and stuck-watch as CronJobs (rule 39); secrets via external-secrets and Vault, never read a credential

> i don't like agents doing shit when i have a k8s cluster too, automate processes right away (Design principles 101 item 39)

> Have fallbacks too (item 28); Ensure that your testing is dev uat stable. (item 34); And don't ever bog the user down with notifications when testing. (item 35)

> i want work scoped so small a fuck ape could do, testing the same way with test plans and scripts (item 30)

## Context

Reuse the shape of apps/line-ops/scripts/gate-uat.sh (NS, APP, k(), fail(), a cleanup trap deleting every object labelled line-ops/gate=uat, idempotent) and docs/line-ops/test-plan-deadman.md.

apps/line-ops/Makefile: add to .PHONY and add two targets after gate-stable: 'test-pr-sweep: ## dev gate for pr-sweep.sh: podman, fakes only' running bash scripts/test-pr-sweep.sh; 'gate-uat-pr-sweep: ## UAT gate for the pr-sweep CronJob in line-ops-uat' running NS=$(or $(NS),line-ops-uat) APP=$(or $(APP),line-ops-uat) bash scripts/gate-uat-pr-sweep.sh. scripts/test-pr-sweep.sh is written by the pr-sweep.sh ticket; this ticket only adds its target.

New apps/line-ops/scripts/gate-uat-pr-sweep.sh (bash, set -euo pipefail, header like gate-uat.sh): U0 kubectl -n argocd get application $APP sync and health; absent -> 'GATE-FAIL uat U0 app=$APP absent', exit 2; then secrets github-token, ghcr-pull-secret and nats-token must exist in $NS, else 'GATE-FAIL uat U0 SECRET-MISSING <name>', exit 2 (never prints a value); cronjob pr-sweep must exist, else 'GATE-FAIL uat U0 cronjob pr-sweep absent', exit 2. U1 kubectl -n $NS create job pr-sweep-gate-$(date -u +%s) --from=cronjob/pr-sweep, label it line-ops/gate=uat, kubectl wait --for=condition=complete --timeout=300s; failed or timed out -> print the last 40 log lines and 'GATE-FAIL uat U1', exit 1. U2 its log has no line matching CLONE-FAIL or SECRET-MISSING and has one 'synced ' line per repo of the rendered config, else GATE-FAIL uat U2. U3 a nats-box Job (image docker.io/natsio/nats-box@sha256:be25666441c3aee65193aba33d60ff2f06ede7ee9eba58864324b33d7eb94fea, label line-ops/gate=uat, env NATS_TOKEN from secret nats-token key token) runs nats --server nats://nats.$NS.svc:4222 --user "$NATS_TOKEN" stream subjects LINE 'line.>' and the gate requires at least one subject starting line.pr-flow., else GATE-FAIL uat U3. U4 a second job from the cronjob completes within 300 s (idempotent re-run on the same volume), else GATE-FAIL uat U4. Success prints 'GATE-PASS uat pr-sweep U0-U4'. Testing never notifies the owner (item 35): the sweep posts no ntfy; nothing else is sent.

New docs/line-ops/test-plan-pr-sweep.md, opening with a contents list, then sections Dev, UAT, Stable, Rollback: Dev = make -C apps/line-ops test-pr-sweep, cases 1-7 of test-pr-sweep.sh; UAT = make -C apps/line-ops gate-uat-pr-sweep, U0-U4 as above, prerequisite: the owner seeded github-username and github-pat (docs/line-ops/vault-seed-line-ops.md); Stable = make -C apps/line-ops gate-stable plus kubectl -n line-ops get cronjob pr-sweep -o jsonpath='{.spec.suspend}' printing false and the newest pr-sweep job Complete; Rollback = git revert of the stable promotion commit (Argo CD re-suspends), then make -C ~/dotfiles/claude/workflow pr-flow-consume brings the local loop back in its monitor pane. One sentence per line.

## Scope

**In**

- touches: apps/line-ops/Makefile (two targets and their .PHONY names)
- touches: apps/line-ops/scripts/gate-uat-pr-sweep.sh (new, U0-U4 in Context)
- touches: docs/line-ops/test-plan-pr-sweep.md (new, as in Context)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path in dotfiles; dotfiles work-orders/INDEX.md and the epic README.md are ignored generated views
- step: clone or worktree jkkelley/homelab-gitops from origin/main into your own worktree under ~/.cache (git worktree add from ~/projects/homelab-gitops; fallback: git clone), branch feat/<slug>; every path and AC command below runs from that worktree's root
- step: write the three changes exactly as in Context
- step: run the AC checks only (U0 is exercised read-only against the real cluster with an app name that does not exist)
- step: commit 'test(line-ops): pr-sweep dev and UAT gates and test plan' with the ticket id, push, open the PR on jkkelley/homelab-gitops, leave
- tool: cmd:shellcheck - fallback: as in the pr-sweep.sh ticket, or stop with ENV-MISSING shellcheck
- tool: cmd:kubectl (cluster context of the owner's homelab) - fallback: cluster unreachable: retry 3 times 30 s apart, then stop with A2A-003 and the kubectl error; no local substitute
- tool: cmd:git, cmd:gh, cmd:jq, cmd:make - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- running U1-U4: needs the CronJob in line-ops-uat and the owner's Vault seed; the stable promotion ticket runs it
- scripts/test-pr-sweep.sh content: the pr-sweep.sh ticket
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- waiting on CI or merging: push, open the PR, write the result, leave
- reading, printing or writing any credential value: secrets reach pods only through external-secrets from Vault; the owner seeds Vault
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [free] [fixed] None declared: implement exactly as specified; stop with DESIGN-GAP before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the gate script passes shellcheck at warning
  - check: `shellcheck -S warning apps/line-ops/scripts/gate-uat-pr-sweep.sh` exit 0
- [ ] `AC-H2` *(human)* both targets exist and call their scripts
  - check: `make -n -C apps/line-ops test-pr-sweep gate-uat-pr-sweep` exit 0 expect /scripts/test-pr-sweep\.sh[\s\S]*scripts/gate-uat-pr-sweep\.sh/
- [ ] `AC-H3` *(human)* U0 refuses an absent app, read-only against the real cluster
  - check: `env APP=no-such-app-gate bash apps/line-ops/scripts/gate-uat-pr-sweep.sh` exit 2 expect /GATE-FAIL uat U0 app=no-such-app-gate absent/
- [ ] `AC-H4` *(human)* the test plan opens with its contents list and names every gate
  - check: `head -12 docs/line-ops/test-plan-pr-sweep.md | grep -c -iE 'contents|dev|uat|stable|rollback'` exit 0 expect /^[5-9]/
- [ ] `AC-H5` *(human)* the diff holds only In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(apps/line-ops/(Makefile|scripts/gate-uat-pr-sweep\.sh)|docs/line-ops/test-plan-pr-sweep\.md)$'` exit 1

## Test plan

```sh
{"scope":"the gate script and targets, exercised up to U0 without touching the cluster","cases":[{"id":"TP-1","intent":"a gate that cannot refuse is no gate: U0 must stop on a missing app before creating anything","command":"APP=no-such-app-gate bash apps/line-ops/scripts/gate-uat-pr-sweep.sh","expected":"exit 2, GATE-FAIL uat U0 app=no-such-app-gate absent"},{"id":"TP-2","intent":"Make drives every gate (item 3)","command":"make -n -C apps/line-ops test-pr-sweep gate-uat-pr-sweep","expected":"both script paths printed"}],"isolation":{"runtime":"podman","image":"none: kubectl read-only and make -n"},"out_of_scope":["U1-U4: the stable promotion ticket"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
