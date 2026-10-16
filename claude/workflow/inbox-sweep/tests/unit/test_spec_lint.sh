#!/usr/bin/env bash
# AC-H1: a 1001-line fixture spec fails and the output names the file and the count.
# AC-H2: a 1000-line fixture passes, with or without a trailing newline.
# AC-H3: every docs/design/*.spec.xml in the repository parses (and is within the cap).
# Rules out: an off-by-one cap (1000 rejected, or 1001 accepted), a failure that does not say which file or how
# long, a malformed spec passing because only length was checked, and a default glob that matches nothing and
# reports success.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
LINT="$R/bin/spec-lint.sh"

# spec <path> <lines>: a well-formed spec of exactly <lines> lines (root open and close, comments between).
spec() {
  { echo '<spec>'; for ((i = 3; i <= $2; i++)); do echo "<!-- $i -->"; done; echo '</spec>'; } >"$1"
}

spec "$T/long.spec.xml" 1001
out="$(bash "$LINT" "$T/long.spec.xml")"; rc=$?
check 1 "$rc" "AC-H1: 1001 lines exits 1"
case $out in *"$T/long.spec.xml"*"1001 lines"*) ok "AC-H1: output names the file and the count" ;; *) bad "AC-H1: output names the file and the count" "got [$out]" ;; esac

spec "$T/edge.spec.xml" 1000
bash "$LINT" "$T/edge.spec.xml" >/dev/null; check 0 "$?" "AC-H2: 1000 lines passes"
printf '%s' "$(cat "$T/edge.spec.xml")" >"$T/nonl.spec.xml"
bash "$LINT" "$T/nonl.spec.xml" >/dev/null; check 0 "$?" "AC-H2: 1000 lines with no trailing newline passes"

printf '<spec><open></spec>\n' >"$T/broken.spec.xml"
out="$(bash "$LINT" "$T/broken.spec.xml")"; rc=$?
check 1 "$rc" "malformed XML exits 1"
case $out in *"broken.spec.xml"*"not well-formed"*) ok "malformed XML names the file" ;; *) bad "malformed XML names the file" "got [$out]" ;; esac

out="$(bash "$LINT" "$T/edge.spec.xml" "$T/long.spec.xml" 2>&1)"; rc=$?
check 1 "$rc" "one bad file among good ones still fails the run"
case $out in *"ok  $T/edge.spec.xml"*) ok "the good file is still reported" ;; *) bad "the good file is still reported" "got [$out]" ;; esac

bash "$LINT" "$T/missing.spec.xml" >/dev/null; check 1 "$?" "a missing file fails"

out="$(bash "$LINT")"; rc=$?
check 0 "$rc" "AC-H3: every docs/design/*.spec.xml parses and is within the cap"
n="$(printf '%s\n' "$out" | grep -c '^ok  ')"
if [ "$n" -ge 2 ]; then ok "AC-H3: default run linted $n specs"; else bad "AC-H3: default run linted $n specs" "wanted at least 2, got [$out]"; fi
finish
