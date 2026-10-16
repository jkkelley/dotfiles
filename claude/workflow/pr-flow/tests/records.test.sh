#!/usr/bin/env bash
# name: records.test.sh
# purpose: dev gate for pr-flow bin/records.sh - schema-valid records, both backends, post-once, bounded retry
# inputs: bin/records.sh, schemas/pr-flow-record.schema.json; a stub publisher in a mktemp directory
# outputs: ok/FAIL lines and pass= fail=; exit 1 on any failure
# writes-to: a mktemp directory
# cleanup: the mktemp directory is removed on exit
# shellcheck disable=SC2015,SC2181 # ok/no only echo; the exit code under test is read right after the call
set -uo pipefail
RS="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)/bin/records.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# shellcheck disable=SC2016 # the stub expands $1 $2 when it runs
printf '#!/usr/bin/env bash\necho "$1 $2" >> "%s/pub.log"\n' "$W" > "$W/pub"; chmod +x "$W/pub"
printf '#!/usr/bin/env bash\necho x >> "%s/bad.log"; exit 1\n' "$W" > "$W/badpub"; chmod +x "$W/badpub"
export PR_FLOW_PUB="$W/pub" PR_FLOW_STATE="$W/state" RECORDS_BACKOFF=0
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
no() { fail=$((fail + 1)); echo "FAIL $1"; }
base=(--ticket WO-20261016-aaaa --line test --seat sweep)

out=$("$RS" post --kind merged --code 200 --pr 7 --sha abc1234 --repo o/r "${base[@]}")
[ "$(jq -r .kind <<<"$out")" = merged ] && [ "$(jq -r .pr <<<"$out")" = 7 ] && ok "post prints the record" || no "post: $out"
grep -q '^line.test.event.merged {' "$W/pub.log" && ok "bus backend publishes line.test.event.merged" || no "bus subject: $(cat "$W/pub.log")"

: > "$W/pub.log"
"$RS" post --kind merge.conflict --code 409 --pr 7 --sha abc1234 --key "409/o/r/7/abc1234" "${base[@]}" >/dev/null
out=$("$RS" post --kind merge.conflict --code 409 --pr 7 --sha abc1234 --key "409/o/r/7/abc1234" "${base[@]}")
[ -z "$out" ] && [ "$(wc -l < "$W/pub.log" | tr -d ' ')" = 1 ] && ok "a key is posted once (R3)" || no "post-once: $(wc -l < "$W/pub.log")"
"$RS" seen --key "409/o/r/7/abc1234"; [ $? = 0 ] && ok "seen: posted key" || no "seen posted"
"$RS" seen --key "409/o/r/7/def"; [ $? = 1 ] && ok "seen: new key" || no "seen new"

rc=0; "$RS" post --kind bogus --code 200 "${base[@]}" >/dev/null 2>&1 || rc=$?; [ $rc = 3 ] && ok "unknown kind fails the schema, exit 3" || no "kind rc=$rc"
rc=0; "$RS" post --kind regen --code REGEN --pr 7 --sha abc1234 --repo o/r "${base[@]}" >/dev/null 2>&1 || rc=$?; [ $rc = 0 ] && ok "kind regen code REGEN is valid" || no "regen rc=$rc"
rc=0; "$RS" post --kind regen --code NOPE "${base[@]}" >/dev/null 2>&1 || rc=$?; [ $rc = 3 ] && ok "kind regen code NOPE fails the schema" || no "NOPE rc=$rc"
rc=0; "$RS" post --kind merged --code 200 --sha 'zz' "${base[@]}" >/dev/null 2>&1 || rc=$?; [ $rc = 3 ] && ok "bad sha fails the schema" || no "sha rc=$rc"
rc=0; "$RS" post --kind merged --code 200 --note "$(printf 'x%.0s' {1..241})" "${base[@]}" >/dev/null 2>&1 || rc=$?; [ $rc = 3 ] && ok "note over 240 fails" || no "note rc=$rc"
rc=0; "$RS" post --kind merged --code 200 --line test >/dev/null 2>&1 || rc=$?; [ $rc = 2 ] && ok "missing ticket is usage, exit 2" || no "usage rc=$rc"

rc=0; PR_FLOW_PUB="$W/badpub" "$RS" post --kind merged --code 200 --key k1 "${base[@]}" >/dev/null 2>&1 || rc=$?
[ $rc = 4 ] && [ "$(wc -l < "$W/bad.log" | tr -d ' ')" = 3 ] && ok "bus down: 3 tries then exit 4 (R5)" || no "retry rc=$rc"
"$RS" seen --key k1; [ $? = 1 ] && ok "a failed post is not marked posted" || no "failed post marked"

out=$(PR_FLOW_RECORDS=dir PR_FLOW_RECORDS_DIR="$W/records" "$RS" post --kind ci.passed --code 201 --pr 9 --sha abc1234 "${base[@]}")
f=$(find "$W/records" -name '*.json'); [ -n "$f" ] && [ "$(jq -r .id "$f")" = "$(jq -r .id <<<"$out")" ] && [[ $f == "$W/records/20"[0-9][0-9]/[01][0-9]/* ]] \
  && ok "dir backend writes coq's YYYY/MM tree" || no "dir: $f"

echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
