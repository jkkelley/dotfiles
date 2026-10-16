---
{
  "id": "WO-20261016-3efc",
  "slug": "merge-train-batches-green-prs-by-dag-layer-and-a",
  "title": "merge-train batches green PRs by DAG layer and area, promoted dev, UAT, stable together on a cadence",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:58:40+00:00",
  "parent": "WO-20261016-3610",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-cd3f"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-3efc - merge-train batches green PRs by DAG layer and area, promoted dev, UAT, stable together on a cadence

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

tools/merge-train/merge-train.sh merges per PR on CI state alone; items 34 and 38 need batch promotion with evidence gates

## Scope

**In**

- batch grouping of green PRs by DAG layer and area
- cadence from config, default every 30 minutes, passed as VAR=value through make
- dev, UAT and stable gates per batch, each a Make target with its test plan
- a PR merges only when its batch has dev and UAT evidence; stable promotion follows merge with a scripted rollback
- start and end of every batch emitted on the bus (item 37)

**Out - non-goals**

- changing CI workflows
- the evidence record format itself, which waits on ruling RR-20261016-01

## Degrees of freedom

- [free] batch key derivation, as long as two PRs that touch the same file never land in the same concurrent batch

## Acceptance criteria

- [ ] `AC-H1` *(human)* make merge-train REPO= BATCH=1 groups green PRs into batches by layer and area and prints them as JSON
- [ ] `AC-H2` *(human)* a PR without dev and UAT evidence is skipped with reason no-evidence and is not merged
- [ ] `AC-H3` *(human)* CADENCE= from config or argument sets the batch interval, default 30 minutes
- [ ] `AC-H4` *(human)* a failed stable gate runs the scripted rollback and reports it

## Test plan

```sh
see the --type test sibling
```

## Assumptions

_none_

## Open questions

- [ ] RR-20261016-01: which field carries per-gate evidence and how merge-train finds it for a PR (result.gates keyed by PR url, or a PR-body evidence section)

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
