---
{
  "id": "WO-20261016-21b4",
  "slug": "test-gitops-ci-tooling-dev-gate-for-gitops-chang",
  "title": "Test - gitops-ci tooling: dev gate for gitops-changed, gitops-check and gitops-gate-evidence, eleven cases in podman with fakes",
  "type": "test",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:52:45+00:00",
  "parent": "WO-20261016-770f",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-ae02"
  ],
  "blocks": [
    "WO-20261016-9a0f"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -f claude/workflow/gitops-ci/gitops-ci.mk gitops-ci-test",
      "exit": 0,
      "expect": "pass=11 fail=0"
    },
    {
      "index": 2,
      "command": "grep -c -E '^case_[a-z_]+\\(\\)' claude/workflow/gitops-ci/tests/gitops-ci.test.sh",
      "exit": 0,
      "expect": "^11$"
    },
    {
      "index": 3,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'shellcheck -x claude/workflow/gitops-ci/tests/gitops-ci.test.sh'",
      "exit": 0,
      "expect": null
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/gitops-ci/tests/gitops-ci\\.test\\.sh)$'",
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

# WO-20261016-21b4 - Test - gitops-ci tooling: dev gate for gitops-changed, gitops-check and gitops-gate-evidence, eleven cases in podman with fakes

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

The gitops-ci scripts are proven only by their own ticket checks; nothing runs them together through gitops-ci.mk as one dev gate before they validate a real deploy repo.

## Owner words

> ORD-1128 K1 gitops CI tooling: tooling ticket first (rule 30): homelab-gitops CI, diff-selected and fast: yamllint and kubeconform on changed manifests, helm template plus kubeconform for changed charts, kustomize build for changed overlays, tracked-ignored-check, md-contents; plus the merge-on-green Action ported (one config entry if the template allows). A gitops merge is a deploy, so merge-on-green there also requires the PR dev and UAT gate evidence named in its ticket (rule 34). (orchestrator brief BR-20261016-infra-design19)

> Ensure that your testing is dev uat stable. (Design principles 101 item 34)

> i want work scoped so small a fuck ape could do, testing the same way with test plans and scripts (Design principles 101 item 30)

## Context

Epic WO-20261016-770f holds the design; the units are specified in WO-20261016-b7ee (gitops-changed.sh, config), WO-20261016-d1be (gitops-check.sh) and WO-20261016-3201 (gitops-gate-evidence.sh), wired by WO-20261016-ae02 (gitops-ci.mk target gitops-ci-test runs bash claude/workflow/gitops-ci/tests/gitops-ci.test.sh inside localhost/dotfiles-workflow-test:1, --network=none, cwd /work = the dotfiles root). The test shape follows claude/workflow/pr-flow/tests/*.test.sh: bash, set -uo pipefail, a fixture dir from mktemp -d removed by an EXIT trap, one function per case, a runner that calls each case_* function, prints "ok <name>" or "FAIL <name>: <why>", and ends with the line "pass=N fail=M", exit 1 when M > 0.

The eleven cases, function names exact. Fixture repo: git init in mktemp, base commit with apps/a/base/kustomization.yaml, apps/a/overlays/u/kustomization.yaml, helm/c/Chart.yaml, apps/v/values.yaml; second commit adds apps/a/base/d.yaml, helm/c/templates/s.yaml, argocd-apps/x.yaml and changes apps/v/values.yaml (git -c user.email=t@example.com -c user.name=t). case_select_kustomize: overlays equals ["apps/a/base","apps/a/overlays/u"]. case_select_chart: charts equals ["helm/c"] and helm/c/templates/s.yaml is not in yaml. case_select_manifest_excludes_values: manifests equals ["argocd-apps/x.yaml"] (apps/v/values.yaml absent) and deploy is true. case_select_unknown_repo: --repo no/such exits 2. Stub runtime: a script in the fixture dir that appends "$*" to a log and exits 0, or exits 1 when "$*" contains -strict. case_check_pass_stub: exit 0, last line GITOPS-CHECK ok, log has kubernetes-version 1.32.13 for the manifests and overlay runs. case_check_fail_stub: exit 1 and GITOPS-CHECK fail. case_check_no_runtime: GITOPS_CI_RUNTIME=/nonexistent exits 4 with ENV-MISSING. Gate cases use the repo config (--repo jkkelley/homelab-gitops) and a selection with deploy true unless named: case_gate_ok (CRLF body with ticket, Gate-Dev and Gate-UAT lines: exit 0, GATE-OK), case_gate_missing_uat (exit 1, GATE-MISSING uat), case_gate_skip_no_deploy (deploy false: exit 0, GATE-SKIP no-deploy-path), case_gate_event_path (GITHUB_EVENT_PATH JSON built with jq -n --arg b: exit 0, GATE-OK). A failing case is a defect in the unit: file it with its reproduction (item 22), never weaken the case.

## Scope

**In**

- touches: claude/workflow/gitops-ci/tests/gitops-ci.test.sh (new)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone
- step: write the test exactly as in Context, chmod 755, run make -f claude/workflow/gitops-ci/gitops-ci.mk gitops-ci-test, then checks 1-4 with bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID
- step: write the run output to the artifact store with make artifact-new KEY=log NAME=gitops-ci-dev-gate EXT=log and record its path with work-order.sh evidence
- step: commit 'test(workflow): gitops-ci dev gate, eleven cases' with the ticket id; no Bump trailer; push, open the PR, leave
- tool: make:claude/workflow/Makefile:image - on main; fallback: image build fails: retry 3 times, then stop with ENV-MISSING and the podman output
- tool: make:Makefile:artifact-new - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- changing any gitops-ci script: a failing case is filed against its unit ticket
- network, a real cluster or real images: UAT on homelab-gitops covers them
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the dev gate passes all cases
  - check: `make -f claude/workflow/gitops-ci/gitops-ci.mk gitops-ci-test` exit 0 expect /pass=11 fail=0/
- [ ] `AC-H2` *(human)* the suite has eleven cases
  - check: `grep -c -E '^case_[a-z_]+\(\)' claude/workflow/gitops-ci/tests/gitops-ci.test.sh` exit 0 expect /^11$/
- [ ] `AC-H3` *(human)* shellcheck passes
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'shellcheck -x claude/workflow/gitops-ci/tests/gitops-ci.test.sh'` exit 0
- [ ] `AC-H4` *(human)* the diff holds only the In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/gitops-ci/tests/gitops-ci\.test\.sh)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/gitops-ci: gitops-changed.sh, gitops-check.sh and gitops-gate-evidence.sh through gitops-ci.mk, the dev gate (podman, fakes only)

**Cases**

- `TP-1`
  - intent: every selection, check and gate rule holds in one run, so the homelab-gitops install starts only on a proven tool (item 34 dev gate)
  - command: `make -f claude/workflow/gitops-ci/gitops-ci.mk gitops-ci-test`
  - expected: exit 0 and a last line pass=11 fail=0
- `TP-2`
  - intent: the suite carries all eleven cases, so no rule goes untested
  - command: `grep -c -E '^case_[a-z_]+\(\)' claude/workflow/gitops-ci/tests/gitops-ci.test.sh`
  - expected: exit 0 and 11

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

- `2026-10-16` infra-design19: stays draft by rule 30 (approve: tool_missing gitops-ci-test) until WO-20261016-ae02 merges the gitops-ci.mk target on main; then approve --no-lavish with the same reason

## Outcome

_Written by `work-order done`. Empty until then._
