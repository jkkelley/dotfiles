---
{
  "id": "WO-20261016-b7ee",
  "slug": "gitops-changed-sh-repo-repo-dir-base-diff-select",
  "title": "gitops-changed.sh REPO= REPO_DIR= BASE=: diff-selected yaml, manifests, chart dirs, kustomize dirs and the deploy flag for a GitOps repo, from config/gitops-ci.json",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:49:11+00:00",
  "parent": "WO-20261016-770f",
  "branch": "feat/b7ee-gitops-changed-sh-repo-repo-dir-base-diff-select",
  "pr": 345,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design19 cut ORD-1128 K1 and ORD-1140 S3 (brief BR-20261016-infra-design19); design approvals ruled done, ORD-0550 O4; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-ae02"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/gitops-ci/bin/gitops-changed.sh --help'",
      "exit": 0,
      "expect": "gitops-changed\\.sh"
    },
    {
      "index": 2,
      "command": "jq -e '.defaults.images.kubeconform and .defaults.images.helm and .defaults.images.kustomize and .defaults.images.yamllint and .repos[\"jkkelley/homelab-gitops\"].deploy_re' claude/workflow/gitops-ci/config/gitops-ci.json",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && git -C $d init -q && mkdir -p $d/apps/a/base $d/helm/c/templates $d/argocd-apps && printf \"kind: Kustomization\\n\" > $d/apps/a/base/kustomization.yaml && printf \"name: c\\n\" > $d/helm/c/Chart.yaml && git -C $d add -A && git -C $d -c user.email=t@example.com -c user.name=t commit -qm b && printf \"x: 1\\n\" > $d/apps/a/base/d.yaml && printf \"y: 1\\n\" > $d/helm/c/templates/s.yaml && printf \"kind: ConfigMap\\n\" > $d/argocd-apps/x.yaml && git -C $d add -A && git -C $d -c user.email=t@example.com -c user.name=t commit -qm c && bash claude/workflow/gitops-ci/bin/gitops-changed.sh --repo jkkelley/homelab-gitops --repo-dir $d --base HEAD~1 | jq -c \"[.overlays,.charts,.manifests,.yaml,.deploy]\"'",
      "exit": 0,
      "expect": "^\\[\\[\"apps/a/base\"\\],\\[\"helm/c\"\\],\\[\"argocd-apps/x\\.yaml\"\\],\\[\"apps/a/base/d\\.yaml\",\"argocd-apps/x\\.yaml\"\\],true\\]$"
    },
    {
      "index": 4,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/gitops-ci/bin/gitops-changed.sh --repo no/such --repo-dir . --base HEAD'",
      "exit": 2,
      "expect": null
    },
    {
      "index": 5,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'shellcheck -x claude/workflow/gitops-ci/bin/gitops-changed.sh'",
      "exit": 0,
      "expect": null
    },
    {
      "index": 6,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/gitops-ci/bin/gitops-changed\\.sh|claude/workflow/gitops-ci/config/gitops-ci\\.json)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "claude/workflow/gitops-ci/bin/gitops-changed.sh",
    "claude/workflow/gitops-ci/config/gitops-ci.json"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-b7ee - gitops-changed.sh REPO= REPO_DIR= BASE=: diff-selected yaml, manifests, chart dirs, kustomize dirs and the deploy flag for a GitOps repo, from config/gitops-ci.json

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

A GitOps CI that validates every file on every PR is slow, and one that validates nothing lets a broken manifest deploy. Nothing in dotfiles maps a diff to the yaml files, charts and kustomize overlays it affects.

## Owner words

> ORD-1128 K1 gitops CI tooling: tooling ticket first (rule 30): homelab-gitops CI, diff-selected and fast: yamllint and kubeconform on changed manifests, helm template plus kubeconform for changed charts, kustomize build for changed overlays, tracked-ignored-check, md-contents; plus the merge-on-green Action ported (one config entry if the template allows). A gitops merge is a deploy, so merge-on-green there also requires the PR dev and UAT gate evidence named in its ticket (rule 34). (orchestrator brief BR-20261016-infra-design19)

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in, thats a prereq for the ticket ready then, you feel me? (Design principles 101 item 30)

