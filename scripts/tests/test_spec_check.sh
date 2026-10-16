#!/usr/bin/env bash
# Test plan WO-20261016-bdcb (TP-1 to TP-6) for scripts/spec-check.sh. Run in podman: make spec-check-test.
# Rules out: an off-by-one cap, a malformed spec passing because only length was checked, a spec without a
# <contents> first child passing, a check that writes files, and bad usage mistaken for a violation.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SC=$HERE/../spec-check.sh
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fails=0
check() { if [ "$1" = "$2" ]; then echo "ok - $3"; else echo "not ok - $3 (want $1, got $2)"; fails=$((fails + 1)); fi; }

# spec <path> <lines>: well-formed, <contents> first, exactly <lines> lines.
spec() { { echo '<spec>'; echo '<contents/>'; for ((i = 4; i <= $2; i++)); do echo "<!-- $i -->"; done; echo '</spec>'; } >"$1"; }

spec "$T/good.spec.xml" 20
bash "$SC" "$T/good.spec.xml" >/dev/null; check 0 $? "good spec exits 0"
spec "$T/edge.spec.xml" 1000
bash "$SC" "$T/edge.spec.xml" >/dev/null; check 0 $? "1000 lines exits 0"
spec "$T/long.spec.xml" 1001
out=$(bash "$SC" "$T/long.spec.xml"); check 3 $? "1001 lines exits 3"
case $out in *"1001 lines, limit 1000"*) echo "ok - 1001 lines names the count" ;; *) echo "not ok - count [$out]"; fails=$((fails + 1)) ;; esac
printf '<spec><contents/><open></spec>\n' >"$T/bad.spec.xml"
bash "$SC" "$T/bad.spec.xml" >/dev/null; check 3 $? "malformed exits 3"
printf '<spec><meta/><contents/></spec>\n' >"$T/noc.spec.xml"
out=$(bash "$SC" "$T/noc.spec.xml"); check 3 $? "no contents element exits 3"
case $out in *"<meta>, want <contents>"*) echo "ok - no contents element names the tag" ;; *) echo "not ok - tag [$out]"; fails=$((fails + 1)) ;; esac
printf '<spec/>\n' >"$T/empty.spec.xml"
bash "$SC" "$T/empty.spec.xml" >/dev/null; check 3 $? "root with no children exits 3"
bash "$SC" "$T/good.spec.xml" "$T/long.spec.xml" >/dev/null; check 3 $? "one bad file among good ones exits 3"

before=$(find "$T" -type f -exec md5sum {} + | sort)
a=$(bash "$SC" "$T"/*.spec.xml); ra=$?; b=$(bash "$SC" "$T"/*.spec.xml); rb=$?
after=$(find "$T" -type f -exec md5sum {} + | sort)
if [ "$a$ra" = "$b$rb" ] && [ "$before" = "$after" ]; then echo "ok - two runs same output, nothing written"
else echo "not ok - two runs same output, nothing written"; fails=$((fails + 1)); fi

bash "$SC" --bogus >/dev/null 2>&1; check 2 $? "bad usage exits 2"
LIMIT=abc bash "$SC" "$T/good.spec.xml" >/dev/null 2>&1; check 2 $? "bad LIMIT exits 2"
[ "$fails" = 0 ]
