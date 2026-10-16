---
{
  "id": "WO-20261016-770f",
  "slug": "gitops-ci-diff-selected-ci-and-merge-on-green-fo",
  "title": "gitops-ci: diff-selected CI and merge-on-green for homelab-gitops, gated on dev and UAT evidence (ORD-1128 K1)",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:48:11+00:00",
  "parent": "WO-20261016-fb0c",
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
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "for i in b7ee d1be 3201 d38a ae02 21b4 9a0f babd; do bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-$i --json | jq -r .status; done | grep -vc \"^done$\"",
      "exit": 1,
      "expect": "^0$"
    }
  ],
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-770f - gitops-ci: diff-selected CI and merge-on-green for homelab-gitops, gated on dev and UAT evidence (ORD-1128 K1)

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

homelab-gitops has no CI and no merge-on-green: a manifest that does not parse, a chart that does not render or an overlay that does not build reaches main, and Argo CD applies main, so every merge is an untested deploy. No dotfiles tool validates GitOps manifests, so each repo would invent its own.

## Owner words

> ORD-1128 K1 gitops CI tooling: tooling ticket first (rule 30): homelab-gitops CI, diff-selected and fast: yamllint and kubeconform on changed manifests, helm template plus kubeconform for changed charts, kustomize build for changed overlays, tracked-ignored-check, md-contents; plus the merge-on-green Action ported (one config entry if the template allows). A gitops merge is a deploy, so merge-on-green there also requires the PR dev and UAT gate evidence named in its ticket (rule 34). (orchestrator brief BR-20261016-infra-design19)

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in, thats a prereq for the ticket ready then, you feel me? (Design principles 101 item 30)

> Ensure that your testing is dev uat stable. (Design principles 101 item 34)

> testing and linting smartly (owner 2026-10-16 UTC, global PR process rule)

## Context

Design. A generic, config-driven tool in dotfiles, claude/workflow/gitops-ci/, called from any GitOps repo by make -f <dotfiles>/claude/workflow/gitops-ci/gitops-ci.mk <target> REPO=owner/name REPO_DIR=<checkout> BASE=<ref> (item 4, item 17). One config file claude/workflow/gitops-ci/config/gitops-ci.json holds defaults and one entry per repo, so a new GitOps repo is one config entry. Three scripts: bin/gitops-changed.sh selects from the diff against BASE (yaml files, plain manifests, chart dirs, kustomize dirs, deploy flag); bin/gitops-check.sh runs yamllint, kubeconform, helm template piped to kubeconform and kustomize build piped to kubeconform in digest-pinned images; bin/gitops-gate-evidence.sh holds a PR that touches a deploy path until its body names its ticket and carries Gate-Dev: GATE-PASS dev ... and Gate-UAT: GATE-PASS uat ... lines (the GATE-PASS tokens are the ones apps/line-ops gate-dev and gate-uat already print). The gate is a CI job (make deploy-gate) rather than a change to merge-on-green.yml, because merge-on-green already holds any head with a failed check, and WO-20261016-39da and WO-20261016-ac25 own that template; rejected: a new template key, which would touch their file.

The repo side: homelab-gitops gets a Makefile whose targets clone dotfiles into .ci/dotfiles (ignored) and call the gitops-ci targets, plus tracked-ignored-check and md-contents-check; then one entry in claude/workflow/pr-flow/config/pr-flow.json and make pr-flow-ci-install REPO=jkkelley/homelab-gitops render and install the existing ci.yml and merge-on-green.yml templates there, with pr_targets gitops-lint, deploy-gate, tracked-ignored-check, md-contents-check (the template allows it as one config entry, so no template changes).

DAG (mermaid): graph TD; G1[gitops-changed.sh + config] --&gt; G5[gitops-ci.mk + README]; G2[gitops-check.sh] --&gt; G5; G3[gitops-gate-evidence.sh] --&gt; G5; G5 --&gt; G6[Test - gitops-ci tooling, dev gate]; G6 --&gt; G7[pr-flow.json entry + install on homelab-gitops]; G4[homelab-gitops Makefile] --&gt; G7; G7 --&gt; G8[Test - UAT on homelab-gitops]. G1, G2, G3 and G4 touch disjoint files and start at once. G7 also waits on WO-20261016-73f2, WO-20261016-c6a5 and WO-20261016-be8a, which touch pr-flow.json first.

## Scope

**In**

_none_

**Out - non-goals**

- the children carry the work; this epic carries no code
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* every child is done
  - check: `for i in b7ee d1be 3201 d38a ae02 21b4 9a0f babd; do bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-$i --json | jq -r .status; done | grep -vc "^done$"` exit 1 expect /^0$/

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
