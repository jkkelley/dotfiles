---
{
  "id": "WO-20261016-babd",
  "slug": "test-uat-on-homelab-gitops-a-probe-pr-touching-a",
  "title": "Test - UAT on homelab-gitops: a probe PR touching apps/line-ops is linted green, held by make deploy-gate without evidence, then closed unmerged",
  "type": "test",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:54:00+00:00",
  "parent": "WO-20261016-770f",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design19 cut ORD-1128 K1 and ORD-1140 S3 (brief BR-20261016-infra-design19); design approvals ruled done, ORD-0550 O4; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-9a0f"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "gh api repos/jkkelley/homelab-gitops/commits/$(gh pr list -R jkkelley/homelab-gitops --state all --head uat/gitops-ci-probe --json headRefOid --jq '.[0].headRefOid')/check-runs --jq '.check_runs[] | select(.name==\"make deploy-gate\") | .conclusion'",
      "exit": 0,
      "expect": "^failure$"
    },
    {
      "index": 2,
      "command": "gh api repos/jkkelley/homelab-gitops/commits/$(gh pr list -R jkkelley/homelab-gitops --state all --head uat/gitops-ci-probe --json headRefOid --jq '.[0].headRefOid')/check-runs --jq '.check_runs[] | select(.name==\"make gitops-lint\") | .conclusion'",
      "exit": 0,
      "expect": "^success$"
    },
    {
      "index": 3,
      "command": "gh pr list -R jkkelley/homelab-gitops --state all --head uat/gitops-ci-probe --json state,mergedAt --jq '.[0] | .state + \" \" + (.mergedAt // \"-\")'",
      "exit": 0,
      "expect": "^CLOSED -$"
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'",
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

# WO-20261016-babd - Test - UAT on homelab-gitops: a probe PR touching apps/line-ops is linted green, held by make deploy-gate without evidence, then closed unmerged

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

The dev gate proves the gitops-ci scripts with fakes only; nothing proves the installed CI lints the real manifests on a GitHub runner and that merge-on-green holds a deploy PR without dev and UAT evidence.

## Owner words

> ORD-1128 K1 gitops CI tooling: tooling ticket first (rule 30): homelab-gitops CI, diff-selected and fast: yamllint and kubeconform on changed manifests, helm template plus kubeconform for changed charts, kustomize build for changed overlays, tracked-ignored-check, md-contents; plus the merge-on-green Action ported (one config entry if the template allows). A gitops merge is a deploy, so merge-on-green there also requires the PR dev and UAT gate evidence named in its ticket (rule 34). (orchestrator brief BR-20261016-infra-design19)

> Ensure that your testing is dev uat stable. (Design principles 101 item 34)

> And don't ever bog the user down with notifications when testing. (Design principles 101 item 35)

## Context

Epic WO-20261016-770f holds the design. Inputs: homelab-gitops main carries Makefile, .github/workflows/ci.yml and merge-on-green.yml (WO-20261016-9a0f); the probe never merges, because a merge to homelab-gitops is a deploy. Probe: branch uat/gitops-ci-probe from origin/main in a worktree of ~/projects/homelab-gitops; append the single comment line "# gitops-ci UAT probe THIS-TICKET-ID" to apps/line-ops/base/kustomization.yaml; commit "test: gitops-ci UAT probe (do not merge)"; push; gh pr create -R jkkelley/homelab-gitops --draft --title "test: gitops-ci UAT probe (do not merge)" --body "UAT probe for THIS-TICKET-ID; carries no gate lines on purpose; closed by the tester". A draft PR is still built by ci.yml (pull_request opened). Wait for ci (gh pr checks <N> -R jkkelley/homelab-gitops --watch, timeout 15 min). Expected: make gitops-lint success (kustomize builds apps/line-ops/base, overlays/stable and overlays/uat), make deploy-gate failure with GATE-MISSING ticket, dev and uat (the body has the ticket id but no Gate lines, so GATE-MISSING dev and uat), ci-ok failure, merge-on-green held. Then run TP-4 locally, then gh pr close <N> -R jkkelley/homelab-gitops --delete-branch and remove the worktree. Nothing pings the owner: no ntfy, no card (item 35).

A failure here is a defect in a unit ticket: file it with the run URL and log (item 22), close the probe, and stop with the code UAT-FAIL; never merge the probe and never edit the gitops-ci scripts in this ticket. Evidence: gh run view <run> --log-failed and the four TP outputs written with make artifact-new KEY=log NAME=gitops-ci-uat EXT=log, the path recorded with work-order.sh evidence.

## Scope

**In**

- touches: none in dotfiles beyond the generated ticket files; in jkkelley/homelab-gitops only the probe branch uat/gitops-ci-probe, closed and deleted
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: run the probe exactly as in Context (worktree of ~/projects/homelab-gitops; fallback: worktree add fails: git clone into a mktemp dir)
- step: run TP-1 to TP-4, record evidence with make artifact-new and work-order.sh evidence, close the probe, then checks 1-4 with bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID
- step: the dotfiles PR carries only the generated ticket moves; open it, submit, done, push, leave
- tool: make:Makefile:artifact-new - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:gh, cmd:make, cmd:jq - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output; runner queue over 15 min: stop with SLOW and the run URL

**Out - non-goals**

- merging the probe or any homelab-gitops PR: a merge there is a deploy
- editing any gitops-ci script or workflow: a failure is filed against its unit ticket
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the probe was held by a failed make deploy-gate
  - check: `gh api repos/jkkelley/homelab-gitops/commits/$(gh pr list -R jkkelley/homelab-gitops --state all --head uat/gitops-ci-probe --json headRefOid --jq '.[0].headRefOid')/check-runs --jq '.check_runs[] | select(.name=="make deploy-gate") | .conclusion'` exit 0 expect /^failure$/
- [ ] `AC-H2` *(human)* the real manifests linted green on the runner
  - check: `gh api repos/jkkelley/homelab-gitops/commits/$(gh pr list -R jkkelley/homelab-gitops --state all --head uat/gitops-ci-probe --json headRefOid --jq '.[0].headRefOid')/check-runs --jq '.check_runs[] | select(.name=="make gitops-lint") | .conclusion'` exit 0 expect /^success$/
- [ ] `AC-H3` *(human)* the probe is closed and never merged
  - check: `gh pr list -R jkkelley/homelab-gitops --state all --head uat/gitops-ci-probe --json state,mergedAt --jq '.[0] | .state + " " + (.mergedAt // "-")'` exit 0 expect /^CLOSED -$/
- [ ] `AC-H4` *(human)* the dotfiles diff holds only generated ticket files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

homelab-gitops CI and merge-on-green with the gitops-ci gate, on the real repo with a probe PR that is closed, never merged (UAT, item 34)

**Cases**

- `TP-1`
  - intent: a deploy-path PR with no gate evidence is held by a failed make deploy-gate check, so merge-on-green cannot deploy it
  - command: `gh api repos/jkkelley/homelab-gitops/commits/$(gh pr list -R jkkelley/homelab-gitops --state all --head uat/gitops-ci-probe --json headRefOid --jq '.[0].headRefOid')/check-runs --jq '.check_runs[] | select(.name=="make deploy-gate") | .conclusion'`
  - expected: exit 0 and failure
- `TP-2`
  - intent: the real line-ops base and overlays lint and build green on the runner, so the tool works on the real manifests
  - command: `gh api repos/jkkelley/homelab-gitops/commits/$(gh pr list -R jkkelley/homelab-gitops --state all --head uat/gitops-ci-probe --json headRefOid --jq '.[0].headRefOid')/check-runs --jq '.check_runs[] | select(.name=="make gitops-lint") | .conclusion'`
  - expected: exit 0 and success
- `TP-3`
  - intent: the probe is closed and was never merged, so UAT deployed nothing
  - command: `gh pr list -R jkkelley/homelab-gitops --state all --head uat/gitops-ci-probe --json state,mergedAt --jq '.[0] | .state + " " + (.mergedAt // "-")'`
  - expected: exit 0 and CLOSED -
- `TP-4`
  - intent: with the evidence lines in a body file, the same branch passes the gate locally
  - command: `make -C <probe worktree> deploy-gate BASE_REF=origin/main BODY=/tmp/gc-body.md (body file: Ticket: THIS-TICKET-ID, Gate-Dev: GATE-PASS dev gitops-ci 21b4, Gate-UAT: GATE-PASS uat gitops-ci probe, one per line)`
  - expected: exit 0 and GATE-OK

**Isolation**

- runtime: podman
- image: localhost/dotfiles-workflow-test:1
- build: make -C claude/workflow image
- containerfile: claude/workflow/tests/container/Containerfile

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
