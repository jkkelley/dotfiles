---
{
  "id": "WO-20261016-ddf1",
  "slug": "line-ops-pr-sweep-gates-recut-of-wo-20261016-168",
  "title": "line-ops pr-sweep gates, recut of WO-20261016-168e: finish homelab-gitops PR 105 with U2 counting the repos of dotfiles pr-flow.json, under a runnable markdown test plan",
  "type": "test",
  "status": "in-review",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:33:04+00:00",
  "parent": "WO-20261016-ab87",
  "branch": "feat/ddf1-line-ops-pr-sweep-gates-recut-of-wo-20261016-168",
  "pr": 105,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design18 recut of 168e for DESIGN-GAP F48; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-c315",
    "WO-20261016-a1ca"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "podman run --rm -v \"$PWD\":/mnt:ro,Z -w /mnt docker.io/koalaman/shellcheck@sha256:0fa384f2a6171aef8aab2999a531c8c8158727d54a8f20157a5c3c51a734d6b2 -S warning apps/line-ops/scripts/gate-uat-pr-sweep.sh",
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
      "command": "podman run --rm -v \"$PWD\":/w:ro,Z -v \"$HOME/.kube\":/root/.kube:ro,Z -w /w -e APP=no-such-app-gate docker.io/alpine/k8s@sha256:9c4976d47656d78cf53a92b0203fc54ac45eae18a2b45001ac221c27da4c8036 bash apps/line-ops/scripts/gate-uat-pr-sweep.sh",
      "exit": 2,
      "expect": "GATE-FAIL uat U0 app=no-such-app-gate absent"
    },
    {
      "index": 4,
      "command": "grep -c 'pr-flow/config/pr-flow.json' apps/line-ops/scripts/gate-uat-pr-sweep.sh",
      "exit": 0,
      "expect": "^[1-9]"
    },
    {
      "index": 5,
      "command": "grep -c 'pr-sweep-config' apps/line-ops/scripts/gate-uat-pr-sweep.sh",
      "exit": 1,
      "expect": "^0$"
    },
    {
      "index": 6,
      "command": "grep -c -iE 'contents|dev|uat|stable|rollback|pr-flow\\.json' docs/line-ops/test-plan-pr-sweep.md",
      "exit": 0,
      "expect": "^([6-9]|[1-9][0-9])"
    },
    {
      "index": 7,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(apps/line-ops/(Makefile|scripts/gate-uat-pr-sweep\\.sh)|docs/line-ops/test-plan-pr-sweep\\.md)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "apps/line-ops/scripts/gate-uat-pr-sweep.sh",
    "make:test-pr-sweep",
    "make:gate-uat-pr-sweep"
  ],
  "labels": [
    "line:inbox-triage"
  ],
  "repo": "jkkelley/homelab-gitops"
}
---

# WO-20261016-ddf1 - line-ops pr-sweep gates, recut of WO-20261016-168e: finish homelab-gitops PR 105 with U2 counting the repos of dotfiles pr-flow.json, under a runnable markdown test plan

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

WO-20261016-168e cannot start: its ## Test plan is one JSON line and wo_test_plan_json (claude/skills/work-order/scripts/lib/wo.sh:320) reads only the markdown labels of claude/workflow/templates/test-plan.md, so start refuses test_plan_missing (F48 class; seats/lo-168e.result.json facts.gap). Its code already sits in homelab-gitops PR 105 (branch feat/line-ops-pr-sweep-gates, head 2566e29), where gate-uat-pr-sweep.sh lines 50-51 count repos from a configmap pr-sweep-config* key REPOS that nothing creates: the seat assumed that name, it is not in the ticket. pr-sweep.sh (homelab-gitops PR 106, steps 4-5) syncs one repo per key of dotfiles claude/workflow/pr-flow/config/pr-flow.json .repos.

## Owner words

> DESIGN-GAP 168e: ## Test plan is one JSON line; wo.sh:320 wo_test_plan_json needs the markdown template, so start fails test_plan_missing (F48 class). Code PR homelab-gitops#105 open; ticket never started. Also note lo-168e assumed configmap name pr-sweep-config* for U2 (not in ticket). (orchestrator brief BR-20261016-infra-design18)

> Ensure that your testing is dev uat stable. (Design principles 101 item 34)

> every node has what it fucking needs up front, not later, design it that way (Design principles 101 item 30)

## Context

Order brief BR-20261016-infra-design18. Everything WO-20261016-168e specified (its Context: Makefile targets test-pr-sweep and gate-uat-pr-sweep, gate-uat-pr-sweep.sh U0-U4, docs/line-ops/test-plan-pr-sweep.md with Dev, UAT, Stable, Rollback) is already on PR 105 and stays as it is, except the two changes below; 168e is cancelled in the design PR that cut this ticket. The generator side (new, amend and approve refusing a one-line plan) is WO-20261016-3d4d, already ready; nothing is recut for it.

