#!/usr/bin/env bash
# name: test_timed_run_fallback.sh
# purpose: dev gate for timed-run.sh --fallback/--fallback-code - the one scripted fallback switch (ORD-0558 O1)
# inputs: bin/timed-run.sh; a stub bus publisher and a stub work-order tool in a mktemp directory
# outputs: ok/FAIL lines and pass= fail=; exit 1 on any failure
# writes-to: a mktemp directory
# cleanup: the mktemp directory is removed on exit
# shellcheck disable=SC2015 # ok/no only echo, so A && B || C cannot misfire
set -uo pipefail
TR="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)/bin/timed-run.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
# shellcheck disable=SC2016 # the stub expands $1 $2 when it runs, not here
printf '#!/usr/bin/env bash\necho "$1 $2" >> "%s/pub.log"\n' "$tmp" > "$tmp/pub"; chmod +x "$tmp/pub"
printf '#!/usr/bin/env bash\necho "{\\"id\\":\\"WO-STUB\\"}"\n' > "$tmp/wo"; chmod +x "$tmp/wo"
export SW_PUB_CMD="$tmp/pub" WO_BIN="$tmp/wo" TM_WO_PROJECT="$tmp/wop" XDG_STATE_HOME="$tmp/state" HOME="$tmp"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
no() { fail=$((fail + 1)); echo "FAIL $1"; }
run() { rc=0; err="$(bash "$TR" --node tp --retries 1 --timeout 1 "$@" 2>&1 >"$tmp/out")" || rc=$?; }
fbevents() { grep -c 'event.node.fallback' "$tmp/pub.log"; }

: > "$tmp/pub.log"; run --fallback 'echo fb' --fallback-code FB-001 -- true
[ "$rc" = 0 ] && [ "$(fbevents)" = 0 ] && ! grep -q FALLBACK <<<"$err" && ok "primary ok: fallback not run" || no "primary ok rc=$rc err=$err"

: > "$tmp/pub.log"; run --fallback 'exit 5' --fallback-code FB-002 -- bash -c 'exit 3'
[ "$rc" = 5 ] && grep -q 'FALLBACK FB-002 tp' <<<"$err" && ok "primary rc 3: fallback runs, rc is the fallback's" || no "primary fail rc=$rc err=$err"
grep 'event.node.fallback' "$tmp/pub.log" | cut -d' ' -f2- | jq -e '.code == "FB-002" and .primary_rc == 3 and .rc == 5' >/dev/null && ok "fallback event carries code, primary_rc, rc" || no "fallback event: $(cat "$tmp/pub.log")"

: > "$tmp/pub.log"; run --fallback 'true' --fallback-code FB-003 -- sleep 5
[ "$rc" = 0 ] && grep -q 'FALLBACK FB-003 tp' <<<"$err" && ok "all attempts timed out: fallback runs" || no "timeout rc=$rc err=$err"

: > "$tmp/pub.log"; FORCE_FALLBACK=1 run --fallback 'true' --fallback-code FB-001 -- false
[ "$rc" = 0 ] && grep -q 'FALLBACK FB-001 tp' <<<"$err" && ok "FORCE_FALLBACK=1 skips the primary" || no "force rc=$rc err=$err"
grep -q 'event.node.start' "$tmp/pub.log" && no "primary started under FORCE_FALLBACK" || ok "no primary start event when forced"

run --fallback 'true' --fallback-code BAD -- true
[ "$rc" = 2 ] && grep -q 'fallback-code' <<<"$err" && ok "bad code exits 2" || no "bad code rc=$rc err=$err"

run -- bash -c 'exit 4'
[ "$rc" = 4 ] && ! grep -q FALLBACK <<<"$err" && ok "no --fallback: unchanged, primary rc kept" || no "unchanged rc=$rc err=$err"

echo "pass=$pass fail=$fail"; [ "$fail" = 0 ]
