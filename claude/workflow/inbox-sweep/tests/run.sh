#!/usr/bin/env bash
# Runs the inbox sweep's test suites. Meant to run inside the pinned workflow test image (Rule 14); `make test`,
# `make test-all` and `make herdr-first` start the container and call this.
#
#   run.sh --changed   suites whose `covers` match a changed path; the paths come from $SWEEP_CHANGED (one per line,
#                      repo-root relative), or stdin if that is unset. The container has no git, so the Makefile
#                      computes the list on the host and passes it in.
#   run.sh --all       every suite in tests/suites.tsv
#   run.sh --suite N   suite N only
#
# tests/suites.tsv is `name<TAB>covers<TAB>command`. `covers` is comma-separated and relative to claude/workflow/inbox-sweep/:
# an entry ending in `/` matches everything under it, any other entry matches that exact file. $SWEEP_SUITES points
# at another table (the select suite uses a fixture). The command runs through bash -c from the sweep directory.
#
# Output: one `ok  <suite>` or `FAIL <suite>` line per suite, then `ran N suites` (plus `, M failed` and exit 1).
# `--changed` with nothing selected prints `ran 0 suites` and exits 0: that is a result, not a skip.
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TABLE="${SWEEP_SUITES:-$R/tests/suites.tsv}"
PREFIX="claude/workflow/inbox-sweep/"
usage() { echo "usage: run.sh --changed | --all | --suite <name>" >&2; exit 2; }
[ $# -ge 1 ] || usage
mode="$1"
declare -a selected=()

all_names() { cut -f1 "$TABLE"; }
suite_row() { awk -F'\t' -v n="$1" '$1==n' "$TABLE"; }

case "$mode" in
  --all) mapfile -t selected < <(all_names) ;;
  --suite)
    [ $# -eq 2 ] || usage
    [ -n "$(suite_row "$2")" ] || { echo "run.sh: no suite named '$2'" >&2; exit 2; }
    selected=("$2")
    ;;
  --changed)
    if [ -n "${SWEEP_CHANGED+x}" ]; then changed="$SWEEP_CHANGED"; else changed="$(cat)"; fi
    while IFS=$'\t' read -r name covers _cmd; do
      hit=0
      while IFS= read -r path; do
        [[ $path == "$PREFIX"* ]] || continue
        rel="${path#"$PREFIX"}"
        IFS=',' read -r -a entries <<<"$covers"
        for e in "${entries[@]}"; do
          case $e in
            */) [[ $rel == "$e"* ]] && hit=1 ;;
            *) [ "$rel" = "$e" ] && hit=1 ;;
          esac
        done
      done <<<"$changed"
      [ "$hit" = 1 ] && selected+=("$name")
    done <"$TABLE"
    ;;
  *) usage ;;
esac

cd "$R"
ran=0 failed=0
for name in "${selected[@]}"; do
  cmd="$(suite_row "$name" | cut -f3)"
  ran=$((ran + 1))
  if out="$(bash -c "$cmd" 2>&1)"; then
    printf 'ok  %s\n' "$name"
  else
    failed=$((failed + 1))
    printf 'FAIL %s\n%s\n' "$name" "$(printf '%s\n' "$out" | sed 's/^/     /')"
  fi
done
if [ "$ran" = 1 ]; then s=suite; else s=suites; fi
if [ "$failed" -gt 0 ]; then
  printf 'ran %s %s, %s failed\n' "$ran" "$s" "$failed"
  exit 1
fi
printf 'ran %s %s\n' "$ran" "$s"
