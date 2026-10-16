---
{
  "id": "WO-20261016-d1be",
  "slug": "gitops-check-sh-yamllint-kubeconform-helm-templa",
  "title": "gitops-check.sh: yamllint, kubeconform, helm template and kustomize build on a gitops-changed selection, in digest-pinned images, PASS/FAIL per target",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:49:52+00:00",
  "parent": "WO-20261016-770f",
  "branch": "feat/d1be-gitops-check-sh-yamllint-kubeconform-helm-templa",
  "pr": 344,
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
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/gitops-ci/bin/gitops-check.sh --help'",
      "exit": 0,
      "expect": "gitops-check\\.sh"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf \"#!/bin/sh\\necho \\\"\\$*\\\" >> $d/log\\n\" > $d/rt && chmod +x $d/rt && printf \"{\\\"yaml\\\":[\\\"a.yaml\\\"],\\\"manifests\\\":[\\\"a.yaml\\\"],\\\"charts\\\":[],\\\"overlays\\\":[\\\"apps/x\\\"],\\\"deploy\\\":true}\" > $d/s.json && printf \"{\\\"defaults\\\":{\\\"kubernetes_version\\\":\\\"1.32.13\\\",\\\"schema_locations\\\":[\\\"default\\\"],\\\"yamllint_config\\\":\\\"{}\\\",\\\"images\\\":{\\\"yamllint\\\":\\\"y@sha256:1\\\",\\\"kubeconform\\\":\\\"k@sha256:2\\\",\\\"helm\\\":\\\"h@sha256:3\\\",\\\"kustomize\\\":\\\"z@sha256:4\\\"}},\\\"repos\\\":{}}\" > $d/c.json && GITOPS_CI_RUNTIME=$d/rt bash claude/workflow/gitops-ci/bin/gitops-check.sh --repo jkkelley/homelab-gitops --repo-dir $d --select $d/s.json --config $d/c.json >/dev/null && grep -c \"kubernetes-version 1.32.13\" $d/log'",
      "exit": 0,
      "expect": "^2$"
    },
    {
      "index": 3,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf \"#!/bin/sh\\ncase \\\"\\$*\\\" in *-strict*) exit 1;; esac\\n\" > $d/rt && chmod +x $d/rt && printf \"{\\\"yaml\\\":[\\\"a.yaml\\\"],\\\"manifests\\\":[\\\"a.yaml\\\"],\\\"charts\\\":[],\\\"overlays\\\":[\\\"apps/x\\\"],\\\"deploy\\\":true}\" > $d/s.json && printf \"{\\\"defaults\\\":{\\\"kubernetes_version\\\":\\\"1.32.13\\\",\\\"schema_locations\\\":[\\\"default\\\"],\\\"yamllint_config\\\":\\\"{}\\\",\\\"images\\\":{\\\"yamllint\\\":\\\"y@sha256:1\\\",\\\"kubeconform\\\":\\\"k@sha256:2\\\",\\\"helm\\\":\\\"h@sha256:3\\\",\\\"kustomize\\\":\\\"z@sha256:4\\\"}},\\\"repos\\\":{}}\" > $d/c.json && GITOPS_CI_RUNTIME=$d/rt bash claude/workflow/gitops-ci/bin/gitops-check.sh --repo jkkelley/homelab-gitops --repo-dir $d --select $d/s.json --config $d/c.json'",
      "exit": 1,
      "expect": "GITOPS-CHECK fail"
    },
    {
      "index": 4,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf \"{\\\"yaml\\\":[\\\"a.yaml\\\"],\\\"manifests\\\":[\\\"a.yaml\\\"],\\\"charts\\\":[],\\\"overlays\\\":[\\\"apps/x\\\"],\\\"deploy\\\":true}\" > $d/s.json && printf \"{\\\"defaults\\\":{\\\"kubernetes_version\\\":\\\"1.32.13\\\",\\\"schema_locations\\\":[\\\"default\\\"],\\\"yamllint_config\\\":\\\"{}\\\",\\\"images\\\":{\\\"yamllint\\\":\\\"y@sha256:1\\\",\\\"kubeconform\\\":\\\"k@sha256:2\\\",\\\"helm\\\":\\\"h@sha256:3\\\",\\\"kustomize\\\":\\\"z@sha256:4\\\"}},\\\"repos\\\":{}}\" > $d/c.json && GITOPS_CI_RUNTIME=/nonexistent/rt bash claude/workflow/gitops-ci/bin/gitops-check.sh --repo jkkelley/homelab-gitops --repo-dir $d --select $d/s.json --config $d/c.json'",
      "exit": 4,
      "expect": "ENV-MISSING"
    },
    {
      "index": 5,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'shellcheck -x claude/workflow/gitops-ci/bin/gitops-check.sh'",
      "exit": 0,
      "expect": null
    },
    {
      "index": 6,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/gitops-ci/bin/gitops-check\\.sh)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "claude/workflow/gitops-ci/bin/gitops-check.sh"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-d1be - gitops-check.sh: yamllint, kubeconform, helm template and kustomize build on a gitops-changed selection, in digest-pinned images, PASS/FAIL per target

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

