#!/usr/bin/env bash
# name: test_step_time.sh
# purpose: dev gate for bin/step-time.sh - timing records, SLOW over budget, timeout, retries, bus failure tolerated
# inputs: bin/step-time.sh; a stub publisher in a mktemp directory
# outputs: ok/FAIL lines and pass= fail=; exit 1 on any failure
# writes-to: a mktemp directory
# cleanup: the mktemp directory is removed on exit
# shellcheck disable=SC2015 # ok/no only echo, so A && B || C cannot misfire
set -uo pipefail
ST="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)/bin/step-time.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
# shellcheck disable=SC2016 # the stub expands $1 $2 when it runs, not here
printf '#!/usr/bin/env bash\necho "$1 $2" >> "%s/pub.log"\n' "$tmp" > "$tmp/pub"; chmod +x "$tmp/pub"
printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/badpub"; chmod +x "$tmp/badpub"
export STEP_TIME_PUB="$tmp/pub" STEP_TIME_BACKOFF=0
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
no() { fail=$((fail + 1)); echo "FAIL $1"; }
recs() { grep "^$1 " "$tmp/pub.log" | cut -d' ' -f2-; }

: > "$tmp/pub.log"; out="$("$ST" --line test --node N4 -- echo hi 2>/dev/null)"
[ "$out" = hi ] && ok "command output passes through" || no "output: $out"
[ "$(recs line.test.time.N4 | jq -r .kind | tr '\n' ' ')" = "step.start step.end " ] && ok "start then end on line.test.time.N4" || no "records: $(cat "$tmp/pub.log")"
recs line.test.time.N4 | tail -1 | jq -e '.code == "200" and .rc == 0 and (.dur_s|type) == "number" and (.at|test("Z$"))' >/dev/null && ok "end record: code 200, rc, dur_s, UTC at" || no "end record fields"
grep -q step.slow "$tmp/pub.log" && no "SLOW posted under budget" || ok "no SLOW under budget"

: > "$tmp/pub.log"; "$ST" --line test --node N2 --budget 0 -- sleep 1 2>/dev/null
recs line.test.event.step.slow | jq -e '.code == "SLOW" and .dur_s >= 1' >/dev/null && ok "over budget posts SLOW" || no "no SLOW over budget"

: > "$tmp/pub.log"; rc=0; "$ST" --line test --node N6 --timeout 1 --retries 2 -- sleep 5 2>/dev/null || rc=$?
[ "$rc" = 124 ] && ok "timeout returns 124 after retries" || no "timeout rc=$rc"
[ "$(recs line.test.time.N6 | jq -r 'select(.kind=="step.end") | .code' | tr '\n' ' ')" = "124 124 " ] && ok "each attempt posts its own end, code 124" || no "timeout records"

: > "$tmp/pub.log"; rc=0; "$ST" --line test --node N3 -- false 2>/dev/null || rc=$?
[ "$rc" = 1 ] && [ "$(recs line.test.time.N3 | grep -c step.end)" = 3 ] && ok "failure retried 3 times then exits with its code" || no "retry rc=$rc"

: > "$tmp/pub.log"; f="$tmp/flaky"; rc=0
"$ST" --line test --node N1 -- bash -c "[ -f $f ] || { touch $f; exit 7; }" 2>/dev/null || rc=$?
[ "$rc" = 0 ] && [ "$(recs line.test.time.N1 | jq -r 'select(.kind=="step.end") | .code' | tr '\n' ' ')" = "7 200 " ] && ok "a flaky step succeeds on retry" || no "flaky rc=$rc"

rc=0; err="$(STEP_TIME_PUB="$tmp/badpub" "$ST" --line test --node N4 -- true 2>&1)" || rc=$?
[ "$rc" = 0 ] && grep -q 'publish to line.test.time.N4 failed' <<<"$err" && ok "bus down: step still succeeds, error on stderr" || no "bus down rc=$rc"

rc=0; "$ST" --node N4 -- true 2>/dev/null || rc=$?; [ "$rc" = 2 ] && ok "missing --line exits 2" || no "missing line rc=$rc"
rc=0; "$ST" --line 'a.b' --node N4 -- true 2>/dev/null || rc=$?; [ "$rc" = 2 ] && ok "a dot in line exits 2 (subject injection)" || no "dot rc=$rc"
rc=0; "$ST" --line t --node N4 2>/dev/null || rc=$?; [ "$rc" = 2 ] && ok "no command exits 2" || no "no cmd rc=$rc"

# WO-20261016-a702: default publisher must run a non-executable bus.sh through bash
mkdir "$tmp/nx"; cp "$ST" "$tmp/nx/step-time.sh"
printf '#!/usr/bin/env bash\necho "$*" >> "%s/nx.log"\n' "$tmp" > "$tmp/nx/bus.sh"; chmod 0644 "$tmp/nx/bus.sh"
rc=0; err="$(env -u STEP_TIME_PUB bash "$tmp/nx/step-time.sh" --line t --node n --retries 1 -- true 2>&1)" || rc=$?
[ "$rc" = 0 ] && grep -q '^pub line.t.time.n' "$tmp/nx.log" && ! grep -q 'publish to' <<<"$err" && ok "non-executable bus.sh is published through bash" || no "noexec bus rc=$rc err=$err"

echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
