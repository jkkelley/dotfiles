---
{
  "id": "WO-20261016-0974",
  "slug": "cluster-bus-nats-with-tls-per-consumer-creds-fro",
  "title": "Cluster bus: NATS with TLS, per-consumer creds from Vault via external-secrets, namespace NetworkPolicy",
  "type": "feature",
  "status": "cancelled",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:08:46+00:00",
  "parent": "WO-20261016-ab87",
  "branch": null,
  "pr": null,
  "closed": "2026-10-16",
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "superseded_by": null
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

- [ ] Which homelab-gitops app directory, ClusterSecretStore and Vault path does the NATS deployment use?

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

Cancelled `2026-10-16` - nothing shipped.

- reason: moved to homelab-gitops per ORD-0616 G4: W13 WO-20261016-672d in jkkelley/homelab-gitops PR 103

No branch, no PR and no merge commit exist for this work order.

