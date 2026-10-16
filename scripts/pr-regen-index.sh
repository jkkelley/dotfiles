#!/usr/bin/env bash
# rolodex: header reviewed
# name: pr-regen-index.sh
# purpose: merge origin/main into PR branches; if the only conflicts are generated work-order views, regenerate them, commit and push.
# inputs: --repo DIR --branches "a b"; DOTFILES env overrides the dotfiles checkout holding work-order.sh; TMPDIR for worktrees
# outputs: stdout "<branch> <CODE> [detail]" per branch: CLEAN-MERGE REGEN CONFLICT-REAL WT-FAIL PUSH-FAIL; exit 0 ok, 2 usage
# writes-to: a temp worktree per branch (removed after), the branch on origin
# cleanup: removes every worktree it adds
# pr-regen-index.sh - fallback for the index-regen Action (ORD-0553 R7, ORD-0554 U4), ported from regen-merge.sh.
# Breadcrumb: dotfiles #170 #178 #185 had index conflicts cleared by architect break glass,
# log/2026/10/20261016-055223-breakglass-index-regen.md in the artifact store. A real conflict is never auto-resolved.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES=${DOTFILES:-$(cd "$HERE/.." && pwd)}
WO=$DOTFILES/claude/skills/work-order/scripts/work-order.sh
repo="" branches=""
while [ $# -gt 0 ]; do
  case $1 in
    --repo) repo=${2:-}; shift 2 ;;
    --branches) branches=${2:-}; shift 2 ;;
    *) echo 'usage: pr-regen-index.sh --repo DIR --branches "a b"' >&2; exit 2 ;;
  esac
done
if [ -z "$repo" ] || [ -z "$branches" ]; then echo 'usage: pr-regen-index.sh --repo DIR --branches "a b"' >&2; exit 2; fi
R=$repo
git -C "$R" fetch -q origin
for b in $branches; do
  W=$(mktemp -d "${TMPDIR:-/tmp}/regen.XXXX")
  git -C "$R" worktree add -q --detach "$W" "origin/$b" || { echo "$b WT-FAIL"; rm -rf "$W"; continue; }
  git -C "$W" switch -q -C "$b" "origin/$b"
  if git -C "$W" merge -q --no-edit origin/main >/dev/null 2>&1; then st=CLEAN-MERGE
  else
    bad=$(git -C "$W" diff --name-only --diff-filter=U | grep -vE '^work-orders/(INDEX\.md|.*/README\.md)$')
    if [ -n "$bad" ]; then
      git -C "$W" merge --abort; echo "$b CONFLICT-REAL $bad"; git -C "$R" worktree remove --force "$W"; continue
    fi
    # Generated views: if main no longer tracks them, take main's deletion; otherwise take main's copy and reindex.
    # Never re-add a path main has untracked.
    for f in $(git -C "$W" diff --name-only --diff-filter=U); do
      if git -C "$W" cat-file -e "origin/main:$f" 2>/dev/null; then git -C "$W" checkout --theirs -- "$f"; git -C "$W" add -- "$f"
      else git -C "$W" rm -q --cached -- "$f" 2>/dev/null; rm -f "$W/$f"; fi
    done
    if git -C "$W" cat-file -e origin/main:work-orders/INDEX.md 2>/dev/null; then
      bash "$WO" reindex --project "$W" >/dev/null 2>&1; git -C "$W" add -A work-orders
    fi
    git -C "$W" commit -qm "chore: merge main, resolve generated work-order views" && st=REGEN
  fi
  git -C "$W" push -q origin "HEAD:$b" && echo "$b $st PUSHED" || echo "$b PUSH-FAIL"
  git -C "$R" worktree remove --force "$W"
done