No dotfiles tool validates Kubernetes manifests, charts or kustomize overlays, so a GitOps repo has no lint before Argo CD applies main.

## Owner words

> ORD-1128 K1 gitops CI tooling: tooling ticket first (rule 30): homelab-gitops CI, diff-selected and fast: yamllint and kubeconform on changed manifests, helm template plus kubeconform for changed charts, kustomize build for changed overlays, tracked-ignored-check, md-contents; plus the merge-on-green Action ported (one config entry if the template allows). A gitops merge is a deploy, so merge-on-green there also requires the PR dev and UAT gate evidence named in its ticket (rule 34). (orchestrator brief BR-20261016-infra-design19)

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in, thats a prereq for the ticket ready then, you feel me? (Design principles 101 item 30)

> everything portable, generic, templated out so everybody gets it, NEVER REINVENT THE WHEEL (Design principles 101 item 4)

## Context

Epic WO-20261016-770f holds the design. The selection JSON is the output of claude/workflow/gitops-ci/bin/gitops-changed.sh (WO-20261016-b7ee): {"repo","base","yaml":[],"manifests":[],"charts":[],"overlays":[],"deploy":bool}; config keys and image digests are in claude/workflow/gitops-ci/config/gitops-ci.json from the same ticket (images.yamllint, images.kubeconform, images.helm, images.kustomize, kubernetes_version, schema_locations, yamllint_config). This ticket does not depend on that one: it reads the config path given, and its checks use a hand-written selection and a stub runtime.

New file claude/workflow/gitops-ci/bin/gitops-check.sh, mode 755, bash, set -uo pipefail, rolodex header block (name, purpose, inputs, outputs, writes-to: a mktemp dir per chart, removed on exit, cleanup) as in claude/workflow/pr-flow/bin/pr-flow-config.sh. Usage: gitops-check.sh --repo OWNER/NAME --repo-dir DIR --select FILE [--config FILE]; -h/--help prints usage containing gitops-check.sh, exit 0; bad argument exit 2. Config: --config, else GITOPS_CI_CONFIG, else $HERE/../config/gitops-ci.json, resolved with jq --arg r SLUG ".defaults * (.repos[\$r] // {})". Runtime RT: env GITOPS_CI_RUNTIME if set (must be executable, else print "ENV-MISSING GITOPS_CI_RUNTIME" and exit 4); else podman on PATH; else docker; else print "ENV-MISSING podman docker" and exit 4. KC flags, in this order: -strict -summary -ignore-missing-schemas -kubernetes-version <kubernetes_version> then -schema-location <each schema_locations entry>.

