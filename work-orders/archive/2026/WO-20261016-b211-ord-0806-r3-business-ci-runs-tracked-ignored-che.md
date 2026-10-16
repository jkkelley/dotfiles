---
{
  "id": "WO-20261016-b211",
  "slug": "ord-0806-r3-business-ci-runs-tracked-ignored-che",
  "title": "ORD-0806 R3: business CI runs tracked-ignored-check - pr-flow.json business ci targets, Makefile target, ci.yml re-rendered",
  "type": "chore",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:08:08+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": "feat/ord-0806-r3-business-ci-runs-tracked-ignored-che",
  "pr": 244,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "biz-design1 cut for ORD-0806 R3; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-5082"
  ],
  "blocks": [
    "WO-20261016-7012"
  ]
}
---

# WO-20261016-b211 - ORD-0806 R3: business CI runs tracked-ignored-check - pr-flow.json business ci targets, Makefile target, ci.yml re-rendered

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

Order ORD-0806 R3 verbatim: "port tracked-ignored-check to business (after business #76, merged) through the same rolodex or lint job; one config entry if the check is generic enough to live in the shared CI template." Source: dotfiles PR 227 (chore/untrack-generated-again, open at cut time 2026-10-16T08:10Z): root Makefile target tracked-ignored-check runs `git ls-files -ci --exclude-standard` and fails when the output is non-empty; .github/workflows/rolodex-check.yml runs `make tracked-ignored-check`. Why: business #76 (chore(work-orders): untrack generated views (ORD-0554), merged) untracked work-orders/INDEX.md and the epic READMEs; a branch cut before #76 re-adds them on merge, exactly what dotfiles #223 did after #222. Inventory, 2026-10-16T08:10Z: (1) business has no Makefile and no rolodex or lint job; its only workflows are ci.yml and merge-on-green.yml. (2) business .github/workflows/ci.yml on main is byte-identical to `bash claude/workflow/pr-flow/bin/pr-flow-ci-render.sh --template ci --set PR_TARGETS='["none"]' --set MAIN_TARGETS='["none"]'` (diff exit 0), so the shared CI template is the port path: the template runs `make <target>` per matrix entry, and the per-repo values live in claude/workflow/pr-flow/config/pr-flow.json repos["jkkelley/business"].ci (pr_targets and main_targets both ["none"] today). (3) The template only calls make inside the repository, so the check itself must be a business Make target: CI runners have no dotfiles checkout. The one config entry is pr_targets and main_targets = ["tracked-ignored-check"]; the rendered ci.yml and a new business Makefile carrying the same recipe as dotfiles PR 227 follow from it. (4) `git ls-files -ci --exclude-standard` on business origin/main prints nothing (0 lines), so the new check is green on landing. (5) The Makefile below was proved by the design seat in localhost/dotfiles-workflow-test:1: clean tree exit 0 `tracked-ignored-check: ok`; a force-added .lavish/x exit 2 listing .lavish/x. (6) WO-20261016-5082 - pr-flow sweep verb rerun-stale-red: once per main sha, refresh open PRs whose red run predates main, post RERUN, make pr-rerun-stale-red is ready and also touches claude/workflow/pr-flow/config/pr-flow.json, so this ticket depends on it (owner item 19: never touching same files). PR 227 is not a dependency: the recipe is copied verbatim, not called.

## Scope

**In**

