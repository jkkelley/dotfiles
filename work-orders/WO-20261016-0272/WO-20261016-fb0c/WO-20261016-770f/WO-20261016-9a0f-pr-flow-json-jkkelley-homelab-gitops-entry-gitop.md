---
{
  "id": "WO-20261016-9a0f",
  "slug": "pr-flow-json-jkkelley-homelab-gitops-entry-gitop",
  "title": "pr-flow.json: jkkelley/homelab-gitops entry (gitops-lint, deploy-gate, tracked-ignored-check, md-contents-check) and make pr-flow-ci-install puts ci.yml and merge-on-green.yml on homelab-gitops",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:53:27+00:00",
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
    "WO-20261016-d38a",
    "WO-20261016-21b4",
    "WO-20261016-73f2",
    "WO-20261016-c6a5",
    "WO-20261016-be8a"
  ],
  "blocks": [
    "WO-20261016-babd"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/workflow/pr-flow/bin/pr-flow-config.sh jkkelley/homelab-gitops | jq -r '[.required_check, (.ci.pr_targets|join(\",\")), (.ci.main_targets|join(\",\")), .ci.setup, (.ci.installed|join(\",\"))] | join(\" \")'",
      "exit": 0,
      "expect": "^ci-ok gitops-lint,deploy-gate,tracked-ignored-check,md-contents-check gitops-lint-all,tracked-ignored-check setup ci,merge-on-green$"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow pr-flow-test CASES=ci-template",
      "exit": 0,
      "expect": "ok  ci-template"
    },
    {
      "index": 3,
      "command": "gh api repos/jkkelley/homelab-gitops/contents/.github/workflows/ci.yml --jq .name",
      "exit": 0,
      "expect": "^ci\\.yml$"
    },
    {
      "index": 4,
      "command": "gh api repos/jkkelley/homelab-gitops/contents/.github/workflows/merge-on-green.yml --jq .name",
      "exit": 0,
      "expect": "^merge-on-green\\.yml$"
    },
    {
      "index": 5,
      "command": "gh api repos/jkkelley/homelab-gitops/contents/Makefile --jq .name",
      "exit": 0,
      "expect": "^Makefile$"
    },
    {
      "index": 6,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/pr-flow/config/pr-flow\\.json)$'",
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

# WO-20261016-9a0f - pr-flow.json: jkkelley/homelab-gitops entry (gitops-lint, deploy-gate, tracked-ignored-check, md-contents-check) and make pr-flow-ci-install puts ci.yml and merge-on-green.yml on homelab-gitops

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

homelab-gitops has no CI and no merge-on-green: green PRs sit open, and nothing lints a manifest before Argo CD applies it.

## Owner words

> ORD-1128 K1 gitops CI tooling: tooling ticket first (rule 30): homelab-gitops CI, diff-selected and fast: yamllint and kubeconform on changed manifests, helm template plus kubeconform for changed charts, kustomize build for changed overlays, tracked-ignored-check, md-contents; plus the merge-on-green Action ported (one config entry if the template allows). A gitops merge is a deploy, so merge-on-green there also requires the PR dev and UAT gate evidence named in its ticket (rule 34). (orchestrator brief BR-20261016-infra-design19)

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

> testing and linting smartly (owner 2026-10-16 UTC, global PR process rule)

## Context

Epic WO-20261016-770f holds the design. The pr-flow ci.yml and merge-on-green.yml templates take the gitops targets as one config entry, so no template changes (claude/workflow/pr-flow/bin/pr-flow-ci-render.sh keys PR_TARGETS, MAIN_TARGETS, SETUP, REQUIRED_CHECK, WORKFLOWS). Inputs: homelab-gitops Makefile from WO-20261016-d38a (its PR in jkkelley/homelab-gitops is open and unmerged when this starts, since that repo has no merge-on-green yet), the gitops-ci tool proven by WO-20261016-21b4. pr-flow.json is edited after WO-20261016-73f2, WO-20261016-c6a5 and WO-20261016-be8a, which touch it first; rebase on origin/main before editing. homelab-gitops repo facts read 2026-10-16 UTC: private, default branch main, Actions enabled, default workflow permissions read (the templates declare their own permissions blocks).

Add exactly this key under .repos, after jkkelley/business, 2-space indent, nothing else in the file changes (no $comment edit; the breadcrumb lives in the homelab-gitops Makefile): "jkkelley/homelab-gitops": {"clone": "~/projects/homelab-gitops", "required_check": "ci-ok", "ci": {"pr_targets": ["gitops-lint", "deploy-gate", "tracked-ignored-check", "md-contents-check"], "main_targets": ["gitops-lint-all", "tracked-ignored-check"], "setup": "setup", "installed": ["ci", "merge-on-green"]}}. The workflows default ["ci"] and dispatch default "ci.yml" are kept, so merge-on-green waits on ci and starts ci on main after a merge. The installing PR touches only .github/workflows, which is not a deploy path, so its deploy-gate check skips.