Steps. 1) Pull: for each image a non-empty list needs, "$RT pull -q IMG", retried 3 times with sleep 2, 4, 6; still failing prints "IMAGE-PULL IMG" and exits 4. 2) yamllint: if yaml[] non-empty, $RT run --rm -v "DIR:/work:ro,Z" -w /work IMG_YAMLLINT -d "<yamllint_config>" -- FILES. 3) manifests: if non-empty, $RT run --rm -v "DIR:/work:ro,Z" -w /work IMG_KC KC_FLAGS FILES. 4) charts: per chart dir c, tmp=$(mktemp -d), cp -a DIR/c/. tmp/, if grep -q ^dependencies: tmp/Chart.yaml then $RT run --rm -v "tmp:/work:Z" -w /work IMG_HELM dependency build . ; then $RT run --rm -v "tmp:/work:ro,Z" -w /work IMG_HELM template ci . | $RT run --rm -i IMG_KC KC_FLAGS - (set -o pipefail around the pipe); rm -rf tmp (also on EXIT trap). 5) overlays: per dir o, $RT run --rm -v "DIR:/work:ro,Z" -w /work IMG_KUSTOMIZE build o | $RT run --rm -i IMG_KC KC_FLAGS - with pipefail. Mount at /work and -w /work for every image (the kustomize image keeps its binary in /app and helm works in /apps, so mounting there would hide them). Each step prints one line per target: "PASS <yamllint|manifests|chart|overlay> <target>" or "FAIL ..." (yamllint and manifests use the file count as target, e.g. "PASS manifests 3 files"), or "SKIP <check> none" for an empty list. A failing validation is not retried. End: "GITOPS-CHECK ok" exit 0, or "GITOPS-CHECK fail N" (N failed lines) exit 1. GOOD: one kubeconform run for all changed manifests. NEVER: a validation run on every tracked file of a PR, or an image referenced by tag.

## Scope

**In**

- touches: claude/workflow/gitops-ci/bin/gitops-check.sh (new)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone
- step: write the script exactly as in Context, chmod 755, then run checks 1-6 with bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID
- step: commit 'feat(workflow): gitops-check.sh validates a GitOps selection in pinned images' with the ticket id; no Bump trailer; push, open the PR, leave
- tool: make:claude/workflow/Makefile:image - on main; fallback: image build fails: retry 3 times, then stop with ENV-MISSING and the podman output
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output
- tool: images yamllint, kubeconform, helm, kustomize by digest from config/gitops-ci.json - fallback: pull fails 3 times: exit 4 IMAGE-PULL, CI red, merge-on-green holds; no runtime: exit 4 ENV-MISSING

**Out - non-goals**

- choosing which files to check: gitops-changed.sh (WO-20261016-b7ee) does
- a Make target: the gitops-ci.mk ticket wires it
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the usage prints
  - observed `2026-10-16` check: make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/gitops-ci/bin/gitops-check.sh --help' exit 0 output: usage: gitops-check.sh --repo OWNER/NAME --repo-dir DIR --select FILE [--config FILE]
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/gitops-ci/bin/gitops-check.sh --help'` exit 0 expect /gitops-check\.sh/
- [x] `AC-H2` *(human)* manifests and the overlay output both reach kubeconform with kubernetes-version 1.32.13 (fixture --config, stub runtime)
  - observed `2026-10-16` check: make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "#!/bin/sh
echo "$*" >> $d/log
" > $d/rt && chmod +x $d/rt && printf "{"yaml":["a.yaml"],"manifests":["a.yaml"],"charts":[],"overlays":["apps/x"],"deploy":true}" > $d/s.json && printf "{"defaults":{"kubernetes_version":"1.32.13","schema_locations":["default"],"yamllint_config":"{}","images":{"yamllint":"y@sha256:1","kubeconform":"k@sha256:2","helm":"h@sha256:3","kustomize":"z@sha256:4"}},"repos":{}}" > $d/c.json && GITOPS_CI_RUNTIME=$d/rt bash claude/workflow/gitops-ci/bin/gitops-check.sh --repo jkkelley/homelab-gitops --repo-dir $d --select $d/s.json --config $d/c.json >/dev/null && grep -c "kubernetes-version 1.32.13" $d/log' exit 0 output: 2
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "#!/bin/sh\necho \"\$*\" >> $d/log\n" > $d/rt && chmod +x $d/rt && printf "{\"yaml\":[\"a.yaml\"],\"manifests\":[\"a.yaml\"],\"charts\":[],\"overlays\":[\"apps/x\"],\"deploy\":true}" > $d/s.json && printf "{\"defaults\":{\"kubernetes_version\":\"1.32.13\",\"schema_locations\":[\"default\"],\"yamllint_config\":\"{}\",\"images\":{\"yamllint\":\"y@sha256:1\",\"kubeconform\":\"k@sha256:2\",\"helm\":\"h@sha256:3\",\"kustomize\":\"z@sha256:4\"}},\"repos\":{}}" > $d/c.json && GITOPS_CI_RUNTIME=$d/rt bash claude/workflow/gitops-ci/bin/gitops-check.sh --repo jkkelley/homelab-gitops --repo-dir $d --select $d/s.json --config $d/c.json >/dev/null && grep -c "kubernetes-version 1.32.13" $d/log'` exit 0 expect /^2$/
- [x] `AC-H3` *(human)* a failing validator fails the run
  - observed `2026-10-16` check: make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "#!/bin/sh
