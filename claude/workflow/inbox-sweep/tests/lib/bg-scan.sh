# shellcheck shell=bash
# Rule 18 scanner, sourced by the herdr-first suite. bg_scan <file...> prints one line per backgrounding construct and
# returns 1 if it printed any.
#
# Same pattern as claude/workflow/tests/unit/test_herdr_first.sh, kept as its own copy because that one is wired to the
# machinery's own directories. What counts: a code line (comments stripped) ending in a lone `&`, or `& disown`,
# `disown`, `nohup`, `setsid`. `&&` and `>&` are not backgrounding.
BG_PATTERN='(^|[^&>])&[[:space:]]*$|&[[:space:]]*disown|(^|[[:space:];|])(disown|nohup|setsid)([[:space:]]|$)'
bg_scan() {
  local f hits rc=0
  for f in "$@"; do
    hits="$(sed -e 's/[[:space:]]#.*$//' -e '/^[[:space:]]*#/d' "$f" | grep -nE "$BG_PATTERN" || true)"
    if [ -n "$hits" ]; then
      printf 'FAIL: %s backgrounds a process (Rule 18):\n%s\n' "$f" "$(printf '%s\n' "$hits" | sed 's/^/    /')"
      rc=1
    fi
  done
  return "$rc"
}