> speed is the name of the game, no bottlenecks (Design principles 101 item 1)

> config and arguments are good ways to pass things, easy in makefiles too (Design principles 101 item 17)

## Context

Epic WO-20261016-770f holds the design and DAG. New file claude/workflow/gitops-ci/config/gitops-ci.json, exactly this JSON (2-space indent): {"$comment": "gitops-ci per GitOps repository (dotfiles claude/workflow/gitops-ci, ORD-1128 K1). defaults are merged under repos[slug] with jq .defaults * .repos[slug]; a new repo is one entry. images are pinned by digest (Rule 15), tags in the _tag keys.", "defaults": {"deploy_re": "^(apps|argocd-apps|bootstrap|helm|charts|clusters)/", "yaml_re": "\\.ya?ml$", "yaml_exclude_re": "(^|/)templates/", "manifest_re": "\\.ya?ml$", "manifest_exclude_re": "(^|/)(values[^/]*|Chart|kustomization)\\.ya?ml$|^\\.github/", "app_depth": 2, "kubernetes_version": "1.32.13", "schema_locations": ["default", "https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json"], "yamllint_config": "{extends: relaxed, rules: {line-length: disable}}", "evidence": {"ticket_re": "WO-[0-9]{8}-[0-9a-f]{4}", "dev_re": "^Gate-Dev: GATE-PASS dev .+", "uat_re": "^Gate-UAT: GATE-PASS uat .+"}, "images": {"yamllint": "docker.io/cytopia/yamllint@sha256:1bf8270a671a2e5f2fea8ac2e80164d627e0c5fa083759862bbde80628f942b2", "yamllint_tag": "cytopia/yamllint:1.26", "kubeconform": "ghcr.io/yannh/kubeconform@sha256:0925177fb05b44ce18574076141b5c3d83235e1904d3f952182ac99ddc45762c", "kubeconform_tag": "yannh/kubeconform:v0.6.7", "helm": "docker.io/alpine/helm@sha256:0572e0413de2c21ce4904864ecf075ec3ddc093deb436e2e35bd3ed65a83a5b2", "helm_tag": "alpine/helm:3.16.2", "kustomize": "registry.k8s.io/kustomize/kustomize@sha256:6dd0a67e2a8634a5d1aabd9c5e888ff220663e979b55bc17fe4b3a845718bb10", "kustomize_tag": "kustomize/kustomize:v5.4.3"}}, "repos": {"jkkelley/homelab-gitops": {"deploy_re": "^(apps|argocd-apps|bootstrap|helm)/", "manifest_re": "^(apps|argocd-apps|bootstrap)/.*\\.ya?ml$"}}}. The digests were read 2026-10-16 UTC with podman pull then podman image inspect --format {{index .RepoDigests 0}}; kubernetes_version is the cluster server version (kubectl version, v1.32.13).

New file claude/workflow/gitops-ci/bin/gitops-changed.sh, mode 755, bash, set -euo pipefail, the rolodex header block (name, purpose, inputs, outputs, writes-to: nothing, cleanup: none) as in claude/workflow/pr-flow/bin/pr-flow-config.sh. Usage: gitops-changed.sh --repo OWNER/NAME --repo-dir DIR [--base REF] [--config FILE]; -h/--help prints the usage lines (they contain the word gitops-changed.sh) and exits 0. Config: --config, else env GITOPS_CI_CONFIG, else $HERE/../config/gitops-ci.json; resolved = jq --arg r SLUG ".defaults * .repos[\$r]"; a slug absent from .repos prints "gitops-changed: unknown repo SLUG" to stderr and exits 2; any other bad argument exits 2. Changed list: with a non-empty --base, git -C DIR diff --name-only --diff-filter=d BASE...HEAD; with an empty or absent --base, git -C DIR ls-files (the push-to-main full run); a failing git exits 4.

