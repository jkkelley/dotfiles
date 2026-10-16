---
{
  "id": "WO-20261016-64f2",
  "slug": "line-ops-tools-image-gitops-builder-builds-ghcr-",
  "title": "line-ops-tools image: gitops-builder builds ghcr.io/jkkelley/line-ops-tools (bash, git, jq, python3-jsonschema, gh 2.101.0, nats) for the cluster pr-sweep",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:51:49+00:00",
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
  "depends_on": [
    "WO-20261016-1099"
  ],
  "blocks": [
    "WO-20261016-03ef"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "podman build -q -t localhost/line-ops-tools:dev -f golden-images/line-ops/Dockerfile.line-ops-tools golden-images/line-ops",
      "exit": 0,
      "expect": null
    },
    {
      "index": 2,
      "command": "podman run --rm localhost/line-ops-tools:dev bash -c 'gh --version | head -1; nats --version; python3 -c \"import jsonschema\" && echo jsonschema-ok; git --version >/dev/null && jq --version >/dev/null && make --version >/dev/null && echo tools-ok; id -u'",
      "exit": 0,
      "expect": "gh version 2\\.101\\.0[\\s\\S]*0\\.5\\.0[\\s\\S]*jsonschema-ok[\\s\\S]*tools-ok[\\s\\S]*^1000$"
    },
    {
      "index": 3,
      "command": "grep -c -E \"'line-ops-tools'|golden-images/line-ops/Dockerfile.line-ops-tools|ghcr.io/jkkelley/line-ops-tools\" Jenkinsfile",
      "exit": 0,
      "expect": "^4$"
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(golden-images/line-ops/Dockerfile\\.line-ops-tools|Jenkinsfile)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ],
  "repo": "jkkelley/gitops-builder"
}
---

# WO-20261016-64f2 - line-ops-tools image: gitops-builder builds ghcr.io/jkkelley/line-ops-tools (bash, git, jq, python3-jsonschema, gh 2.101.0, nats) for the cluster pr-sweep

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

