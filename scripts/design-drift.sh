#!/usr/bin/env bash
# rolodex: header reviewed
# name: design-drift.sh
# purpose: fail when a design.md changed after the version its wireframes/README.md says the frames reflect.
# inputs: check|stamp, then README... arguments; default: every tracked */wireframes/README.md
# outputs: stdout ok/skip/FAIL/stamped lines; exit 0 ok, 3 drift or no record, 2 usage
# writes-to: check writes nothing; stamp rewrites the Design-Reflects line of the README it is given
# cleanup: none needed
# design-drift.sh - wireframes never silently lag the design they draw.
# Usage: design-drift.sh [check] [README...]   fail on drift (default: every tracked */wireframes/README.md)
#        design-drift.sh stamp README...       record the current design.md in each README (idempotent)
# The pair: <dir>/wireframes/README.md reflects <dir>/design.md. A README with no sibling design.md is skipped.
# The record: one line in the README, "Design-Reflects: <git blob id of design.md>".
# Exit: 0 every pair in step (or nothing in scope), 3 any drift or missing record, 2 bad usage.
#
# Why a blob id and not the design.md commit (brief BR-20261016-design-drift asked for "the design.md commit"):
# every repo here merges with `gh pr merge --squash`, which replaces the branch commits with one new commit, so a
# commit id stamped on a branch no longer exists on main and the check would fail forever after the merge. The
# blob id is the hash of design.md's content, so it survives squash, rebase and shallow clones, and CI needs no
# history (fetch-depth 1 is enough, CI speed is king). It answers the same question: has design.md changed since
# the frames were drawn. Cost: the README names a content hash, not a commit; `git log --find-object=<id>` maps
# it back to the commits that held that content.
set -uo pipefail

cmd=check
case ${1:-} in
  check|stamp) cmd=$1; shift ;;
  -h|--help) sed -n '9,14p' "$0"; exit 0 ;;
  -*) echo "design-drift: unknown option $1" >&2; exit 2 ;;
esac

if [ "$#" -gt 0 ]; then
  files=("$@")
elif [ "$cmd" = stamp ]; then
  echo "design-drift: stamp needs README paths (it never stamps everything at once)" >&2; exit 2
else
  root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "design-drift: not in a git repo and no README given" >&2; exit 2; }
  cd "$root" || exit 2
  mapfile -t files < <(git ls-files -- 'wireframes/README.md' '*/wireframes/README.md')
fi
[ "${#files[@]}" -gt 0 ] || { echo "design-drift: nothing in scope"; exit 0; }

failed=0
for r in "${files[@]}"; do
  if [ ! -f "$r" ]; then printf 'FAIL %s: no such file\n' "$r"; failed=1; continue; fi
  design=$(dirname "$(dirname "$r")")/design.md
  if [ ! -f "$design" ]; then printf 'skip %s: no %s\n' "$r" "$design"; continue; fi
  want=$(git hash-object -- "$design") || { printf 'FAIL %s: cannot hash %s\n' "$r" "$design"; failed=1; continue; }
  have=$(sed -n 's/^Design-Reflects: \([0-9a-f]\{40,64\}\)[[:space:]]*$/\1/p' "$r" | head -1)
  if [ "$cmd" = stamp ]; then
    [ "$have" = "$want" ] && { printf 'ok   %s (already %s)\n' "$r" "${want:0:12}"; continue; }
    tmp=$(mktemp) || exit 2
    if grep -q '^Design-Reflects:' "$r"; then
      sed "s/^Design-Reflects:.*/Design-Reflects: $want/" "$r" >"$tmp"
    else
      # After the title line, so the record is the first thing a reader of the README meets.
      awk -v l="Design-Reflects: $want" 'NR==1{print; print ""; print l; next} {print}' "$r" >"$tmp"
    fi
    cat "$tmp" >"$r"; rm -f "$tmp"
    printf 'stamped %s: %s\n' "$r" "${want:0:12}"
  elif [ -z "$have" ]; then
    printf 'FAIL %s: no Design-Reflects line; run make design-drift-stamp FILES=%s\n' "$r" "$r"; failed=1
  elif [ "$have" != "$want" ]; then
    printf 'FAIL %s: %s changed since %s (now %s); redraw the frames, then make design-drift-stamp FILES=%s\n' \
      "$r" "$design" "${have:0:12}" "${want:0:12}" "$r"; failed=1
  else
    printf 'ok   %s (%s)\n' "$r" "${want:0:12}"
  fi
done
[ "$failed" = 0 ] || exit 3
