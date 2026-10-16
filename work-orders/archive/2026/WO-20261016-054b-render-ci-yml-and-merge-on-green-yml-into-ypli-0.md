---
{
  "id": "WO-20261016-054b",
  "slug": "render-ci-yml-and-merge-on-green-yml-into-ypli-0",
  "title": "Render ci.yml and merge-on-green.yml into ypli-01-src; ypconsult-01-src already ported",
  "type": "chore",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:46:33+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": "feat/render-ci-yml-and-merge-on-green-yml-into-ypli-0",
  "pr": 203,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design2 recut closing DESIGN-GAP on WO-20261016-8031; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-054b - Render ci.yml and merge-on-green.yml into ypli-01-src; ypconsult-01-src already ported

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

ORD-0553 R8: "private repos (ypli PR 14, ypconsult PR 54) refuse auto-merge: the merge script merges them on green until the merge-on-green Action is ported to those repos; cut that port ticket." Recut of WO-20261016-8031 (DESIGN-GAP from seat mog-port, evidence /home/luna/.local/state/zenith/inbox-triage/20261015/mog-port-result.json). Facts, 2026-10-16T06:45Z: (1) jkkelley/ypconsult-01-src main .github/workflows/merge-on-green.yml (PR 55) is byte-identical to `bash claude/workflow/pr-flow/bin/pr-flow-ci-render.sh --template merge-on-green` with defaults (WORKFLOWS ["ci"], REQUIRED_CHECK ci-ok, DISPATCH empty), so ypconsult needs no change and is verified by AC only. (2) jkkelley/ypli-01-src has no .github/workflows; its Makefile has the same targets as ypconsult (setup, lint, typecheck, test, validate, lint-all, typecheck-all, test-all), so it gets ci.yml rendered with ypconsult's values (whose ci.yml is that render) plus merge-on-green.yml at defaults. The rendered ci.yml carries the always-run ci-ok check, so ypli PRs stop being zero-check PRs (RR-orch-4). The old ticket's verbatim copy of dotfiles' own workflow file was wrong: the renderer and its templates are the port source (pr-process.md section 8).

## Scope

**In**

- touches: jkkelley/ypli-01-src: .github/workflows/ci.yml (new, rendered)
- touches: jkkelley/ypli-01-src: .github/workflows/merge-on-green.yml (new, rendered)
- touches: jkkelley/ypconsult-01-src: none (read-only AC check)
- touches (generated, written only by work-order.sh start/submit/done in dotfiles, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-0272/WO-20261016-fb0c/README.md
- step: `test -d ~/.cache/wt-ypli-01-src-merge-on-green || gh repo clone jkkelley/ypli-01-src ~/.cache/wt-ypli-01-src-merge-on-green`; then `git -C ~/.cache/wt-ypli-01-src-merge-on-green fetch origin` and `git -C ~/.cache/wt-ypli-01-src-merge-on-green checkout -B chore/merge-on-green origin/main` (idempotent from any state)
- step: from the dotfiles worktree: `bash claude/workflow/pr-flow/bin/pr-flow-ci-render.sh --template ci --set PR_TARGETS='["lint","typecheck","test","validate"]' --set MAIN_TARGETS='["lint-all","typecheck-all","test-all","validate"]' --set SETUP=setup --set CACHE_PATHS='~/.cache/uv' --out ~/.cache/wt-ypli-01-src-merge-on-green/.github/workflows/ci.yml`
- step: `bash claude/workflow/pr-flow/bin/pr-flow-ci-render.sh --template merge-on-green --out ~/.cache/wt-ypli-01-src-merge-on-green/.github/workflows/merge-on-green.yml` (defaults: WORKFLOWS ["ci"], REQUIRED_CHECK ci-ok, DISPATCH empty, since ypli has no other workflow)
- step: `git -C ~/.cache/wt-ypli-01-src-merge-on-green add .github/workflows`, `git -C ~/.cache/wt-ypli-01-src-merge-on-green commit -m 'ci: smart CI and merge on green (rendered by dotfiles pr-flow-ci-render.sh, ORD-0553 R8)'`, `git -C ~/.cache/wt-ypli-01-src-merge-on-green push -u origin chore/merge-on-green --force-with-lease`
- step: `gh pr list -R jkkelley/ypli-01-src --head chore/merge-on-green --json number -q length`; when 0, `gh pr create -R jkkelley/ypli-01-src --head chore/merge-on-green --title 'ci: smart CI and merge on green' --body 'Rendered by dotfiles claude/workflow/pr-flow/bin/pr-flow-ci-render.sh (ORD-0553 R8). ci-ok gives every PR one required check.'`
- step: `rm -rf ~/.cache/wt-ypli-01-src-merge-on-green` after the PR exists (item 11)
- tool: path:claude/workflow/pr-flow/bin/pr-flow-ci-render.sh - on main; fallback: missing or exit 2: stop with DESIGN-GAP naming it; never hand-edit a template copy
- tool: path:claude/workflow/pr-flow/templates/ci.yml and templates/merge-on-green.yml - on main; fallback: missing: stop with DESIGN-GAP naming the file
- tool: cmd:gh - on main; fallback: gh or GitHub down: retry 3 times, then stop with A2A-003 and the gh error in the result blockers
- tool: cmd:git - on main; fallback: push refused: retry 3 times, then stop with A2A-003 and the git error in the result blockers
- tool: cmd:jq - required by the renderer; fallback: missing: stop with ENV-MISSING naming it
- tool: merge path - until the ypli PR merges, the orchestrator merge script merges ypli-01-src on green (fallback, no change here)

**Out - non-goals**

- any change to jkkelley/ypconsult-01-src: PR 55 already carries the rendered merge-on-green.yml and ci.yml
- editing the templates or the renderer: repo values pass as --set
- work-orders/INDEX.md, the ticket file or the parent README by hand: work-order.sh writes them, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1); their close-out diff is allowed
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* `gh api repos/jkkelley/ypconsult-01-src/contents/.github/workflows/merge-on-green.yml -q .content | base64 -d | diff - <(bash claude/workflow/pr-flow/bin/pr-flow-ci-render.sh --template merge-on-green)` exits 0 and prints nothing (ypconsult already ported; proof pasted by work-order.sh evidence)
  - observed `2026-10-16` diff exit 0, no output (2026-10-16)
- [x] `AC-H2` *(human)* `gh pr list -R jkkelley/ypli-01-src --head chore/merge-on-green --json number -q length` exits 0 and its output matches /^1$/ (proof pasted by work-order.sh evidence)
  - observed `2026-10-16` output 1 (PR jkkelley/ypli-01-src#20)
- [x] `AC-H3` *(human)* `gh pr view chore/merge-on-green -R jkkelley/ypli-01-src --json files -q '[.files[].path]|sort|join(",")'` exits 0 and its output matches /^\.github\/workflows\/ci\.yml,\.github\/workflows\/merge-on-green\.yml$/ (proof pasted by work-order.sh evidence)
  - observed `2026-10-16` .github/workflows/ci.yml,.github/workflows/merge-on-green.yml
- [x] `AC-H4` *(human)* `gh api 'repos/jkkelley/ypli-01-src/contents/.github/workflows/ci.yml?ref=chore/merge-on-green' -q .content | base64 -d | diff - <(bash claude/workflow/pr-flow/bin/pr-flow-ci-render.sh --template ci --set PR_TARGETS='["lint","typecheck","test","validate"]' --set MAIN_TARGETS='["lint-all","typecheck-all","test-all","validate"]' --set SETUP=setup --set CACHE_PATHS='~/.cache/uv')` exits 0 and prints nothing (proof pasted by work-order.sh evidence)
  - observed `2026-10-16` diff exit 0, no output

## Test plan

```sh
no code in dotfiles changes; the four AC commands are the proof, run from the dotfiles worktree root
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