The pr-flow sweep (dotfiles claude/workflow/pr-flow/bin/pr-flow-consume.sh sweep: records, regen, autofix, merge backstop) runs only as a local loop in the pr-flow monitor pane (dotfiles claude/workflow/config/monitors.json entry pr-flow). Rule 39 moves it to a cluster CronJob, and no pinned image carries what it calls: bash, git, jq, python3 with jsonschema (records.sh validates every record), gh 2.50+ (pr update-branch) and the nats CLI (bus.sh with BUS_NATS=nats). nats-box (the deadman's image) has nats and jq but no bash, git, gh or python3.

## Owner words

> ORD-1042 G1 (brief BR-20261016-ops-design1): L1 cluster-ops deploy: homelab-gitops app for the bus, merge-on-green sweeps and stuck-watch as CronJobs (rule 39); secrets via external-secrets and Vault, never read a credential

> i don't like agents doing shit when i have a k8s cluster too, automate processes right away (Design principles 101 item 39)

> Have fallbacks too (item 28); Ensure that your testing is dev uat stable. (item 34); And don't ever bog the user down with notifications when testing. (item 35)

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in, thats a prereq for the ticket ready then (item 30)

## Context

Inventory: gitops-builder origin/main b137f6a builds every golden image with one Jenkinsfile (kaniko, parameter IMAGE_TO_BUILD, one switch case per image, pushes IMAGE_NAME:BUILD_NUMBER and :latest, Trivy scan). Reuse it (item 4); no new pipeline.

File golden-images/line-ops/Dockerfile.line-ops-tools, exactly: ``` # line-ops-tools: what the cluster pr-sweep CronJob (homelab-gitops apps/line-ops/base/pr-sweep.yaml) runs dotfiles' pr-flow sweep with. # Bases pinned by multi-arch list digest (dotfiles Rule 15); the cluster nodes are arm64. gh from its release tarball, sha256 checked per arch, # because Debian bookworm ships gh 2.23.0 and pr-flow-consume.sh calls `gh pr update-branch` (gh 2.50+). Ticket WO id in the commit. FROM docker.io/natsio/nats-box@sha256:be25666441c3aee65193aba33d60ff2f06ede7ee9eba58864324b33d7eb94fea AS nats # nats-box 0.20.0-nonroot FROM docker.io/library/debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251 # debian:bookworm-slim ARG GH_VERSION=2.101.0 ARG GH_SHA256_AMD64=9bca2d1c16825f109907a23307628a2f0698fbf99662b73a5cf0b020293072b8 ARG GH_SHA256_ARM64=b57e8063f18862647c9d22727c32e9da1b963f8bf9db648fe123a6975695640f RUN apt-get update && apt-get install -y --no-install-recommends bash ca-certificates curl git jq make procps python3 python3-jsonschema \ && rm -rf /var/lib/apt/lists/* RUN set -eu; arch=$(dpkg --print-architecture); case $arch in amd64) sum=$GH_SHA256_AMD64 ;; arm64) sum=$GH_SHA256_ARM64 ;; *) echo "unsupported arch $arch"; exit 1 ;; esac; \ curl -fsSL -o /tmp/gh.tgz "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${arch}.tar.gz"; \ echo "$sum /tmp/gh.tgz" | sha256sum -c -; tar -xzf /tmp/gh.tgz -C /tmp; \ install -m 0755 "/tmp/gh_${GH_VERSION}_linux_${arch}/bin/gh" /usr/local/bin/gh; rm -rf /tmp/gh.tgz /tmp/gh_* COPY --from=nats /usr/local/bin/nats /usr/local/bin/nats RUN useradd -u 1000 -m -s /bin/bash sweep USER 1000 WORKDIR /work ```

Jenkinsfile, two edits only: (1) the choices list of parameter IMAGE_TO_BUILD gains 'line-ops-tools' at the end; (2) a case before `default:` in the Init switch, same shape as the others: case 'line-ops-tools': env.IMAGE_NAME = 'ghcr.io/jkkelley/line-ops-tools'; env.DOCKERFILE = "${env.WORKSPACE}/golden-images/line-ops/Dockerfile.line-ops-tools"; env.BUILD_CONTEXT = "${env.WORKSPACE}/golden-images/line-ops"; break.

Evidence for the pins: podman manifest inspect of both digests returns a manifest list with arm64 and amd64; nats-box carries /usr/local/bin/nats (nats --version 0.5.0); gh_2.101.0_checksums.txt from cli/cli release v2.101.0 (published 2026-09-15) gives the two sums above; apt-cache policy gh in the debian digest shows 2.23.0+dfsg1-1, too old for `gh pr update-branch`.

## Scope

**In**

- touches: golden-images/line-ops/Dockerfile.line-ops-tools (new, exactly as in Context)
- touches: Jenkinsfile (choice 'line-ops-tools' and its case, as in Context)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path in dotfiles; dotfiles work-orders/INDEX.md and the epic README.md are ignored generated views
- step: git worktree add from ~/projects/gitops-builder at origin/main into ~/.cache/wt-<slug>, branch feat/line-ops-tools (fallback: git clone); every AC runs from that worktree's root
- step: write the two changes exactly as in Context
- step: podman build -t localhost/line-ops-tools:dev -f golden-images/line-ops/Dockerfile.line-ops-tools golden-images/line-ops (dev gate, item 34), then run the AC checks only
- step: commit 'feat(golden-images): line-ops-tools image for the cluster pr-sweep' with the ticket id, push, open the PR on jkkelley/gitops-builder; the Jenkins build after merge is the first step of the CronJob ticket
- tool: cmd:podman - fallback: missing or no network for pulls: retry 3 times, then stop with ENV-MISSING podman
- tool: cmd:git, cmd:gh, cmd:jq, cmd:make - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- building or pushing the image from Jenkins: the CronJob ticket's first step
- any homelab-gitops file
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- waiting on CI or merging: push, open the PR, write the result, leave
- reading, printing or writing any credential value: secrets reach pods only through external-secrets from Vault; the owner seeds Vault
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [free] [fixed] None declared: implement exactly as specified; stop with DESIGN-GAP before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the image builds from the pinned bases in podman
  - check: `podman build -q -t localhost/line-ops-tools:dev -f golden-images/line-ops/Dockerfile.line-ops-tools golden-images/line-ops` exit 0
- [ ] `AC-H2` *(human)* every tool the sweep calls is in the image at the pinned version, as uid 1000
  - check: `podman run --rm localhost/line-ops-tools:dev bash -c 'gh --version | head -1; nats --version; python3 -c "import jsonschema" && echo jsonschema-ok; git --version >/dev/null && jq --version >/dev/null && make --version >/dev/null && echo tools-ok; id -u'` exit 0 expect /gh version 2\.101\.0[\s\S]*0\.5\.0[\s\S]*jsonschema-ok[\s\S]*tools-ok[\s\S]*^1000$/
- [ ] `AC-H3` *(human)* the Jenkinsfile offers the image and maps it to its Dockerfile
  - check: `grep -c -E "'line-ops-tools'|golden-images/line-ops/Dockerfile.line-ops-tools|ghcr.io/jkkelley/line-ops-tools" Jenkinsfile` exit 0 expect /^4$/
- [ ] `AC-H4` *(human)* the diff holds only In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(golden-images/line-ops/Dockerfile\.line-ops-tools|Jenkinsfile)$'` exit 1

## Test plan

```sh
{"scope":"the line-ops-tools Dockerfile built locally in podman","cases":[{"id":"TP-1","intent":"the cluster sweep dies at its first call if one tool is missing or too old; the image must carry every tool at the pinned version and run as non-root","command":"AC-H1 then AC-H2 commands","expected":"build exit 0; gh 2.101.0, nats 0.5.0, jsonschema-ok, tools-ok, uid 1000"}],"isolation":{"runtime":"podman","image":"localhost/line-ops-tools:dev"},"out_of_scope":["the Jenkins build and push: after merge","arm64 run: the cluster UAT gate"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