Change 1, apps/line-ops/scripts/gate-uat-pr-sweep.sh: replace the two lines under the comment 'Repo count comes from the rendered config (configmap pr-sweep-config*, key REPOS, whitespace separated).' and that comment with: a comment 'Repo count is the number of keys of dotfiles claude/workflow/pr-flow/config/pr-flow.json .repos, the list pr-sweep.sh syncs (its step 5); EXPECT_REPOS=N overrides it. Rejected: a configmap - nothing renders one (WO-20261016-168e recut).'; then repos="${EXPECT_REPOS:-}"; when empty, repos=$(git -C "${DOTFILES:-$HOME/dotfiles}" show origin/main:claude/workflow/pr-flow/config/pr-flow.json 2>/dev/null | jq '.repos | keys | length' 2>/dev/null || true); when still empty or 0: echo 'GATE-FAIL uat U2 config-unknown: set DOTFILES or EXPECT_REPOS' and exit 2. The pass condition on the next line becomes [ "$synced" -eq "$repos" ] || fail "U2 synced=$synced repos=$repos"; the echo after it stays. Add DOTFILES and EXPECT_REPOS to the script header's inputs line. Change 2, docs/line-ops/test-plan-pr-sweep.md, UAT section: one new line 'U2 expects one synced line per key of dotfiles pr-flow.json .repos (DOTFILES=<dotfiles clone>, or EXPECT_REPOS=N).'

Lifecycle, because the code lives in homelab-gitops and check and done --code-dir (WO-20261016-1099) are not on main yet: start this ticket in your own dotfiles worktree; make the two changes in a homelab-gitops worktree of the PR branch; run each AC check from that worktree's root and record each pass with bash claude/skills/work-order/scripts/work-order.sh evidence --id THIS-TICKET-ID --index N --observed '<command> exit <rc>' run from the dotfiles worktree; submit --id THIS-TICKET-ID --pr 105; commit the generated ticket move on a dotfiles branch chore/wo-<id hex>-lo-gates, open that PR and leave. done runs later in the F44 close-out ticket with --code-dir. THIS-TICKET-ID is this ticket's own id, the .id in its frontmatter.

## Scope

**In**

- touches: apps/line-ops/scripts/gate-uat-pr-sweep.sh (U2 repo count lines, their comment and the header inputs line, in PR 105)
- touches: docs/line-ops/test-plan-pr-sweep.md (one UAT line, in PR 105)
- touches (already on PR 105, unchanged): apps/line-ops/Makefile
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: `git -C $HOME/projects/homelab-gitops fetch -q origin` then `git -C $HOME/projects/homelab-gitops worktree add $HOME/.cache/wt-lo-gates feat/line-ops-pr-sweep-gates` (fallback: the branch is checked out elsewhere: git worktree add --detach then git switch -c from origin/feat/line-ops-pr-sweep-gates, or git clone); every AC command runs from that worktree root
- step: make the two changes in Context, commit 'test(line-ops): U2 counts the repos of dotfiles pr-flow.json' with the ticket id, push to feat/line-ops-pr-sweep-gates (PR 105)
- step: the lifecycle in Context: start, evidence per passing AC, submit --pr 105, a dotfiles PR with the generated ticket move, leave
- tool: cmd:podman with images docker.io/koalaman/shellcheck@sha256:0fa384f2a6171aef8aab2999a531c8c8158727d54a8f20157a5c3c51a734d6b2 (shellcheck v0.10.0) and docker.io/alpine/k8s@sha256:9c4976d47656d78cf53a92b0203fc54ac45eae18a2b45001ac221c27da4c8036 (alpine/k8s 1.31.4) - fallback: pull fails: retry 3 times, then stop with ENV-MISSING podman
- tool: cmd:kubectl through the alpine/k8s image with ~/.kube mounted read-only - fallback: cluster unreachable: retry 3 times 30 s apart, then stop with A2A-003 and the kubectl error; no local substitute
- tool: script:claude/skills/work-order/scripts/work-order.sh - on main; fallback: a verb refuses: stop with its status code and output, never edit a ticket by hand
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- running U1-U4: they need the CronJob in line-ops-uat and the owner's Vault seed; WO-20261016-c315 runs them
- work-order.sh done: the F44 close-out ticket runs it with --code-dir after WO-20261016-1099 merges
- a new homelab-gitops PR or branch: the work rides PR 105
- reading, printing or writing any credential value
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the gate script passes shellcheck at warning
  - observed `2026-10-16` shellcheck -S warning gate-uat-pr-sweep.sh exit 0
  - check: `podman run --rm -v "$PWD":/mnt:ro,Z -w /mnt docker.io/koalaman/shellcheck@sha256:0fa384f2a6171aef8aab2999a531c8c8158727d54a8f20157a5c3c51a734d6b2 -S warning apps/line-ops/scripts/gate-uat-pr-sweep.sh` exit 0
