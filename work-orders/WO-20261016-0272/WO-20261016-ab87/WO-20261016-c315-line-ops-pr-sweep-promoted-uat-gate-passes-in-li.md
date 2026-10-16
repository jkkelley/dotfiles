---
{
  "id": "WO-20261016-c315",
  "slug": "line-ops-pr-sweep-promoted-uat-gate-passes-in-li",
  "title": "line-ops pr-sweep promoted: UAT gate passes in line-ops-uat, stable unsuspends CronJob pr-sweep, the local pr-flow loop stops",
  "type": "chore",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:55:41+00:00",
  "parent": "WO-20261016-ab87",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-03ef",
    "WO-20261016-ddf1",
    "WO-20261016-a1ca"
  ],
  "blocks": [
    "WO-20261016-0a4c"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C apps/line-ops gate-uat-pr-sweep",
      "exit": 0,
      "expect": "GATE-PASS uat pr-sweep U0-U4"
    },
    {
      "index": 2,
      "command": "test $(kubectl kustomize apps/line-ops/overlays/stable | grep -c '^  suspend: false$') = 1 && test $(kubectl kustomize apps/line-ops/overlays/uat | grep -c '^  suspend: true$') = 1 && echo PROMOTE-OK",
      "exit": 0,
      "expect": "PROMOTE-OK"
    },
    {
      "index": 3,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(apps/line-ops/overlays/stable/kustomization\\.yaml)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ],
  "repo": "jkkelley/homelab-gitops"
}
---

# WO-20261016-c315 - line-ops pr-sweep promoted: UAT gate passes in line-ops-uat, stable unsuspends CronJob pr-sweep, the local pr-flow loop stops

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

Item 34: the cluster sweep reaches stable only after its UAT gate passes; while both the local loop and the cluster CronJob run they keep separate post-once ledgers and double-post records.

## Owner words

> ORD-1042 G1 (brief BR-20261016-ops-design1): L1 cluster-ops deploy: homelab-gitops app for the bus, merge-on-green sweeps and stuck-watch as CronJobs (rule 39); secrets via external-secrets and Vault, never read a credential

> i don't like agents doing shit when i have a k8s cluster too, automate processes right away (Design principles 101 item 39)

> Have fallbacks too (item 28); Ensure that your testing is dev uat stable. (item 34); And don't ever bog the user down with notifications when testing. (item 35)

## Context

Prerequisite (owner, Bearings card raised by the architect): Vault secret/homelab/apps/line-ops carries github-username and github-pat. Check without reading values: kubectl -n line-ops-uat get secret github-token ghcr-pull-secret -o name prints both; absent: stop with A2A-003 OWNER-SEED and leave.

apps/line-ops/overlays/stable/kustomization.yaml gains a patches entry: target {kind: CronJob, name: pr-sweep}, patch '- op: replace\n path: /spec/suspend\n value: false', with a comment naming the UAT evidence path. uat stays suspended (its gate creates jobs from it).

Held in draft until WO-20261016-e297 (work-order.sh approve --code-dir DIR resolves step and AC tools in the checkout of the ticket repo) is on main: approve today resolves tools only against dotfiles.

Order: (1) make -C apps/line-ops gate-uat-pr-sweep; output to the artifact store by script (the repo's gate evidence uses the artifact store's log key, PR 102) - GATE-PASS required, else stop with GATE-FAIL and the output. (2) commit the patch, push, open the PR, leave. The architect's merge sweep merges on green; after Argo CD syncs, the line's orchestrator runs make -C ~/dotfiles/claude/workflow pr-flow-consume-stop and the dotfiles monitors ticket replaces the pane.

## Scope

**In**

- touches: apps/line-ops/overlays/stable/kustomization.yaml (one patches entry)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path in dotfiles; dotfiles work-orders/INDEX.md and the epic README.md are ignored generated views
- step: clone or worktree jkkelley/homelab-gitops from origin/main into your own worktree under ~/.cache (git worktree add from ~/projects/homelab-gitops; fallback: git clone), branch feat/<slug>; every path and AC command below runs from that worktree's root
- step: check the prerequisite per Context; absent: stop with A2A-003 OWNER-SEED
- step: make -C apps/line-ops gate-uat-pr-sweep, evidence to the artifact store
- step: write the patch, run the AC checks only, commit 'feat(line-ops): pr-sweep on the real line' with the ticket id and the evidence path, push, open the PR, leave
- tool: make:apps/line-ops/Makefile:gate-uat-pr-sweep - built by the gates ticket; fallback: missing on main: stop with DESIGN-GAP
- tool: cmd:kubectl (cluster context of the owner's homelab) - fallback: cluster unreachable: retry 3 times 30 s apart, then stop with A2A-003 and the kubectl error; no local substitute
- tool: cmd:git, cmd:gh, cmd:jq, cmd:make - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- dotfiles monitors.json: its own ticket
- any other overlay or base file
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- waiting on CI or merging: push, open the PR, write the result, leave
- reading, printing or writing any credential value: secrets reach pods only through external-secrets from Vault; the owner seeds Vault
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [free] [fixed] None declared: implement exactly as specified; stop with DESIGN-GAP before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* UAT passed before promotion
  - check: `make -C apps/line-ops gate-uat-pr-sweep` exit 0 expect /GATE-PASS uat pr-sweep U0-U4/
- [ ] `AC-H2` *(human)* stable renders the CronJob unsuspended, uat still suspended
  - check: `test $(kubectl kustomize apps/line-ops/overlays/stable | grep -c '^ suspend: false$') = 1 && test $(kubectl kustomize apps/line-ops/overlays/uat | grep -c '^ suspend: true$') = 1 && echo PROMOTE-OK` exit 0 expect /PROMOTE-OK/
- [ ] `AC-H3` *(human)* the diff holds only In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(apps/line-ops/overlays/stable/kustomization\.yaml)$'` exit 1

## Test plan

```sh
{"scope":"the UAT gate against line-ops-uat, then a render of the promotion","cases":[{"id":"TP-1","intent":"stable only after UAT (item 34)","command":"make -C apps/line-ops gate-uat-pr-sweep","expected":"GATE-PASS uat pr-sweep U0-U4"},{"id":"TP-2","intent":"only stable is unsuspended","command":"AC-H2","expected":"PROMOTE-OK"}],"isolation":{"runtime":"podman","image":"none: cluster UAT namespace line-ops-uat"},"out_of_scope":["stable health after sync: make gate-stable, run by the line after merge"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` HELD draft: approve resolves tools only in the dotfiles project; this ticket names make:apps/line-ops/Makefile:gate-uat-pr-sweep on homelab-gitops. Approve with approve --code-dir <homelab-gitops checkout> once WO-20261016-e297 (approve --code-dir) is on main and the gates ticket merged.

## Outcome

_Written by `work-order done`. Empty until then._
