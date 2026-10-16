#!/usr/bin/env bash
# rolodex: header reviewed
# name: wo-untrack-generated.sh
# purpose: untrack the generated work-order views (INDEX.md, per-epic README.md) in a repo; plan before apply.
# inputs: --repo DIR [--apply] [--branch NAME]; DOTFILES env overrides the dotfiles checkout holding work-order.sh
# outputs: stdout UNTRACK/IGNORE plan lines, WO-UNTRACK-NOCHANGE, ROLLBACK line; exit 0 ok, 2 usage, 3 apply failed
# writes-to: plan writes nothing; apply writes DIR's index, .gitignore, a branch, a commit and a PR
# cleanup: none needed
# wo-untrack-generated.sh - migration verb (ORD-0554 U2, ORD-0556 O1): generic, any repo, idempotent.
# Rollback is git revert of the commit it prints. Generated views are written by work-order.sh reindex, never tracked.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES=${DOTFILES:-$(cd "$HERE/.." && pwd)}
repo="" apply=0 branch=chore/wo-untrack-generated
while [ $# -gt 0 ]; do
  case $1 in
    --repo) repo=${2:-}; shift 2 ;;
    --apply) apply=1; shift ;;
    --branch) branch=${2:-}; shift 2 ;;
    *) echo "usage: wo-untrack-generated.sh --repo DIR [--apply] [--branch NAME]" >&2; exit 2 ;;
  esac
done
[ -n "$repo" ] && git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo "usage: --repo must be a git repo" >&2; exit 2; }
IGN=("/work-orders/INDEX.md" "/work-orders/**/README.md")

files=$(git -C "$repo" ls-files -- work-orders/INDEX.md ':(glob)work-orders/**/README.md')
missing=()
for l in "${IGN[@]}"; do grep -qxF -- "$l" "$repo/.gitignore" 2>/dev/null || missing+=("$l"); done

if [ -z "$files" ] && [ ${#missing[@]} -eq 0 ]; then echo "WO-UNTRACK-NOCHANGE"; exit 0; fi
[ -n "$files" ] && while IFS= read -r f; do echo "UNTRACK $f"; done <<<"$files"
for l in "${missing[@]}"; do echo "IGNORE $l"; done
[ "$apply" = 1 ] || exit 0

g() { git -C "$repo" "$@"; }
g switch -q -c "$branch" origin/main 2>/dev/null || g switch -q "$branch" || exit 3
[ -n "$files" ] && while IFS= read -r f; do g rm --cached -q -- "$f" || exit 3; done <<<"$files"
for l in "${missing[@]}"; do printf '%s\n' "$l" >>"$repo/.gitignore"; done
bash "$DOTFILES/claude/skills/work-order/scripts/work-order.sh" reindex --project "$repo" >/dev/null || exit 3
g add .gitignore
g commit -q -m "chore(work-orders): untrack generated views (ORD-0554)" || exit 3
sha=$(g rev-parse HEAD)
g push -q -u origin "$branch" || exit 3
(cd "$repo" && gh pr create --fill) || exit 3
echo "ROLLBACK git -C $repo revert $sha"