- [x] `AC-H2` *(human)* both Make targets exist and call their scripts
  - observed `2026-10-16` make -n -C apps/line-ops test-pr-sweep gate-uat-pr-sweep exit 0
  - check: `make -n -C apps/line-ops test-pr-sweep gate-uat-pr-sweep` exit 0 expect /scripts/test-pr-sweep\.sh[\s\S]*scripts/gate-uat-pr-sweep\.sh/
- [x] `AC-H3` *(human)* U0 refuses an absent app, read-only against the real cluster
  - observed `2026-10-16` gate-uat-pr-sweep.sh APP=no-such-app-gate exit 2: GATE-FAIL uat U0 app=no-such-app-gate absent
  - check: `podman run --rm -v "$PWD":/w:ro,Z -v "$HOME/.kube":/root/.kube:ro,Z -w /w -e APP=no-such-app-gate docker.io/alpine/k8s@sha256:9c4976d47656d78cf53a92b0203fc54ac45eae18a2b45001ac221c27da4c8036 bash apps/line-ops/scripts/gate-uat-pr-sweep.sh` exit 2 expect /GATE-FAIL uat U0 app=no-such-app-gate absent/
- [x] `AC-H4` *(human)* U2 counts the repos of dotfiles pr-flow.json
  - observed `2026-10-16` grep -c pr-flow/config/pr-flow.json exit 0: 2
  - check: `grep -c 'pr-flow/config/pr-flow.json' apps/line-ops/scripts/gate-uat-pr-sweep.sh` exit 0 expect /^[1-9]/
- [x] `AC-H5` *(human)* no configmap name is assumed any more
  - observed `2026-10-16` grep -c pr-sweep-config exit 1: 0
  - check: `grep -c 'pr-sweep-config' apps/line-ops/scripts/gate-uat-pr-sweep.sh` exit 1 expect /^0$/
- [x] `AC-H6` *(human)* the test plan opens with its contents list, names every gate and the U2 repo source
  - observed `2026-10-16` grep -c test-plan-pr-sweep.md exit 0: 14
  - check: `grep -c -iE 'contents|dev|uat|stable|rollback|pr-flow\.json' docs/line-ops/test-plan-pr-sweep.md` exit 0 expect /^([6-9]|[1-9][0-9])/
- [x] `AC-H7` *(human)* the PR diff holds only In files
  - observed `2026-10-16` git diff --name-only origin/main...HEAD | grep -vE In-files exit 1
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(apps/line-ops/(Makefile|scripts/gate-uat-pr-sweep\.sh)|docs/line-ops/test-plan-pr-sweep\.md)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

apps/line-ops/scripts/gate-uat-pr-sweep.sh on homelab-gitops PR 105, run from that worktree root, U0 only (U1-U4 need the CronJob in line-ops-uat)

**Cases**

- `TP-1`
  - intent: a gate script that fails shellcheck hides the error that would let a broken sweep pass UAT
  - command: `podman run --rm -v "$PWD":/mnt:ro,Z -w /mnt docker.io/koalaman/shellcheck@sha256:0fa384f2a6171aef8aab2999a531c8c8158727d54a8f20157a5c3c51a734d6b2 -S warning apps/line-ops/scripts/gate-uat-pr-sweep.sh`
  - expected: exit 0, no output
- `TP-2`
  - intent: a gate that cannot refuse is no gate: U0 must stop on a missing app before it creates any object
  - command: `podman run --rm -v "$PWD":/w:ro,Z -v "$HOME/.kube":/root/.kube:ro,Z -w /w -e APP=no-such-app-gate docker.io/alpine/k8s@sha256:9c4976d47656d78cf53a92b0203fc54ac45eae18a2b45001ac221c27da4c8036 bash apps/line-ops/scripts/gate-uat-pr-sweep.sh`
  - expected: exit 2 and the line GATE-FAIL uat U0 app=no-such-app-gate absent
- `TP-3`
  - intent: U2 must count the repos pr-sweep.sh really syncs (dotfiles pr-flow.json .repos), not a configmap nothing creates
  - command: `grep -c pr-flow/config/pr-flow.json apps/line-ops/scripts/gate-uat-pr-sweep.sh`
  - expected: exit 0 and 1

**Isolation**

- runtime: podman
- image: `docker.io/alpine/k8s@sha256:9c4976d47656d78cf53a92b0203fc54ac45eae18a2b45001ac221c27da4c8036` (alpine/k8s:1.31.4)

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
