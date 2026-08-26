---
{
  "id": "WO-20260826-9037",
  "slug": "credential-rotation-workflow-kms-free-tier-fix",
  "title": "Credential rotation workflow - KMS free tier fix",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-08-26",
  "updated": "2026-08-26",
  "created_at": "2026-08-26T11:31:18-05:00",
  "parent": null,
  "branch": "feat/credential-rotation-workflow-kms-free-tier-fix",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Scope was agreed in the session that produced the three gitops pull requests and was restated back verbatim as the Phase 4 item list; the user asked for the work to start rather than for another review surface.",
    "at": "2026-08-26"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20260826-9037 - Credential rotation workflow - KMS free tier fix

## Problem

The 12 SSM-backed ExternalSecrets move from refreshInterval 1h to 168h to stop burning the KMS free tier. At 1h a rotated credential propagated on its own within the hour; at 168h it does not, for up to a week. There is no written procedure for rotating one of the 14 SSM credentials and getting the cluster onto the new value, no record of which credentials exist or how they fan out, and no way to tell which are overdue or which are currently serving a stale value.

## Scope

**In**

- workflows/credential-rotation.md, the procedure, version-stamped by workflow-version.sh
- a manifest of the 14 SSM credentials: pointers, rotation interval, coexist flag, and every consuming ExternalSecret
- a driver with list, due, verify and rotate --dry-run
- a Podman suite for the driver, network off, source mounted read-only

**Out - non-goals**

- minting a new credential at the provider - GitHub, Slack, Google and Anthropic stay human
- rotating the 16 Vault-backed secrets - different store, different path, not this ticket
- changing refreshInterval or refreshPolicy - that ships in the three gitops pull requests
- running the rotation on a schedule - due reports, a human decides
- storing any credential value, anywhere in this repository

## Acceptance criteria


- [x] `AC-H1` *(human)* tools/workflow-version.sh verify exits 0 and lists credential-rotation
  - observed `2026-08-26` tools/workflow-version.sh verify exits 0: 'ok - 2 workflow document(s) versioned'. list prints close-out-procedure 1.0.0 and credential-rotation 1.0.0. The tools suite also gained a check that a supporting directory beside a document is not counted as one, since workflows/credential-rotation/ is the first of those.
- [x] `AC-H2` *(human)* the driver suite is green in Podman with --network=none and the source mounted read-only
  - observed `2026-08-26` workflows/credential-rotation/testing/run-tests.sh: PASS 75 FAIL 0, in podman with --network=none, /repo mounted ro and outputs forced into a scratch mount. Two closing checks cmp the copied script and manifest against the originals, so the read-only guarantee is asserted rather than assumed. tools/testing/run-tests.sh is PASS 38 FAIL 0 alongside it.
- [x] `AC-H3` *(human)* due reports an overdue credential from the manifest without reading any parameter value
  - observed `2026-08-26` Offline: 'due exits 2 when something is overdue', 'due names the overdue credential' matching OVERDUE by Nd, and 'due never called get-parameter - no KMS request was spent' asserted against a logged stub, plus 'due did not touch the cluster'. Live against the real account: due reported github-pat last changed 2026-04-30, 117 days against a 90-day policy, OVERDUE by 27d, from describe-parameters metadata only.
- [x] `AC-H4` *(human)* verify detects a cluster serving a value older than the parameter, and spends no KMS call doing it
  - observed `2026-08-26` Offline: 'verify exits 2 when the cluster is behind the parameter' and 'verify says STALE and by how much', with 'the stale path still spends no KMS request' asserted on the stub call log. Cost is pinned by two more checks - exactly one aws call and exactly one kubectl call per run. Live: verify returned 0 with all 17 consumer rows in sync and made no get-parameter call.
- [x] `AC-H5` *(human)* rotate --dry-run prints every consumer of the shared PAT and writes nothing
  - observed `2026-08-26` Offline: 'dry run listed all four consumers of the shared PAT', 'dry run named every one of the four namespaces' checking argocd, job-hunter, jenkins and prospector individually, 'dry run really wrote nothing' against the stub log, and 'dry run did not print the new value'. Live verify confirmed the same four namespaces resolve from the real cluster, so the fan-out is real and not a fixture artefact.
- [x] `AC-H6` *(human)* the manifest carries all 14 credentials and no credential value, no AWS account id and no real GitHub owner
  - observed `2026-08-26` credentials.tsv holds 14 rows, asserted by 'list reports 14 credentials'. Five negative checks run against the real file: no 12-digit account id, no arn:aws, no IP address, no ghp_/github_pat_/sk-/xox/AKIA token shape, no https URL. A sixth asserts every row is exactly id, a path starting with /, an integer and yes-or-no, so nothing else can hide in it. Consumer object names are absent by design - the driver discovers them from the cluster.

## Test plan

```sh
bash workflows/credential-rotation/testing/run-tests.sh - builds the pinned image, then runs every case with --network=none, /repo read-only and outputs forced into a scratch mount
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
