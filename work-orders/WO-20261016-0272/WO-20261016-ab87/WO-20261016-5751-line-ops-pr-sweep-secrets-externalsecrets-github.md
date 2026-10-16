---
{
  "id": "WO-20261016-5751",
  "slug": "line-ops-pr-sweep-secrets-externalsecrets-github",
  "title": "line-ops pr-sweep secrets: ExternalSecrets github-token and ghcr-pull-secret from Vault homelab/apps/line-ops, PVC pr-sweep-work, seed doc keys",
  "type": "feature",
  "status": "in-review",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:53:42+00:00",
  "parent": "WO-20261016-ab87",
  "branch": "feat/5751-line-ops-pr-sweep-secrets-externalsecrets-github",
  "pr": 104,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "ops-design1 cut for ORD-1042 G1 cluster-ops; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-03ef"
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
      "command": "kubectl kustomize apps/line-ops/overlays/uat | grep -cE '^  name: (github-token|ghcr-pull-secret|pr-sweep-work)$'",
      "exit": 0,
      "expect": "^3$"
    },
    {
      "index": 3,
      "command": "grep -oE 'key: homelab/apps/line-ops, property: github-(pat|username)' apps/line-ops/base/pr-sweep-secrets.yaml | sort -u | wc -l",
      "exit": 0,
      "expect": "^2$"
    },
    {
      "index": 4,
      "command": "grep -cE 'github-(username|pat)' docs/line-ops/vault-seed-line-ops.md",
      "exit": 0,
      "expect": "^[2-9]"
    },
    {
      "index": 5,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(apps/line-ops/base/(pr-sweep-secrets\\.yaml|kustomization\\.yaml|vault-store\\.yaml)|docs/line-ops/vault-seed-line-ops\\.md)$'",
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

# WO-20261016-5751 - line-ops pr-sweep secrets: ExternalSecrets github-token and ghcr-pull-secret from Vault homelab/apps/line-ops, PVC pr-sweep-work, seed doc keys

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

The cluster pr-sweep needs a GitHub identity (gh merges, pushes and reruns; ghcr pull) and a volume that keeps clones and the post-once ledger between runs. line-ops has only nats-token (ESO Password generator) and ntfy-topic (Vault). Credentials reach pods only through external-secrets from Vault (rule 39, item 25).

## Owner words

> ORD-1042 G1 (brief BR-20261016-ops-design1): L1 cluster-ops deploy: homelab-gitops app for the bus, merge-on-green sweeps and stuck-watch as CronJobs (rule 39); secrets via external-secrets and Vault, never read a credential

> i don't like agents doing shit when i have a k8s cluster too, automate processes right away (Design principles 101 item 39)

> Have fallbacks too (item 28); Ensure that your testing is dev uat stable. (item 34); And don't ever bog the user down with notifications when testing. (item 35)

## Context

Inventory homelab-gitops origin/main 26dc819: apps/line-ops/base/vault-store.yaml holds SecretStore vault-backend (role line-ops-vault-eso, policy line-ops-read on secret/data/homelab/apps/line-ops, sync wave 5) and ExternalSecret ntfy-topic; storage classes longhorn and longhorn-static exist (kubectl get sc). Keeping both new keys under homelab/apps/line-ops means the existing policy covers them, no Vault policy change.

New file apps/line-ops/base/pr-sweep-secrets.yaml, exactly: ``` # pr-sweep secrets and work volume (dotfiles ticket in the commit). Spec: docs/line-ops/line-ops-spec.xml loop L1. # The GitHub identity the sweep merges, pushes regen and autofix commits, and pulls its image with. Owner-seeded in # Vault (docs/line-ops/vault-seed-line-ops.md), read only through ESO; wave 5 with the store, so an unseeded key never # holds the bus back (lesson: PR 100). apiVersion: external-secrets.io/v1 kind: ExternalSecret metadata: name: github-token annotations: argocd.argoproj.io/sync-wave: "5" spec: refreshInterval: 1h secretStoreRef: {kind: SecretStore, name: vault-backend} target: {name: github-token, creationPolicy: Owner} data: - secretKey: token remoteRef: {key: homelab/apps/line-ops, property: github-pat} --- # ghcr.io pull secret for the private line-ops-tools image; template copied from helm/resume-star-infra/templates/externalsecret-ghcr.yaml. apiVersion: external-secrets.io/v1 kind: ExternalSecret metadata: name: ghcr-pull-secret annotations: argocd.argoproj.io/sync-wave: "5" spec: refreshInterval: 1h secretStoreRef: {kind: SecretStore, name: vault-backend} target: name: ghcr-pull-secret creationPolicy: Owner template: type: kubernetes.io/dockerconfigjson engineVersion: v2 data: .dockerconfigjson: '{"auths":{"ghcr.io":{"username":"{{ .username }}","password":"{{ .pat }}","auth":"{{ printf "%s:%s" .username .pat | b64enc }}"}}}' data: - secretKey: username remoteRef: {key: homelab/apps/line-ops, property: github-username} - secretKey: pat remoteRef: {key: homelab/apps/line-ops, property: github-pat} --- # Clones and the sweep's post-once ledger (PR_FLOW_STATE) survive between runs, so a record is never posted twice. apiVersion: v1 kind: PersistentVolumeClaim metadata: name: pr-sweep-work spec: accessModes: [ReadWriteOnce] storageClassName: longhorn resources: requests: {storage: 2Gi} ```

apps/line-ops/base/kustomization.yaml: append ' - pr-sweep-secrets.yaml' as the last entry of resources; nothing else.

apps/line-ops/base/vault-store.yaml: the header comment line '# keys secret/homelab/apps/line-ops ntfy-topic, ntfy-test-topic' becomes '# keys secret/homelab/apps/line-ops ntfy-topic, ntfy-test-topic, github-username, github-pat'; no manifest change.

docs/line-ops/vault-seed-line-ops.md: add the two keys to its key list with one line each: github-username (the GitHub login the sweep acts as) and github-pat (classic PAT, scopes repo, workflow, read:packages: merge, push regen and autofix commits that start CI, rerun workflows, pull ghcr.io/jkkelley/line-ops-tools). The owner seeds them; no agent writes Vault.

Owner edge: until the owner seeds the two keys, both ExternalSecrets report SecretSyncedError and the CronJob stays suspended (base suspend: true in the CronJob ticket); nothing else waits on them.

## Scope

**In**

- touches: apps/line-ops/base/pr-sweep-secrets.yaml (new, exactly as in Context)
- touches: apps/line-ops/base/kustomization.yaml (one resources entry)
- touches: apps/line-ops/base/vault-store.yaml (header comment keys line only)
- touches: docs/line-ops/vault-seed-line-ops.md (two keys)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path in dotfiles; dotfiles work-orders/INDEX.md and the epic README.md are ignored generated views
- step: clone or worktree jkkelley/homelab-gitops from origin/main into your own worktree under ~/.cache (git worktree add from ~/projects/homelab-gitops; fallback: git clone), branch feat/<slug>; every path and AC command below runs from that worktree's root
- step: write the four changes exactly as in Context
- step: run make -C apps/line-ops render and make -C apps/line-ops lint and the AC checks only; CI runs the rest
- step: commit 'feat(line-ops): pr-sweep secrets from Vault and its work volume' with the ticket id, push, open the PR on jkkelley/homelab-gitops, leave
- tool: make:apps/line-ops/Makefile:render, make:apps/line-ops/Makefile:lint - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:kubectl (cluster context of the owner's homelab) - fallback: cluster unreachable: retry 3 times 30 s apart, then stop with A2A-003 and the kubectl error; no local substitute
- tool: cmd:git, cmd:gh, cmd:jq, cmd:make - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- the CronJob, its script and the overlays: their own tickets
- seeding Vault: the owner (Bearings card)
- any Vault policy or role change
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- waiting on CI or merging: push, open the PR, write the result, leave
- reading, printing or writing any credential value: secrets reach pods only through external-secrets from Vault; the owner seeds Vault
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [free] [fixed] None declared: implement exactly as specified; stop with DESIGN-GAP before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* both overlays render (what make -C apps/line-ops render runs)
  - observed `2026-10-16` run in homelab-gitops worktree: RENDER-OK exit 0 (make -C apps/line-ops render, lint LINT-OK); PR 104
  - check: `kubectl kustomize apps/line-ops/overlays/stable >/dev/null && kubectl kustomize apps/line-ops/overlays/uat >/dev/null && echo RENDER-OK` exit 0 expect /RENDER-OK/
- [x] `AC-H2` *(human)* the uat render carries both ExternalSecrets and the PVC
  - observed `2026-10-16` grep -cE name-pattern on uat render: 3, exit 0
  - check: `kubectl kustomize apps/line-ops/overlays/uat | grep -cE '^ name: (github-token|ghcr-pull-secret|pr-sweep-work)$'` exit 0 expect /^3$/
- [x] `AC-H3` *(human)* every key comes from the one path the line-ops policy reads
  - observed `2026-10-16` grep|sort -u|wc -l: 2, exit 0
  - check: `grep -oE 'key: homelab/apps/line-ops, property: github-(pat|username)' apps/line-ops/base/pr-sweep-secrets.yaml | sort -u | wc -l` exit 0 expect /^2$/
- [x] `AC-H4` *(human)* the seed doc names both keys
  - observed `2026-10-16` grep -cE github-(username|pat) on seed doc: 2, exit 0
  - check: `grep -cE 'github-(username|pat)' docs/line-ops/vault-seed-line-ops.md` exit 0 expect /^[2-9]/
- [x] `AC-H5` *(human)* the diff holds only In files
  - observed `2026-10-16` check: git diff --name-only origin/main...HEAD | grep -vE '^(apps/line-ops/base/(pr-sweep-secrets.yaml|kustomization.yaml|vault-store.yaml)|docs/line-ops/vault-seed-line-ops.md)$' exit 1 output:
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(apps/line-ops/base/(pr-sweep-secrets\.yaml|kustomization\.yaml|vault-store\.yaml)|docs/line-ops/vault-seed-line-ops\.md)$'` exit 1

## Test plan

```sh
{"scope":"line-ops overlays rendered with kustomize, no cluster write","cases":[{"id":"TP-1","intent":"a wrong key path or missing resource fails silently in Argo CD; render proves the objects and paths before merge","command":"make -C apps/line-ops render; AC-H2; AC-H3","expected":"RENDER-OK; 3; 2"}],"isolation":{"runtime":"podman","image":"none: kubectl kustomize is a pure render (podman not needed)"},"out_of_scope":["Vault seed and ESO sync: owner, then the UAT gate ticket"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
