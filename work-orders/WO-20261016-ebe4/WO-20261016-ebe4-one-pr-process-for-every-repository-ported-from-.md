---
{
  "id": "WO-20261016-ebe4",
  "slug": "one-pr-process-for-every-repository-ported-from-",
  "title": "One PR process for every repository, ported from coq",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:13:35+00:00",
  "parent": null,
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-ebe4 - One PR process for every repository, ported from coq

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

dotfiles merge-train was written new and does not reuse coq's proven merge flow (line/bin/merge.sh, factory/bin/gate.sh); open PRs pile up (06:15Z: dotfiles 7, business 3, ypconsult-01-src 10)

## Scope

**In**

- port coq merge.sh and gate.sh as claude/workflow/pr-flow, config per repository, records on the NATS bus
- merge-train becomes a wrapper, old body retired

**Out - non-goals**

- rewriting the merge decision
- old YieldPoint repositories

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* spec maps each coq step to its ported file
- [ ] `AC-H2` *(human)* a green, approved PR merges within 2 minutes of its last gate record, shown by bus timing
- [ ] `AC-H3` *(human)* open PR count across the stable repositories falls to only those not green or not approved
- [ ] `AC-H4` *(human)* PR process DAG published in dotfiles and linked globally

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
