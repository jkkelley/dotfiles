# shellcheck shell=bash
# Tiny assertion helpers shared by this directory's suites; same ok/FAIL vocabulary as claude/workflow/tests/unit.
fail=0
ok()  { printf 'ok  %s\n' "$1"; }
bad() { fail=1; printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; return 0; }
check() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3" "wanted [$1] got [$2]"; fi; }
finish() { exit "$fail"; }