Classification, per changed path f (repo-relative), in this order. yaml: f matches yaml_re and not yaml_exclude_re (grep -E) -> yaml[]. chart: walk from dirname f up to the repo root; the first dir holding Chart.yaml in DIR -> charts[] gets that dir, and f is not classified further. kustomize: else let root be the first app_depth components of f (for apps/a/base/d.yaml with depth 2, apps/a); walk from dirname f up to root inclusive; if any dir holds kustomization.yaml or kustomization.yml, every dir K that holds one (from git -C DIR ls-files, dirname of each path ending /kustomization.ya?ml) and equals root or starts with root/ -> overlays[], and f is not classified further. manifest: else f matches manifest_re and not manifest_exclude_re -> manifests[]. deploy is true when any f matches deploy_re. Output, one compact JSON line on stdout: {"repo": SLUG, "base": BASE or "", "yaml": [...], "manifests": [...], "charts": [...], "overlays": [...], "deploy": true|false}, each array sorted and unique; exit 0. GOOD: apps/line-ops/base/deadman.yaml selects overlays apps/line-ops/base, apps/line-ops/overlays/stable and apps/line-ops/overlays/uat. NEVER: a values.yaml or a chart template sent to kubeconform as a manifest.

## Scope

**In**

- touches: claude/workflow/gitops-ci/bin/gitops-changed.sh (new)
- touches: claude/workflow/gitops-ci/config/gitops-ci.json (new)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone
- step: write both files exactly as in Context, chmod 755 the script, then run checks 1-6 with bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID
- step: commit 'feat(workflow): gitops-changed.sh diff selection for GitOps repos' with the ticket id; no Bump trailer; push, open the PR, leave
- tool: make:claude/workflow/Makefile:image - on main; fallback: image build fails: retry 3 times, then stop with ENV-MISSING and the podman output
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- running yamllint, kubeconform, helm or kustomize: WO gitops-check.sh does
- a Make target: the gitops-ci.mk ticket wires it
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the usage prints
  - observed `2026-10-16` check: make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/gitops-ci/bin/gitops-changed.sh --help' exit 0 output: usage: gitops-changed.sh --repo OWNER/NAME --repo-dir DIR [--base REF] [--config FILE] empty or absent --base lists every tracked file (push-to-main full run)
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/gitops-ci/bin/gitops-changed.sh --help'` exit 0 expect /gitops-changed\.sh/
- [x] `AC-H2` *(human)* the config carries the four pinned images and the homelab-gitops entry
  - observed `2026-10-16` check: jq -e '.defaults.images.kubeconform and .defaults.images.helm and .defaults.images.kustomize and .defaults.images.yamllint and .repos["jkkelley/homelab-gitops"].deploy_re' claude/workflow/gitops-ci/config/gitops-ci.json exit 0 output: true
  - check: `jq -e '.defaults.images.kubeconform and .defaults.images.helm and .defaults.images.kustomize and .defaults.images.yamllint and .repos["jkkelley/homelab-gitops"].deploy_re' claude/workflow/gitops-ci/config/gitops-ci.json` exit 0
- [x] `AC-H3` *(human)* a fixture diff classifies into overlays, charts, manifests, yaml and deploy exactly
  - observed `2026-10-16` check: make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && git -C $d init -q && mkdir -p $d/apps/a/base $d/helm/c/templates $d/argocd-apps && printf "kind: Kustomization