## Scope

**In**

- touches: claude/workflow/pr-flow/config/pr-flow.json (one key under repos)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone
- step: merge the WO-20261016-d38a homelab-gitops PR: gh pr merge <its pr from work-order.sh show --id WO-20261016-d38a --json | jq .pr> -R jkkelley/homelab-gitops --squash --delete-branch (Makefile and .gitignore only, not a deploy path; the repo has no merge-on-green yet)
- step: add the key exactly as in Context; jq . claude/workflow/pr-flow/config/pr-flow.json >/dev/null; run checks 1 and 2
- step: commit 'chore(pr-flow): homelab-gitops entry, gitops-ci targets' with the ticket id; no Bump trailer; push, open the dotfiles PR
- step: make -C claude/workflow pr-flow-ci-install REPO=jkkelley/homelab-gitops DRY=1 and read the plan, then without DRY; wait for the installing PR ci run (gh pr checks <N> -R jkkelley/homelab-gitops --watch, timeout 15 min), then gh pr merge <N> -R jkkelley/homelab-gitops --squash --delete-branch as pr-flow-install.sh says (the Action runs only once on main); run checks 3-5, submit --pr <dotfiles PR>, leave
- tool: make:claude/workflow/pr-flow/pr-flow.mk:pr-flow-ci-install, make:claude/workflow/pr-flow/pr-flow.mk:pr-flow-test - on main; fallback: install refused: make -C claude/workflow pr-flow-rollback REPO=jkkelley/homelab-gitops and stop with DESIGN-GAP and its output; installing PR ci red: stop with DESIGN-GAP and the failed job log, never merge red
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- claude/workflow/pr-flow/templates/* or pr-flow-ci-render.sh: the entry is enough
- any homelab-gitops file other than what pr-flow-install.sh renders into .github/workflows
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the entry resolves to the gitops targets
  - check: `bash claude/workflow/pr-flow/bin/pr-flow-config.sh jkkelley/homelab-gitops | jq -r '[.required_check, (.ci.pr_targets|join(",")), (.ci.main_targets|join(",")), .ci.setup, (.ci.installed|join(","))] | join(" ")'` exit 0 expect /^ci-ok gitops-lint,deploy-gate,tracked-ignored-check,md-contents-check gitops-lint-all,tracked-ignored-check setup ci,merge-on-green$/
- [ ] `AC-H2` *(human)* the ci template test passes
  - check: `make -C claude/workflow pr-flow-test CASES=ci-template` exit 0 expect /ok ci-template/
- [ ] `AC-H3` *(human)* ci.yml is on homelab-gitops main
  - check: `gh api repos/jkkelley/homelab-gitops/contents/.github/workflows/ci.yml --jq .name` exit 0 expect /^ci\.yml$/
- [ ] `AC-H4` *(human)* merge-on-green.yml is on homelab-gitops main
  - check: `gh api repos/jkkelley/homelab-gitops/contents/.github/workflows/merge-on-green.yml --jq .name` exit 0 expect /^merge-on-green\.yml$/
- [ ] `AC-H5` *(human)* the Makefile is on homelab-gitops main
  - check: `gh api repos/jkkelley/homelab-gitops/contents/Makefile --jq .name` exit 0 expect /^Makefile$/
- [ ] `AC-H6` *(human)* the diff holds only the In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/pr-flow/config/pr-flow\.json)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the jkkelley/homelab-gitops entry in claude/workflow/pr-flow/config/pr-flow.json and the rendered workflows it installs

**Cases**

- `TP-1`
  - intent: the entry resolves to the gitops targets, so the rendered ci.yml runs the gitops checks and the gate on every PR
  - command: `bash claude/workflow/pr-flow/bin/pr-flow-config.sh jkkelley/homelab-gitops | jq -r '[.required_check, (.ci.pr_targets|join(",")), (.ci.main_targets|join(",")), .ci.setup, (.ci.installed|join(","))] | join(" ")'`
  - expected: exit 0 and ci-ok gitops-lint,deploy-gate,tracked-ignored-check,md-contents-check gitops-lint-all,tracked-ignored-check setup ci,merge-on-green
- `TP-2`
  - intent: the existing template test still passes, so no other repo render changed
  - command: `make -C claude/workflow pr-flow-test CASES=ci-template`
  - expected: exit 0 and ok  ci-template
- `TP-3`
  - intent: merge-on-green is live on homelab-gitops main
  - command: `gh api repos/jkkelley/homelab-gitops/contents/.github/workflows/merge-on-green.yml --jq .name`
  - expected: exit 0 and merge-on-green.yml

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
