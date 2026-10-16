#!/usr/bin/env bash
# name: gate.test.sh
# purpose: dev gate for pr-flow bin/gate.sh - coq's same-head cases (12-gate.test.sh AC-H1) and the ci-green verb against a stub gh
# inputs: bin/gate.sh; a scratch git repo and a stub gh in a mktemp directory
# outputs: ok/FAIL lines and pass= fail=; exit 1 on any failure
# writes-to: a mktemp directory
# cleanup: the mktemp directory is removed on exit
# shellcheck disable=SC2015 # ok/no only echo, so A && B || C cannot misfire
set -uo pipefail
GATE="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)/bin/gate.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
no() { fail=$((fail + 1)); echo "FAIL $1"; }
eq() { [ "$2" = "$3" ] && ok "$1" || no "$1: got '$2' want '$3'"; }
R="$W/repo"; mkdir -p "$R"; g() { "$GATE" "$@" --repo "$R"; }

# --- same-head, copied from coq factory/tests/cases/12-gate.test.sh ------------------------------------------
git -C "$R" init -q -b main; git -C "$R" config user.email t@example.invalid; git -C "$R" config user.name t
echo one > "$R/code.txt"; git -C "$R" add -A; git -C "$R" commit -q -m A; A=$(git -C "$R" rev-parse --short=7 HEAD)
mkdir -p "$R/events/2026/10"; echo '{}' > "$R/events/2026/10/r.json"; git -C "$R" add -A; git -C "$R" commit -q -m B; B=$(git -C "$R" rev-parse --short=7 HEAD)
git -C "$R" checkout -q "$A"; echo two > "$R/code.txt"; git -C "$R" commit -q -am C; C=$(git -C "$R" rev-parse --short=7 HEAD)
git -C "$R" checkout -q "$A"; mkdir -p "$R/work-orders"; echo x > "$R/work-orders/INDEX.md"; git -C "$R" add -A; git -C "$R" commit -q -m D; D=$(git -C "$R" rev-parse --short=7 HEAD)
out=$(g same-head "$A" "$B"); eq "A and B differ only under events/: same, exit 0" "$?" 0
eq "and nothing is printed" "$out" ""
out=$(g same-head "$A" "$C"); eq "A and C differ in code.txt: exit 1" "$?" 1
eq "the path is named" "$out" "code.txt"
g same-head "$B" "$C" >/dev/null; eq "B and C: exit 1" "$?" 1
g same-head "$A" "$A" >/dev/null; eq "one sha against itself" "$?" 0
g same-head "$A" "${A}0123456" >/dev/null; eq "a prefix of the other is the same head, no git needed" "$?" 0
g same-head "$A" 1234567 >/dev/null 2>&1; eq "a sha the repo does not have: exit 4, not a difference" "$?" 4
g same-head "$A" 'not-a-sha' >/dev/null 2>&1; eq "a malformed sha: exit 4" "$?" 4
g same-head "$A" >/dev/null 2>&1; eq "one sha: usage, exit 2" "$?" 2
g same-head "$A" "$D" >/dev/null; eq "port: default ignore is coq's events/ only, INDEX.md differs" "$?" 1
PR_FLOW_IGNORE_PATHS="events work-orders" g same-head "$A" "$D" >/dev/null; eq "port: PR_FLOW_IGNORE_PATHS adds work-orders/" "$?" 0

# --- ci-green, stub gh ------------------------------------------------------------------------------------------
mkdir -p "$W/bin"; cat > "$W/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$W/calls"
[ "${F_FAIL:-}" = 1 ] && exit 1
case "$1 $2" in
  "pr view") echo "${F_HEAD:-abc1234def}" ;;
  "api repos/o/r/commits/"*) echo "${F_CHECKS}" ;;
  *) exit 9 ;;
