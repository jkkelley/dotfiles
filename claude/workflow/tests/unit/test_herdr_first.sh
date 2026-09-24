#!/usr/bin/env bash
# Enforces dotfiles CLAUDE.md Rule 18 in code: nothing in this machinery backgrounds a process.
#
# Why a test and not a review note: the kimi-proxy watcher this repository ported shipped `( ... ) & disown`, and
# bearings-v2's ceremony watcher shipped `( ... ) &`. Both were written by careful authors who knew the rule. A rule a
# reviewer has to remember is a rule that holds until the first busy day; a red gate holds every day.
#
# What counts: a code line (comments stripped) that ends in a lone `&`, or uses `& disown`, `disown`, `nohup` or
# `setsid`. `&&` and `>&` are not backgrounding and are not flagged.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0
for f in "$R"/bin/*.sh "$R"/tools/*.sh "$R"/report/rail.sh; do
  [ -f "$f" ] || continue
  hits="$(sed -e 's/[[:space:]]#.*$//' -e '/^[[:space:]]*#/d' "$f" \
    | grep -nE '(^|[^&>])&[[:space:]]*$|&[[:space:]]*disown|(^|[[:space:];|])(disown|nohup|setsid)([[:space:]]|$)' || true)"
  if [ -n "$hits" ]; then
    printf 'FAIL: %s backgrounds a process (Rule 18):\n%s\n' "${f#"$R"/}" "$(printf '%s\n' "$hits" | sed 's/^/    /')"; fail=1
  fi
done
# The negative case: prove the pattern catches what it exists to catch, so a green run means something.
probe="$(printf '%s\n' '( sleep 1 ) >/dev/null 2>&1 &' 'x && y' 'cmd 2>&1' 'nohup foo' '( loop ) & disown' \
  | grep -cE '(^|[^&>])&[[:space:]]*$|&[[:space:]]*disown|(^|[[:space:];|])(disown|nohup|setsid)([[:space:]]|$)')"
[ "$probe" = 3 ] || { echo "FAIL: the background pattern matched $probe of 3 planted cases"; fail=1; }
[ "$fail" = 0 ] && echo "ok  herdr-first: no process in bin/, tools/ or report/ is backgrounded"
exit "$fail"
