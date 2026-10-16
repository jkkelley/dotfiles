---
{
  "id": "WO-20261016-8031",
  "slug": "port-merge-on-green-yml-to-ypli-01-src-and-ypcon",
  "title": "Port merge-on-green.yml to ypli-01-src and ypconsult-01-src",
  "type": "chore",
  "status": "cancelled",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:08:41+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "superseded_by": "WO-20261016-054b"
}
---

# WO-20261016-8031 - Port merge-on-green.yml to ypli-01-src and ypconsult-01-src

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

ORD-0553 R8: "private repos (ypli PR 14, ypconsult PR 54) refuse auto-merge: the merge script merges them on green until the merge-on-green Action is ported to those repos; cut that port ticket." dotfiles .github/workflows/merge-on-green.yml (PR 188) merges on workflow_run with no --auto, which the free plan refuses on private repositories.

## Scope

**In**

- touches: jkkelley/ypli-01-src: .github/workflows/merge-on-green.yml
- touches: jkkelley/ypconsult-01-src: .github/workflows/merge-on-green.yml
- step: for R in ypli-01-src ypconsult-01-src: clone to `~/.cache/wt-$R-merge-on-green`, branch `chore/merge-on-green`, copy dotfiles origin/main .github/workflows/merge-on-green.yml verbatim, set its DISPATCH list to the workflow names present in that repo's .github/workflows (empty when none need a post-merge run), commit `ci: merge on green (ported from dotfiles, ORD-0553 R8)`, push, `gh pr create -R jkkelley/$R --fill`
- step: until each PR merges, the orchestrator's merge script keeps merging that repo on green (fallback, no change here)
- tool: path:.github/workflows/merge-on-green.yml - on main; fallback: until each port PR merges, the orchestrator merge script merges the repo on green
- tool: cmd:gh - on main; fallback: gh or GitHub down: retry 3 times, then stop with A2A-003 and the gh error in the result blockers

**Out - non-goals**

- changing merge-on-green.yml logic: a port is a verbatim copy
- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `gh pr list -R jkkelley/ypli-01-src --head chore/merge-on-green --json number -q length` exits 0 and its output matches /^1$/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* `gh pr list -R jkkelley/ypconsult-01-src --head chore/merge-on-green --json number -q length` exits 0 and its output matches /^1$/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

```sh
no code changes; the AC commands are the proof
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

Cancelled `2026-10-16` - nothing shipped.

- reason: DESIGN-GAP: verbatim copy of dotfiles' own merge-on-green.yml is inert in ypli and regresses ypconsult; ypconsult already ported (PR 55); recut to render via pr-flow-ci-render.sh
- superseded by: `WO-20261016-054b`

No branch, no PR and no merge commit exist for this work order.

