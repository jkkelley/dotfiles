#!/usr/bin/env bash
# AC-H4: the herdr-first scan is red on a planted ampersand and green on the real bin/ (Rule 18).
# Rules out: a scan that passes because its pattern matches nothing, a scan that flags `&&` or `2>&1`, and a real script
# backgrounding a process without a red gate. $SWEEP_BIN_DIR points the scan elsewhere (`make herdr-first SWEEP_BIN_DIR=`).
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
# shellcheck source=../lib/bg-scan.sh
. "$R/tests/lib/bg-scan.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# Self-test first: each construct, planted alone, must be caught.
plant() { printf '%s\n' "$1" >"$T/fixture.sh"; bg_scan "$T/fixture.sh" >/dev/null; }
plant '( sleep 1 ) >/dev/null 2>&1 &';   check 1 "$?" "planted trailing ampersand is red"
plant '( loop ) & disown';               check 1 "$?" "planted & disown is red"
plant 'nohup foo';                       check 1 "$?" "planted nohup is red"
plant 'setsid foo';                      check 1 "$?" "planted setsid is red"
plant 'foo && bar 2>&1 | cat >&2';       check 0 "$?" "&& and >& are not flagged"
plant '# nohup is only a comment'
check 0 "$?" "a comment mentioning nohup is not flagged"
mkdir -p "$T/planted"; printf '#!/usr/bin/env bash\nsleep 5 &\n' >"$T/planted/sweep-bad.sh"
bg_scan "$T/planted/"*.sh >/dev/null; check 1 "$?" "a planted script file is red"

# The real thing: every script in the sweep's bin/ (or $SWEEP_BIN_DIR).
dir="${SWEEP_BIN_DIR:-$R/bin}"
shopt -s nullglob
files=("$dir"/*.sh)
if [ "${#files[@]}" -gt 0 ] && bg_scan "${files[@]}"; then
  ok "herdr-first: none of ${#files[@]} script(s) in ${dir#"$R"/} backgrounds a process"
else
  bad "herdr-first: ${dir#"$R"/} backgrounds a process or has no scripts"
fi
finish
