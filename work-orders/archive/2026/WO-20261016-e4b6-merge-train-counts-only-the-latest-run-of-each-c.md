---
{
  "id": "WO-20261016-e4b6",
  "slug": "merge-train-counts-only-the-latest-run-of-each-c",
  "title": "merge-train counts only the latest run of each check",
  "type": "bug",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:53:22+00:00",
  "parent": "WO-20261016-949a",
  "branch": "feat/merge-train-counts-only-the-latest-run-of-each-c",
  "pr": 156,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "owner: i approved of everything (brief BR-20261016-spec-check)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-e4b6 - merge-train counts only the latest run of each check

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

make merge-train skipped green #152 as ci-failed: a superseded CANCELLED bump intent run sat beside the newer SUCCESS in statusCheckRollup.

## Scope

**In**

- files: tools/merge-train/merge-train.sh, tools/merge-train/tests/test_merge_train.sh
- commands: make -C tools/merge-train test; make -C tools/merge-train merge-train REPO=jkkelley/dotfiles DRY=1
- docs: ~/AGENTS.md Design principles 101 items 21, 22

**Out - non-goals**

- ignoring CANCELLED outright

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* a cancelled run superseded by a green rerun merges; a green run superseded by a red rerun stays ci-failed
  - observed `2026-10-16` #10 merges, #11 ci-failed; old code fails: /home/luna/.local/state/zenith/log/2026/10/20261016-045324-merge-train-superseded.txt
- [x] `AC-H2` *(human)* evidence: repro command and output written by claude/tools/artifact/artifact.sh new --key log to the artifact store
  - observed `2026-10-16` evidence: /home/luna/.local/state/zenith/log/2026/10/20261016-045324-merge-train-superseded.txt

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