case "$*" in *-strict*) exit 1;; esac
" > $d/rt && chmod +x $d/rt && printf "{"yaml":["a.yaml"],"manifests":["a.yaml"],"charts":[],"overlays":["apps/x"],"deploy":true}" > $d/s.json && printf "{"defaults":{"kubernetes_version":"1.32.13","schema_locations":["default"],"yamllint_config":"{}","images":{"yamllint":"y@sha256:1","kubeconform":"k@sha256:2","helm":"h@sha256:3","kustomize":"z@sha256:4"}},"repos":{}}" > $d/c.json && GITOPS_CI_RUNTIME=$d/rt bash claude/workflow/gitops-ci/bin/gitops-check.sh --repo jkkelley/homelab-gitops --repo-dir $d --select $d/s.json --config $d/c.json' exit 1 output: PASS yamllint 1 files FAIL manifests 1 files SKIP chart none FAIL overlay apps/x GITOPS-CHECK fail 2
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "#!/bin/sh\ncase \"\$*\" in *-strict*) exit 1;; esac\n" > $d/rt && chmod +x $d/rt && printf "{\"yaml\":[\"a.yaml\"],\"manifests\":[\"a.yaml\"],\"charts\":[],\"overlays\":[\"apps/x\"],\"deploy\":true}" > $d/s.json && printf "{\"defaults\":{\"kubernetes_version\":\"1.32.13\",\"schema_locations\":[\"default\"],\"yamllint_config\":\"{}\",\"images\":{\"yamllint\":\"y@sha256:1\",\"kubeconform\":\"k@sha256:2\",\"helm\":\"h@sha256:3\",\"kustomize\":\"z@sha256:4\"}},\"repos\":{}}" > $d/c.json && GITOPS_CI_RUNTIME=$d/rt bash claude/workflow/gitops-ci/bin/gitops-check.sh --repo jkkelley/homelab-gitops --repo-dir $d --select $d/s.json --config $d/c.json'` exit 1 expect /GITOPS-CHECK fail/
- [x] `AC-H4` *(human)* a missing runtime stops with exit 4
  - observed `2026-10-16` check: make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "{"yaml":["a.yaml"],"manifests":["a.yaml"],"charts":[],"overlays":["apps/x"],"deploy":true}" > $d/s.json && printf "{"defaults":{"kubernetes_version":"1.32.13","schema_locations":["default"],"yamllint_config":"{}","images":{"yamllint":"y@sha256:1","kubeconform":"k@sha256:2","helm":"h@sha256:3","kustomize":"z@sha256:4"}},"repos":{}}" > $d/c.json && GITOPS_CI_RUNTIME=/nonexistent/rt bash claude/workflow/gitops-ci/bin/gitops-check.sh --repo jkkelley/homelab-gitops --repo-dir $d --select $d/s.json --config $d/c.json' exit 4 output: ENV-MISSING GITOPS_CI_RUNTIME
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "{\"yaml\":[\"a.yaml\"],\"manifests\":[\"a.yaml\"],\"charts\":[],\"overlays\":[\"apps/x\"],\"deploy\":true}" > $d/s.json && printf "{\"defaults\":{\"kubernetes_version\":\"1.32.13\",\"schema_locations\":[\"default\"],\"yamllint_config\":\"{}\",\"images\":{\"yamllint\":\"y@sha256:1\",\"kubeconform\":\"k@sha256:2\",\"helm\":\"h@sha256:3\",\"kustomize\":\"z@sha256:4\"}},\"repos\":{}}" > $d/c.json && GITOPS_CI_RUNTIME=/nonexistent/rt bash claude/workflow/gitops-ci/bin/gitops-check.sh --repo jkkelley/homelab-gitops --repo-dir $d --select $d/s.json --config $d/c.json'` exit 4 expect /ENV-MISSING/
- [x] `AC-H5` *(human)* shellcheck passes
  - observed `2026-10-16` check: make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'shellcheck -x claude/workflow/gitops-ci/bin/gitops-check.sh' exit 0 output:
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'shellcheck -x claude/workflow/gitops-ci/bin/gitops-check.sh'` exit 0
- [x] `AC-H6` *(human)* the diff holds only the In files
  - observed `2026-10-16` check: git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/gitops-ci/bin/gitops-check.sh)$' exit 1 output:
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/gitops-ci/bin/gitops-check\.sh)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/gitops-ci/bin/gitops-check.sh, the check runner, with a fixture --config and a stub runtime

**Cases**

- `TP-1`
  - intent: plain manifests and kustomize output both reach kubeconform with the pinned cluster version, so an invalid object never merges into a deploy repo
  - command: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "#!/bin/sh\necho \"\$*\" >> $d/log\n" > $d/rt && chmod +x $d/rt && printf "{\"yaml\":[\"a.yaml\"],\"manifests\":[\"a.yaml\"],\"charts\":[],\"overlays\":[\"apps/x\"],\"deploy\":true}" > $d/s.json && printf "{\"defaults\":{\"kubernetes_version\":\"1.32.13\",\"schema_locations\":[\"default\"],\"yamllint_config\":\"{}\",\"images\":{\"yamllint\":\"y@sha256:1\",\"kubeconform\":\"k@sha256:2\",\"helm\":\"h@sha256:3\",\"kustomize\":\"z@sha256:4\"}},\"repos\":{}}" > $d/c.json && GITOPS_CI_RUNTIME=$d/rt bash claude/workflow/gitops-ci/bin/gitops-check.sh --repo jkkelley/homelab-gitops --repo-dir $d --select $d/s.json --config $d/c.json >/dev/null && grep -c "kubernetes-version 1.32.13" $d/log'`
  - expected: exit 0 and 2
