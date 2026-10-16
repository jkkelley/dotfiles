#!/usr/bin/env bash
# name: test_quota_probe.sh
# purpose: dev gate for quota-probe.sh - codes, transitions on the bus, bus-down fallback, config errors
# inputs: quota-probe.sh; a temp config and a stub publisher in a mktemp directory
# outputs: ok/FAIL lines and pass= fail=; exit 1 on any failure
# writes-to: a mktemp directory
# cleanup: the mktemp directory is removed on exit
# shellcheck disable=SC2015,SC2016 # ok/no only echo; the stub expands its args when it runs
set -uo pipefail
QP="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)/quota-probe.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
jq -n '{state_dir:"x",subject_prefix:"p",probes:{
  ok:{command:"echo X-OK",ok_regex:"X-OK",out_regex:"X-LIMIT",timeout_s:5,resumes:["r1"]},
  out:{command:"echo X-LIMIT; exit 1",ok_regex:"X-OK",out_regex:"X-LIMIT",timeout_s:5,resumes:[]},
  err:{command:"exit 3",ok_regex:"X-OK",out_regex:"X-LIMIT",timeout_s:5,resumes:[]},
  slow:{command:"sleep 5",ok_regex:"X-OK",out_regex:"X-LIMIT",timeout_s:1,resumes:[]}}}' > "$tmp/c.json"
printf '#!/usr/bin/env bash\necho "$@" >> "%s/pub.log"\n' "$tmp" > "$tmp/pub"; chmod +x "$tmp/pub"
printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/badpub"; chmod +x "$tmp/badpub"
export QP_BUS="$tmp/pub"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
no() { fail=$((fail + 1)); echo "FAIL $1"; }
run() { # run NAME [STATE]
  export QP_STATE_DIR="$tmp/${2:-s}"; rc=0; err="$(bash "$QP" --name "$1" --config "$tmp/c.json" 2>&1 >"$tmp/out")" || rc=$?; }
scode() { jq -r '.code' "$tmp/${1:-s}/$2.json"; }

run ok s1; [ "$rc" = 0 ] && [ "$(scode s1 ok)" = QUOTA-OK ] && ok "t1 ok -> 0 QUOTA-OK" || no "t1 rc=$rc"
run out s2; [ "$rc" = 5 ] && [ "$(scode s2 out)" = QUOTA-OUT ] && ok "t2 out -> 5" || no "t2 rc=$rc"
run err s3; [ "$rc" = 4 ] && ok "t3 err -> 4" || no "t3 rc=$rc"
s=$SECONDS; run slow s4; [ "$rc" = 4 ] && [ $((SECONDS - s)) -le 3 ] && ok "t4 slow -> 4 within 3 s" || no "t4 rc=$rc"
: > "$tmp/pub.log"; run ok s5; run ok s5
[ "$(wc -l < "$tmp/pub.log")" = 1 ] && ok "t5 same result twice -> one publish" || no "t5 $(cat "$tmp/pub.log")"
: > "$tmp/pub.log"; mkdir -p "$tmp/s6"; echo '{"name":"ok","code":"QUOTA-OUT","prev":null,"at":"x"}' > "$tmp/s6/ok.json"; run ok s6
[ "$(wc -l < "$tmp/pub.log")" = 1 ] && grep -q '"prev":"QUOTA-OUT"' "$tmp/pub.log" && ok "t6 ok after out -> publish with prev QUOTA-OUT" || no "t6 $(cat "$tmp/pub.log")"
QP_BUS="$tmp/badpub" run ok s7
[ "$(wc -l < "$tmp/s7/events.jsonl")" = 1 ] && grep -q 'FALLBACK QPROBE-BUS ok' <<<"$err" && [ "$rc" = 0 ] && ok "t7 bus down -> events.jsonl + FALLBACK" || no "t7 rc=$rc err=$err"
run nope s8; [ "$rc" = 2 ] && grep -q QUOTA-CFG "$tmp/out" && ok "t8 unknown name -> 2" || no "t8 rc=$rc"

echo "pass=$pass fail=$fail"; [ "$fail" = 0 ]
