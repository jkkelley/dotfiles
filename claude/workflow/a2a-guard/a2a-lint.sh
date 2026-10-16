#!/usr/bin/env bash
# name: a2a-lint.sh
# purpose: fail any script that types into a herdr pane directly instead of through a2a-send.
# outputs: stdout A2A-RAW-SEND lines or A2A-LINT-OK, exit code
# cleanup: none
# a2a-lint.sh - fail any script that types into a herdr pane directly instead of going through a2a-send.
#
# usage: a2a-lint.sh [--root DIR] [FILE...]
#   no FILE: scans config lint.paths under ROOT. Prints "A2A-RAW-SEND <file>:<line>: <text>" per hit.
# exit: 0 clean, 1 a raw send found, 2 usage.
# inputs: config.json beside this file (A2A_CONFIG): lint.pattern (ERE), lint.paths, lint.allow (path prefixes).
# writes-to: stdout only. cleanup: none.
#
# BREADCRUMB - P1 of brief BR-20261016-a2a-guard: a raw `herdr pane send-text` has no notion of whether the agent in that
#   pane is working, which is how orders sat queued 18-25 min. Grep is the whole check on purpose: fast enough for every
#   PR (item 1) and a new caller cannot slip past it. Rejected: a shellcheck plugin, more machinery for one regex.
# Cost: a doc or comment line naming the command trips it outside the allow list; the allow list is config.
set -uo pipefail
# shellcheck source=claude/workflow/a2a-guard/a2a-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/a2a-lib.sh"
root=. files=()
while [ $# -gt 0 ]; do
  case $1 in --root) root=${2:-}; shift 2 ;; -h|--help) sed -n 2,8p "$0"; exit 0 ;; *) files+=("$1"); shift ;; esac
done
pat=$(a2a_cfg .lint.pattern)
cd "$root" || a2a_die 2 "A2A-USAGE no such root $root"
if [ ${#files[@]} -eq 0 ]; then
  mapfile -t paths < <(a2a_cfg '.lint.paths[]')
  mapfile -t files < <(find "${paths[@]}" -type f \( -name '*.sh' -o -name '*.bash' -o -name '*.mk' -o -name 'Makefile' \
                         -o -name '*.py' -o -name '*.mjs' -o -name '*.js' \) 2>/dev/null | sort)
fi
mapfile -t allow < <(a2a_cfg '.lint.allow[]')
bad=0
for f in "${files[@]}"; do
  f=${f#./}; skip=0
  for a in "${allow[@]}"; do case $f in "$a"*) skip=1 ;; esac; done
  [ $skip = 1 ] || [ ! -f "$f" ] && continue
  while IFS= read -r hit; do printf 'A2A-RAW-SEND %s:%s\n' "$f" "$hit"; bad=1; done < <(grep -nE "$pat" "$f")
done
[ $bad = 0 ] && printf 'A2A-LINT-OK %s files, no raw herdr pane send-text outside a2a-guard\n' "${#files[@]}"
exit $bad