- `TP-2`
  - intent: a failing validator fails the run, so CI is red and merge-on-green holds
  - command: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "#!/bin/sh\ncase \"\$*\" in *-strict*) exit 1;; esac\n" > $d/rt && chmod +x $d/rt && printf "{\"yaml\":[\"a.yaml\"],\"manifests\":[\"a.yaml\"],\"charts\":[],\"overlays\":[\"apps/x\"],\"deploy\":true}" > $d/s.json && printf "{\"defaults\":{\"kubernetes_version\":\"1.32.13\",\"schema_locations\":[\"default\"],\"yamllint_config\":\"{}\",\"images\":{\"yamllint\":\"y@sha256:1\",\"kubeconform\":\"k@sha256:2\",\"helm\":\"h@sha256:3\",\"kustomize\":\"z@sha256:4\"}},\"repos\":{}}" > $d/c.json && GITOPS_CI_RUNTIME=$d/rt bash claude/workflow/gitops-ci/bin/gitops-check.sh --repo jkkelley/homelab-gitops --repo-dir $d --select $d/s.json --config $d/c.json'`
  - expected: exit 1 and GITOPS-CHECK fail
- `TP-3`
  - intent: no container runtime is a coded stop, never a silent pass
  - command: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "{\"yaml\":[\"a.yaml\"],\"manifests\":[\"a.yaml\"],\"charts\":[],\"overlays\":[\"apps/x\"],\"deploy\":true}" > $d/s.json && printf "{\"defaults\":{\"kubernetes_version\":\"1.32.13\",\"schema_locations\":[\"default\"],\"yamllint_config\":\"{}\",\"images\":{\"yamllint\":\"y@sha256:1\",\"kubeconform\":\"k@sha256:2\",\"helm\":\"h@sha256:3\",\"kustomize\":\"z@sha256:4\"}},\"repos\":{}}" > $d/c.json && GITOPS_CI_RUNTIME=/nonexistent/rt bash claude/workflow/gitops-ci/bin/gitops-check.sh --repo jkkelley/homelab-gitops --repo-dir $d --select $d/s.json --config $d/c.json'`
  - expected: exit 4 and ENV-MISSING

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