- touches: jkkelley/dotfiles: claude/workflow/pr-flow/config/pr-flow.json (repos["jkkelley/business"].ci.pr_targets and .main_targets only)
- touches: jkkelley/business: Makefile (new, exact bytes below, sha256 f23c20f15fd8733f844306c376b5ae8c27ad9e8905ac2748cc1071f25baaed5c)
- touches: jkkelley/business: .github/workflows/ci.yml (re-rendered, never hand-edited)
- touches (generated, written only by work-order.sh start/submit/done in dotfiles, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-0272/WO-20261016-fb0c/README.md
- step: in the dotfiles worktree opened by `work-order.sh start`: `jq --indent 2 '.repos["jkkelley/business"].ci.pr_targets = ["tracked-ignored-check"] | .repos["jkkelley/business"].ci.main_targets = ["tracked-ignored-check"]' claude/workflow/pr-flow/config/pr-flow.json > claude/workflow/pr-flow/config/pr-flow.json.tmp && mv claude/workflow/pr-flow/config/pr-flow.json.tmp claude/workflow/pr-flow/config/pr-flow.json` (idempotent: a rerun writes the same bytes; the file is already jq --indent 2 formatted, so the diff is exactly 2 lines)
- step: `test -d /home/luna/.cache/wt-business-tracked-ignored || gh repo clone jkkelley/business /home/luna/.cache/wt-business-tracked-ignored`; then `git -C /home/luna/.cache/wt-business-tracked-ignored fetch origin` and `git -C /home/luna/.cache/wt-business-tracked-ignored checkout -B chore/tracked-ignored-check origin/main` (idempotent from any state)
- step: `cd /home/luna/.cache/wt-business-tracked-ignored && printf '# Makefile - the targets the rendered .github/workflows/ci.yml runs (dotfiles claude/workflow/pr-flow/templates/ci.yml).\n# Breadcrumb: ORD-0806 R3 ported tracked-ignored-check from the dotfiles root Makefile (dotfiles PR 227).\n# business #76 untracked work-orders/INDEX.md and the epic READMEs; a branch cut before #76 re-adds them on merge.\n# The guard is generic: any tracked path that .gitignore excludes fails, whichever generator wrote it.\n.PHONY: tracked-ignored-check\ntracked-ignored-check: ## fail when git tracks a path .gitignore excludes\n\t@bad="$$(git ls-files -ci --exclude-standard)"; if [ -n "$$bad" ]; then echo "tracked-ignored-check: tracked but ignored:"; echo "$$bad"; exit 1; fi; echo "tracked-ignored-check: ok"\n' > Makefile`
- step: from the dotfiles worktree root: `bash claude/workflow/pr-flow/bin/pr-flow-ci-render.sh --template ci --set PR_TARGETS='["tracked-ignored-check"]' --set MAIN_TARGETS='["tracked-ignored-check"]' --out /home/luna/.cache/wt-business-tracked-ignored/.github/workflows/ci.yml`
- step: `git -C /home/luna/.cache/wt-business-tracked-ignored add Makefile .github/workflows/ci.yml`, `git -C /home/luna/.cache/wt-business-tracked-ignored commit -m 'ci: tracked-ignored-check in the smart CI matrix (ORD-0806 R3, rendered by dotfiles pr-flow-ci-render.sh)'`, `git -C /home/luna/.cache/wt-business-tracked-ignored push -u origin chore/tracked-ignored-check --force-with-lease`
- step: `gh pr list -R jkkelley/business --head chore/tracked-ignored-check --json number -q length`; when 0, `gh pr create -R jkkelley/business --head chore/tracked-ignored-check --title 'ci: tracked-ignored-check in the smart CI matrix' --body 'ORD-0806 R3. Port of dotfiles tracked-ignored-check (dotfiles PR 227): fails when git tracks a path .gitignore excludes, so a branch cut before #76 cannot re-add the generated work-orders views. ci.yml rendered by dotfiles claude/workflow/pr-flow/bin/pr-flow-ci-render.sh with PR_TARGETS and MAIN_TARGETS ["tracked-ignored-check"].'`
- step: dotfiles side: commit claude/workflow/pr-flow/config/pr-flow.json on the ticket branch with `work-order.sh submit` and `done` per the close-out procedure; the dotfiles PR carries only claude/workflow/pr-flow/config/pr-flow.json and the generated work-orders files
- step: `rm -rf /home/luna/.cache/wt-business-tracked-ignored` after the business PR exists (item 11)
- tool: path:claude/workflow/pr-flow/bin/pr-flow-ci-render.sh - on main; fallback: missing or exit 2: stop with DESIGN-GAP naming it; never hand-edit a rendered copy
- tool: path:claude/workflow/pr-flow/templates/ci.yml - on main; fallback: missing: stop with DESIGN-GAP naming the file
- tool: cmd:jq - on the host and required by the renderer; fallback: missing: stop with ENV-MISSING naming it
- tool: cmd:gh - fallback: gh or GitHub down: retry 3 times, then stop with A2A-003 and the gh error in the result blockers
- tool: cmd:git - fallback: push refused: retry 3 times, then stop with A2A-003 and the git error in the result blockers
- tool: cmd:make in GitHub Actions ubuntu-24.04 - preinstalled on the runner; fallback: none needed at build, the test ticket proves the target in podman
- tool: merge path - business has merge-on-green.yml installed (pr-flow.json installed ["ci","merge-on-green"]); fallback: the orchestrator merge script merges on green, no change here

**Out - non-goals**

- the shared template ci.yml or the renderer: repo values pass as --set and as the pr-flow.json entry
- dotfiles Makefile or rolodex-check.yml: dotfiles PR 227 owns them
- a dotfiles make include or script for the check: the CI runner has no dotfiles checkout, and the recipe is one line
- business .gitignore or any tracked file cleanup: origin/main has 0 tracked-ignored paths
- work-orders/INDEX.md, the ticket file or the parent README by hand: work-order.sh writes them
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* `jq -c '.repos["jkkelley/business"].ci | [.pr_targets, .main_targets]' claude/workflow/pr-flow/config/pr-flow.json` exits 0 and its output matches /^\[\["tracked-ignored-check"\],\["tracked-ignored-check"\]\]$/
  - observed `2026-10-16` [["tracked-ignored-check"],["tracked-ignored-check"]] exit 0
- [x] `AC-H2` *(human)* `jq --indent 2 . claude/workflow/pr-flow/config/pr-flow.json | diff - claude/workflow/pr-flow/config/pr-flow.json` exits 0 and prints nothing (format preserved)
  - observed `2026-10-16` diff empty, exit 0
- [x] `AC-H3` *(human)* `gh pr list -R jkkelley/business --head chore/tracked-ignored-check --json number -q length` exits 0 and its output matches /^1$/
  - observed `2026-10-16` output 1 (business PR 77)
- [x] `AC-H4` *(human)* `gh pr view chore/tracked-ignored-check -R jkkelley/business --json files -q '[.files[].path]|sort|join(",")'` exits 0 and its output matches /^\.github\/workflows\/ci\.yml,Makefile$/
  - observed `2026-10-16` .github/workflows/ci.yml,Makefile
- [x] `AC-H5` *(human)* `gh api 'repos/jkkelley/business/contents/Makefile?ref=chore/tracked-ignored-check' -q .content | base64 -d | sha256sum` exits 0 and its output matches /^f23c20f15fd8733f844306c376b5ae8c27ad9e8905ac2748cc1071f25baaed5c /
  - observed `2026-10-16` sha256 f23c20f1...aed5c matches
- [x] `AC-H6` *(human)* `gh api 'repos/jkkelley/business/contents/.github/workflows/ci.yml?ref=chore/tracked-ignored-check' -q .content | base64 -d | diff - <(bash claude/workflow/pr-flow/bin/pr-flow-ci-render.sh --template ci --set PR_TARGETS='["tracked-ignored-check"]' --set MAIN_TARGETS='["tracked-ignored-check"]')` exits 0 and prints nothing
  - observed `2026-10-16` rendered diff empty, exit 0

## Test plan

```sh
no code in dotfiles changes; the six AC commands are the build proof, run from the dotfiles worktree root; the target's behaviour is proved by the --type test sibling in podman
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