esac
STUB
chmod +x "$W/bin/gh"
export W GH="$W/bin/gh" GATE_BACKOFF=0
green='[{"n":"ci-ok","s":"completed","c":"success"},{"n":"lint","s":"completed","c":"skipped"}]'
cg() { env F_CHECKS="${F_CHECKS:-$green}" "$@" "$GATE" ci-green --slug o/r --pr 7 --sha abc1234; }
out=$(cg); eq "green head: exit 0" "$?" 0
out=$(cg F_HEAD=fff0000); eq "head moved: hold" "$?" 1; [[ $out == "head moved"* ]] && ok "head moved names it" || no "reason: $out"
out=$(F_CHECKS='[]' cg); eq "zero checks: hold (F3)" "$?" 1; [[ $out == *"required check ci-ok"* ]] && ok "zero checks names ci-ok" || no "reason: $out"
out=$(F_CHECKS='[{"n":"ci-ok","s":"completed","c":"success"},{"n":"t","s":"queued","c":""}]' cg); eq "pending: hold" "$?" 1
[[ $out == "pending: t" ]] && ok "pending names the check" || no "reason: $out"
out=$(F_CHECKS='[{"n":"ci-ok","s":"completed","c":"success"},{"n":"t","s":"completed","c":"failure"}]' cg); eq "failed: hold" "$?" 1
out=$(F_CHECKS='[{"n":"lint","s":"completed","c":"success"}]' cg); eq "required missing: hold" "$?" 1
out=$(F_CHECKS='[{"n":"x","s":"completed","c":"success"}]' "$GATE" ci-green --slug o/r --pr 7 --sha abc1234 --required x); eq "--required names another check" "$?" 0
: > "$W/calls"; out=$(cg F_FAIL=1 2>/dev/null); eq "gh down: exit 4" "$?" 4; eq "three tries, no more" "$(wc -l < "$W/calls" | tr -d ' ')" 3
"$GATE" ci-green --slug o/r --pr 7 >/dev/null 2>&1; eq "no --sha: usage, exit 2" "$?" 2
"$GATE" when x >/dev/null 2>&1; eq "coq's when verb is not ported: exit 2" "$?" 2

# --- ticket-open (WO-20261016-0233): a head whose work-order is still open is held ----------------------------------------
T="$W/trepo"; mkdir -p "$T"; tg() { "$GATE" ticket-open --repo "$T" --base main --sha "$1"; }
git -C "$T" init -q -b main; git -C "$T" config user.email t@example.invalid; git -C "$T" config user.name t
echo a > "$T/a"; git -C "$T" add -A; git -C "$T" commit -q -m base
wo() { printf -- '---\n{"id": "%s", "status": "%s"}\n---\n\n# body\n' "$1" "$2"; }   # wo ID STATUS: a ticket file
git -C "$T" switch -q -c f1; mkdir -p "$T/work-orders/E"; wo WO-20261016-aaaa in-progress > "$T/work-orders/E/WO-20261016-aaaa-x.md"
git -C "$T" add -A; git -C "$T" commit -q -m open; S1=$(git -C "$T" rev-parse HEAD)
out=$(tg "$S1"); eq "in-progress ticket: held, exit 1" "$?" 1; eq "the hold line names ticket and status" "$out" "TICKET-OPEN WO-20261016-aaaa in-progress"
git -C "$T" switch -q main; git -C "$T" switch -q -c f2; mkdir -p "$T/work-orders/archive/2026"; wo WO-20261016-bbbb "done" > "$T/work-orders/archive/2026/WO-20261016-bbbb-x.md"
git -C "$T" add -A; git -C "$T" commit -q -m closed; S2=$(git -C "$T" rev-parse HEAD)
tg "$S2" >/dev/null; eq "archived done ticket: exit 0" "$?" 0
git -C "$T" switch -q main; git -C "$T" switch -q -c f3; mkdir -p "$T/work-orders/E"; wo WO-20261016-cccc ready > "$T/work-orders/E/WO-20261016-cccc-x.md"
git -C "$T" add -A; git -C "$T" commit -q -m cut; S3=$(git -C "$T" rev-parse HEAD)
tg "$S3" >/dev/null; eq "new ready ticket: exit 0" "$?" 0
git -C "$T" switch -q main; git -C "$T" switch -q -c f4; echo b > "$T/b"; git -C "$T" add -A; git -C "$T" commit -q -m plain; S4=$(git -C "$T" rev-parse HEAD)
tg "$S4" >/dev/null; eq "no work-orders file: exit 0" "$?" 0
"$GATE" ticket-open --repo "$T" --sha "$S4" >/dev/null 2>&1; eq "no --base: usage, exit 2" "$?" 2

echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
