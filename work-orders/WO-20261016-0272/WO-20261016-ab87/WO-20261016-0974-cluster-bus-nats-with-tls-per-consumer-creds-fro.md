---
{
  "id": "WO-20261016-0974",
  "slug": "cluster-bus-nats-with-tls-per-consumer-creds-fro",
  "title": "Cluster bus: NATS with TLS, per-consumer creds from Vault via external-secrets, namespace NetworkPolicy",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:08:46+00:00",
  "parent": "WO-20261016-ab87",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-0974 - Cluster bus: NATS with TLS, per-consumer creds from Vault via external-secrets, namespace NetworkPolicy

## Contents

- Problem
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

ORD-0553 R1 ruling, bus security: "cluster bus uses TLS plus per-consumer creds from Vault via external-secrets and a namespace NetworkPolicy. infra-design cuts the ticket." Item 39: workloads from homelab-gitops via Argo CD.

## Scope

**In**

- touches: homelab-gitops: paths not inventoried yet (DESIGN-GAP)
- step: held in draft: the homelab-gitops layout (app dir, ExternalSecret store name, Vault path) is not inventoried; the cluster-ops design seat fills files and commands before approve
- tool: cmd:kubectl - on main; fallback: cluster unreachable: stop with A2A-003; no local substitute

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `kubectl -n <ns> get networkpolicy -o name` exits 0 and its output matches /networkpolicy/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

```sh
no code changes; the AC commands are the proof
```

## Assumptions

_none_

## Open questions

- [x] Which homelab-gitops app directory, ClusterSecretStore and Vault path does the NATS deployment use?
  - answer `2026-10-16` homelab-gitops origin/main: app apps/line-ops (base + overlays/stable, overlays/uat; Makefile targets render, lint, gate-dev, gate-uat, gate-stable); Argo CD apps argocd-apps/workloads/line-ops.yaml and line-ops-uat.yaml (NATS Helm chart 2.15.1 + overlay, token auth from ESO Password generator nats-token, Service LoadBalancer); store is the namespaced SecretStore vault-backend (apps/line-ops/base/vault-store.yaml, sync wave 5), not a ClusterSecretStore; Vault path secret/homelab/apps/line-ops, role line-ops-vault-eso, seed doc docs/line-ops/vault-seed-line-ops.md; TLS issuer ClusterIssuer local-ca-issuer; no NetworkPolicy exists in the repo.

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` ops-design1 edge (ORD-1042 G1): CronJob pr-sweep (WO-20261016-03ef) reads the shared nats-token key token; when this ticket's ruling lands, add a pr-sweep consumer credential and swap that env's secretKeyRef in apps/line-ops/base/pr-sweep.yaml. Order after WO-20261016-03ef: both touch apps/line-ops/base/kustomization.yaml.
- `2026-10-16` DESIGN-GAP (infra-design12 inventory of homelab-gitops origin/main): held in draft, two facts not fixed on main. (1) TLS SAN for local units: bus-env.sh connects local units to the LoadBalancer IP read at runtime (svc line-ops/nats .status.loadBalancer.ingress[0].ip); no pinned IP or MetalLB pool exists in homelab-gitops, so the cert-manager Certificate (issuer local-ca-issuer) cannot carry the IP SAN the local units verify against: needs the fixed LB IP (metallb.universe.tf/loadBalancerIPs) or a DNS name for the bus. (2) Ruling conflict: ORD-0553 R1 says per-consumer creds from Vault via external-secrets, but apps/line-ops/base/nats-token.yaml generates the bus credential in-cluster with the ESO Password generator 'never in Vault', and vault-store.yaml holds SecretStore vault-backend at sync wave 5 because an unseeded store blocks earlier waves (PR 99); Vault-sourced NATS users would make the bus wait on the owner seed. Needs an owner ruling: Vault keys (owner seeds nats-pass-<consumer> under secret/homelab/apps/line-ops, bus waits) or ESO Password generator per consumer. Also: homelab-gitops draft WO-20261016-9126 (W1-W4 NATS bus, bus-init and deadman) shares argocd-apps/workloads/line-ops.yaml and must be ordered against this ticket.

## Outcome

_Written by `work-order done`. Empty until then._