" > $d/apps/a/base/kustomization.yaml && printf "name: c
" > $d/helm/c/Chart.yaml && git -C $d add -A && git -C $d -c user.email=t@example.com -c user.name=t commit -qm b && printf "x: 1
" > $d/apps/a/base/d.yaml && printf "y: 1
" > $d/helm/c/templates/s.yaml && printf "kind: ConfigMap
" > $d/argocd-apps/x.yaml && git -C $d add -A && git -C $d -c user.email=t@example.com -c user.name=t commit -qm c && bash claude/workflow/gitops-ci/bin/gitops-changed.sh --repo jkkelley/homelab-gitops --repo-dir $d --base HEAD~1 | jq -c "[.overlays,.charts,.manifests,.yaml,.deploy]"' exit 0 output: [["apps/a/base"],["helm/c"],["argocd-apps/x.yaml"],["apps/a/base/d.yaml","argocd-apps/x.yaml"],true]
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && git -C $d init -q && mkdir -p $d/apps/a/base $d/helm/c/templates $d/argocd-apps && printf "kind: Kustomization\n" > $d/apps/a/base/kustomization.yaml && printf "name: c\n" > $d/helm/c/Chart.yaml && git -C $d add -A && git -C $d -c user.email=t@example.com -c user.name=t commit -qm b && printf "x: 1\n" > $d/apps/a/base/d.yaml && printf "y: 1\n" > $d/helm/c/templates/s.yaml && printf "kind: ConfigMap\n" > $d/argocd-apps/x.yaml && git -C $d add -A && git -C $d -c user.email=t@example.com -c user.name=t commit -qm c && bash claude/workflow/gitops-ci/bin/gitops-changed.sh --repo jkkelley/homelab-gitops --repo-dir $d --base HEAD~1 | jq -c "[.overlays,.charts,.manifests,.yaml,.deploy]"'` exit 0 expect /^\[\["apps/a/base"\],\["helm/c"\],\["argocd-apps/x\.yaml"\],\["apps/a/base/d\.yaml","argocd-apps/x\.yaml"\],true\]$/
- [x] `AC-H4` *(human)* an unknown repo is refused with exit 2
  - observed `2026-10-16` check: make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/gitops-ci/bin/gitops-changed.sh --repo no/such --repo-dir . --base HEAD' exit 2 output: gitops-changed: unknown repo no/such
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/gitops-ci/bin/gitops-changed.sh --repo no/such --repo-dir . --base HEAD'` exit 2
- [x] `AC-H5` *(human)* shellcheck passes
  - observed `2026-10-16` check: make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'shellcheck -x claude/workflow/gitops-ci/bin/gitops-changed.sh' exit 0 output:
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'shellcheck -x claude/workflow/gitops-ci/bin/gitops-changed.sh'` exit 0
- [x] `AC-H6` *(human)* the diff holds only the In files
  - observed `2026-10-16` check: git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/gitops-ci/bin/gitops-changed.sh|claude/workflow/gitops-ci/config/gitops-ci.json)$' exit 1 output:
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/gitops-ci/bin/gitops-changed\.sh|claude/workflow/gitops-ci/config/gitops-ci\.json)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/gitops-ci/bin/gitops-changed.sh and config/gitops-ci.json, the diff selection

**Cases**

- `TP-1`
  - intent: a changed file under a kustomize dir, a chart template and a plain manifest each land in the right list, so the checker validates what changed and nothing else (item 1)
  - command: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && git -C $d init -q && mkdir -p $d/apps/a/base $d/helm/c/templates $d/argocd-apps && printf "kind: Kustomization\n" > $d/apps/a/base/kustomization.yaml && printf "name: c\n" > $d/helm/c/Chart.yaml && git -C $d add -A && git -C $d -c user.email=t@example.com -c user.name=t commit -qm b && printf "x: 1\n" > $d/apps/a/base/d.yaml && printf "y: 1\n" > $d/helm/c/templates/s.yaml && printf "kind: ConfigMap\n" > $d/argocd-apps/x.yaml && git -C $d add -A && git -C $d -c user.email=t@example.com -c user.name=t commit -qm c && bash claude/workflow/gitops-ci/bin/gitops-changed.sh --repo jkkelley/homelab-gitops --repo-dir $d --base HEAD~1 | jq -c "[.overlays,.charts,.manifests,.yaml,.deploy]"'`
  - expected: exit 0 and [["apps/a/base"],["helm/c"],["argocd-apps/x.yaml"],["apps/a/base/d.yaml","argocd-apps/x.yaml"],true]
- `TP-2`
  - intent: a repo with no config entry is refused, never checked with guessed rules
  - command: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/gitops-ci/bin/gitops-changed.sh --repo no/such --repo-dir . --base HEAD'`
  - expected: exit 2 and gitops-changed: unknown repo no/such

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
