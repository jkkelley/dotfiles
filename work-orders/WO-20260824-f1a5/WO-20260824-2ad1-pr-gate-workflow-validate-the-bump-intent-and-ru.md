---
{
  "id": "WO-20260824-2ad1",
  "slug": "pr-gate-workflow-validate-the-bump-intent-and-ru",
  "title": "PR gate workflow: validate the bump intent and run the affected suites",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:08-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": null,
  "pr": null,
  "merge_sha": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Reviewed and approved on PR #55 on GitHub, which is where the whole cut was read as one diff. Lavish was offered and declined in favour of the PR.",
    "at": "2026-08-24"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-6acf",
    "WO-20260824-efb0"
  ],
  "blocks": [
    "WO-20260824-316d"
  ]
}
---

# WO-20260824-2ad1 - PR gate workflow: validate the bump intent and run the affected suites

## Problem

Merge-time allocation means the PR carries intent and CI carries out the allocation. If a PR reaches main with an unresolvable or mistyped bump, the publisher fails closed and the failure looks like nothing happening. The gate exists to make that impossible before the merge button rather than after it.

## Scope

**In**

- validating that every trailer names a skill that exists and actually changed, at a legal level, with no skill named twice
- every changed skill resolving to a level, from a trailer or a parseable conventional title
- refusing a hand-edited version: or registry.json, and running verify --structure
- printing the resolution table so the outcome is visible before merge
- a detect job emitting changed skills that ship a suite, and a guarded matrix, one runner per skill
- a separate tools job for claude/tools/, which has no registry row and cannot appear in the matrix
- installing Podman on the runner, because ubuntu-24.04 ships Docker and Rule 14 requires Podman

**Out - non-goals**

- writing anything at all - this workflow only ever reads
- ubuntu-latest, banned by Rule 15

## Acceptance criteria


- [ ] `AC-H1` *(human)* a docs-only PR is green with the matrix skipped and no empty-matrix error
- [ ] `AC-H2` *(human)* a PR editing hydration-prompt runs exactly one matrix leg
- [ ] `AC-H3` *(human)* a PR whose trailer names a skill it did not change is refused, and the message says which

## Test plan

```sh
exercised by real PRs against the repository; the empty-matrix case is the one that only shows up live
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 8 points. Sized above the plan's medium. Three non-trivial shell blocks inside YAML, and CI has the worst iteration loop in the plan - every fix costs a push.

## Outcome

_Written by `work-order close`. Empty until then._
