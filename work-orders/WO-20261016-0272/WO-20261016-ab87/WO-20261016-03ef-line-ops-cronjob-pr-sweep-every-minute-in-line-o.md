---
{
  "id": "WO-20261016-03ef",
  "slug": "line-ops-cronjob-pr-sweep-every-minute-in-line-o",
  "title": "line-ops CronJob pr-sweep: every minute in line-ops and line-ops-uat on line-ops-tools by digest, suspended in base, spec loop L1 retargeted to the pr-flow sweep",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:55:17+00:00",
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
    "WO-20261016-64f2",
    "WO-20261016-5751",
    "WO-20261016-9ad9"
  ],
  "blocks": [
    "WO-20261016-c315"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "kubectl kustomize apps/line-ops/overlays/stable >/dev/null && kubectl kustomize apps/line-ops/overlays/uat >/dev/null && echo RENDER-OK",
      "exit": 0,
      "expect": "RENDER-OK"
    },
    {
      "index": 2,
      "command": "kubectl kustomize apps/line-ops/overlays/stable | grep -cE 'image: ghcr\\.io/jkkelley/line-ops-tools@sha256:[0-9a-f]{64}|^  suspend: true$'",
      "exit": 0,
      "expect": "^2$"
    },
    {
      "index": 3,
      "command": "kubectl kustomize apps/line-ops/overlays/uat | grep -cE 'NATS_HOST: nats\\.line-ops-uat\\.svc:4222|REPO: jkkelley/dotfiles'",
      "exit": 0,
      "expect": "^2$"
    },
    {
      "index": 4,
      "command": "python3 -c \"import xml.dom.minidom,sys;xml.dom.minidom.parse('docs/line-ops/line-ops-spec.xml')\" && test $(wc -l < docs/line-ops/line-ops-spec.xml) -le 1000 && grep -c 'CronJob pr-sweep' docs/line-ops/line-ops-spec.xml",
      "exit": 0,
      "expect": "^[1-9]"
    },
    {
      "index": 5,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(apps/line-ops/(base/(pr-sweep\\.yaml|kustomization\\.yaml)|overlays/(stable|uat)/kustomization\\.yaml)|docs/line-ops/line-ops-spec\\.xml)$'",
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

# WO-20261016-03ef - line-ops CronJob pr-sweep: every minute in line-ops and line-ops-uat on line-ops-tools by digest, suspended in base, spec loop L1 retargeted to the pr-flow sweep

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

The pr-flow sweep is a local loop (dotfiles monitors.json entry pr-flow, make pr-flow-consume); rule 39 puts it on the cluster. homelab-gitops docs/line-ops/line-ops-spec.xml loop L1 and node W5 still name dotfiles tools/merge-train/merge-train.sh, which the merge port replaced with pr-flow-consume.sh sweep (dotfiles PR 312 lineage).

## Owner words

> ORD-1042 G1 (brief BR-20261016-ops-design1): L1 cluster-ops deploy: homelab-gitops app for the bus, merge-on-green sweeps and stuck-watch as CronJobs (rule 39); secrets via external-secrets and Vault, never read a credential

> i don't like agents doing shit when i have a k8s cluster too, automate processes right away (Design principles 101 item 39)

> Have fallbacks too (item 28); Ensure that your testing is dev uat stable. (item 34); And don't ever bog the user down with notifications when testing. (item 35)

## Context

Step 0, image digest: DIGEST=$(gh api /user/packages/container/line-ops-tools/versions --jq '.[0].name'). If that fails or is empty, the image was never pushed: trigger the gitops-builder Jenkins job (jenkins-mcp list_jobs, the job whose name contains gitops-builder; trigger_build with IMAGE_TO_BUILD=line-ops-tools), wait for get_build_status SUCCESS up to 30 minutes, retry once, then read DIGEST again; still empty: stop with A2A-003 and the build log tail.

New apps/line-ops/base/pr-sweep.yaml: ServiceAccount pr-sweep (automountServiceAccountToken: false). CronJob pr-sweep: schedule '* * * * *' (the local loop's 60 s, pr-flow.mk pr-flow-consume INTERVAL default), timeZone Etc/UTC, suspend: true (base; the stable promotion ticket unsuspends stable), concurrencyPolicy Forbid, startingDeadlineSeconds 50, successfulJobsHistoryLimit 1, failedJobsHistoryLimit 1; jobTemplate backoffLimit 0, activeDeadlineSeconds 240 (pr-flow.json budgets.sweep.timeout_s); pod labels app.kubernetes.io/name: pr-sweep and app.kubernetes.io/part-of: line-ops; serviceAccountName pr-sweep; imagePullSecrets ghcr-pull-secret; restartPolicy Never; pod securityContext runAsNonRoot true, runAsUser 1000, fsGroup 1000, seccompProfile RuntimeDefault; container pr-sweep, image ghcr.io/jkkelley/line-ops-tools@<DIGEST> with a comment naming the Jenkins build number, command [bash, /opt/pr-sweep/pr-sweep.sh], envFrom configMapRef pr-sweep-config, env NATS_TOKEN from secret nats-token key token and GH_TOKEN from secret github-token key token (both optional: true, so a missing secret yields SECRET-MISSING exit 2 in the log, not a stuck pod), securityContext allowPrivilegeEscalation false, readOnlyRootFilesystem true, capabilities drop ALL, resources requests cpu 50m memory 128Mi, limits memory 512Mi; volumeMounts script /opt/pr-sweep (configMap pr-sweep-script), work /work (PVC pr-sweep-work), tmp /tmp (emptyDir). Header comment: rule 39 owner words, spec loop L1, and the breadcrumb: why a minute (parity with the local loop), why suspended in base (UAT before stable, item 34), rollback (git revert, Argo CD prunes).

apps/line-ops/base/kustomization.yaml: resources gains ' - pr-sweep.yaml' last; configMapGenerator gains '- name: pr-sweep-script' with files: [pr-sweep.sh], same shape as deadman-script.

apps/line-ops/overlays/stable/kustomization.yaml: configMapGenerator gains pr-sweep-config with literals WORK=/work, DOTFILES_URL=https://github.com/jkkelley/dotfiles.git, DOTFILES_REF=main, CLONE_BASE=https://github.com, NATS_HOST=nats.line-ops.svc:4222, GIT_NAME=line-ops pr-sweep, GIT_EMAIL=pr-sweep@line-ops.invalid. apps/line-ops/overlays/uat/kustomization.yaml: the same with NATS_HOST=nats.line-ops-uat.svc:4222 and REPO=jkkelley/dotfiles (UAT sweeps one repository).

docs/line-ops/line-ops-spec.xml: loop L1 becomes name 'pr-flow sweep' now='herdr pane, make pr-flow-consume (dotfiles)' interval='60s' target='cluster' kind='CronJob pr-sweep' wo='W5'; node W5 input becomes 'dotfiles claude/workflow/pr-flow/bin/pr-flow-consume.sh sweep on main; image ghcr.io/jkkelley/line-ops-tools; GitHub identity via ExternalSecret github-token (homelab/apps/line-ops)', files 'apps/line-ops/base/pr-sweep.yaml apps/line-ops/base/pr-sweep.sh apps/line-ops/base/pr-sweep-secrets.yaml', command 'make -C apps/line-ops gate-uat-pr-sweep'. The file stays under 1000 lines and parses.

Bus credential edge: the pod reads the shared nats-token. WO-20261016-0974 (per-consumer bus creds from Vault) waits on an owner ruling; when it lands it adds a pr-sweep consumer credential and swaps this env's secretKeyRef. Recorded on WO-20261016-0974; this ticket does not wait on it.

## Scope

**In**

- touches: apps/line-ops/base/pr-sweep.yaml (new, as in Context)
- touches: apps/line-ops/base/kustomization.yaml (one resource, one configMapGenerator entry)
- touches: apps/line-ops/overlays/stable/kustomization.yaml (pr-sweep-config)
- touches: apps/line-ops/overlays/uat/kustomization.yaml (pr-sweep-config)
- touches: docs/line-ops/line-ops-spec.xml (loop L1 and node W5 only)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path in dotfiles; dotfiles work-orders/INDEX.md and the epic README.md are ignored generated views
- step: clone or worktree jkkelley/homelab-gitops from origin/main into your own worktree under ~/.cache (git worktree add from ~/projects/homelab-gitops; fallback: git clone), branch feat/<slug>; every path and AC command below runs from that worktree's root
- step: resolve DIGEST per Context step 0
- step: write the five changes exactly as in Context
- step: run make -C apps/line-ops render, make -C apps/line-ops lint and the AC checks only
- step: commit 'feat(line-ops): pr-sweep CronJob, suspended until UAT passes' with the ticket id, push, open the PR on jkkelley/homelab-gitops, leave
- tool: jenkins-mcp trigger_build and get_build_status - fallback: Jenkins down: retry 3 times, then stop with A2A-003
- tool: make:apps/line-ops/Makefile:render, make:apps/line-ops/Makefile:lint - on main; fallback: missing: stop with DESIGN-GAP
- tool: cmd:python3 (xml parse in AC) - fallback: missing: stop with ENV-MISSING python3
- tool: cmd:kubectl (cluster context of the owner's homelab) - fallback: cluster unreachable: retry 3 times 30 s apart, then stop with A2A-003 and the kubectl error; no local substitute
- tool: cmd:git, cmd:gh, cmd:jq, cmd:make - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- unsuspending stable and stopping the local loop: the stable promotion ticket
- the secrets file and pr-sweep.sh: their own tickets
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- waiting on CI or merging: push, open the PR, write the result, leave
- reading, printing or writing any credential value: secrets reach pods only through external-secrets from Vault; the owner seeds Vault
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [free] [fixed] None declared: implement exactly as specified; stop with DESIGN-GAP before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* both overlays render (what make -C apps/line-ops render runs)
  - check: `kubectl kustomize apps/line-ops/overlays/stable >/dev/null && kubectl kustomize apps/line-ops/overlays/uat >/dev/null && echo RENDER-OK` exit 0 expect /RENDER-OK/
- [ ] `AC-H2` *(human)* the CronJob runs the tools image by digest, suspended
  - check: `kubectl kustomize apps/line-ops/overlays/stable | grep -cE 'image: ghcr\.io/jkkelley/line-ops-tools@sha256:[0-9a-f]{64}|^ suspend: true$'` exit 0 expect /^2$/
- [ ] `AC-H3` *(human)* uat points the sweep at the uat bus and one repository
  - check: `kubectl kustomize apps/line-ops/overlays/uat | grep -cE 'NATS_HOST: nats\.line-ops-uat\.svc:4222|REPO: jkkelley/dotfiles'` exit 0 expect /^2$/
- [ ] `AC-H4` *(human)* the spec parses, stays under 1000 lines and names the CronJob
  - check: `python3 -c "import xml.dom.minidom,sys;xml.dom.minidom.parse('docs/line-ops/line-ops-spec.xml')" && test $(wc -l < docs/line-ops/line-ops-spec.xml) -le 1000 && grep -c 'CronJob pr-sweep' docs/line-ops/line-ops-spec.xml` exit 0 expect /^[1-9]/
- [ ] `AC-H5` *(human)* the diff holds only In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(apps/line-ops/(base/(pr-sweep\.yaml|kustomization\.yaml)|overlays/(stable|uat)/kustomization\.yaml)|docs/line-ops/line-ops-spec\.xml)$'` exit 1

## Test plan

```sh
{"scope":"line-ops overlays rendered with kustomize; no cluster write","cases":[{"id":"TP-1","intent":"a floating image or an unsuspended base would run an untested sweep on the real line; render proves the pin and the suspension","command":"AC-H1, AC-H2, AC-H3","expected":"RENDER-OK; 2; 2"}],"isolation":{"runtime":"podman","image":"none: kubectl kustomize is a pure render"},"out_of_scope":["the live run: the UAT gate in the stable promotion ticket"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
