#!/usr/bin/env bash
# name: test_pre_push.sh
# purpose: test pre-push.sh run, install, uninstall and the installed hook against a fixture repository (TP-1 to TP-5)
# inputs: none; run in the workflow test image from the repository root
# outputs: "ok <case>" or "FAIL <case>" per check, last line "pre-push: pass=<n> fail=<m>"; exit 1 when m>0
# writes-to: a temp dir removed on exit
# cleanup: the temp dir is removed by trap on EXIT
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PP="$HERE/../pre-push.sh"
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok() { echo "ok $1"; pass=$((pass + 1)); }
bad() { echo "FAIL $1"; fail=$((fail + 1)); }
check() { local name="$1"; shift; if "$@"; then ok "$name"; else bad "$name"; fi; }

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0="*"
git init -q --bare "$W/r.git"
git clone -q "$W/r.git" "$W/c" 2>/dev/null
cd "$W/c" || exit 1
git checkout -q -b main
echo a > a; git add a; git commit -qm init
git push -q origin main
git remote set-url origin https://github.com/o/r.git
git remote set-url --push origin "$W/r.git"
git fetch -q "$W/r.git" main:refs/remotes/origin/main

# cfg <file> <gates-json>: a fixture config with the gates under repos["o/r"]
cfg() { jq -n --argjson g "$2" '{budget_s: 30, timeout_s: 60, defaults: {gates: []}, repos: {"o/r": {gates: $g}}}' > "$1"; }

# TP-1: red gate refused with name and output; green passes
cfg "$W/red.json" '[{"name":"bad","needs":[],"cmd":"echo boom-out; false"},{"name":"good","needs":[],"cmd":"true"}]'
out="$(bash "$PP" run --repo "$W/c" --config "$W/red.json" 2>&1)"; rc=$?
check "TP-1 red exits 1" test "$rc" -eq 1
check "TP-1 red names gate" grep -q "PREPUSH-RED bad" <<<"$out"
check "TP-1 red shows output" grep -q "  boom-out" <<<"$out"
cfg "$W/green.json" '[{"name":"g1","needs":[],"cmd":"true"},{"name":"g2","needs":[],"cmd":"true"}]'
out="$(bash "$PP" run --repo "$W/c" --config "$W/green.json" 2>&1)"; rc=$?
check "TP-1 green exits 0" test "$rc" -eq 0
check "TP-1 green prints OK" grep -q "^PREPUSH-OK 2 gates" <<<"$out"
out="$(PRE_PUSH_CONFIG="$W/green.json" bash "$PP" run --repo "$W/c" 2>&1)"
check "TP-1 env config" grep -q "^PREPUSH-OK 2 gates" <<<"$out"

# TP-2: gates run in parallel
cfg "$W/par.json" '[{"name":"s1","needs":[],"cmd":"sleep 2"},{"name":"s2","needs":[],"cmd":"sleep 2"},{"name":"s3","needs":[],"cmd":"sleep 2"}]'
s=$(date +%s)
bash "$PP" run --repo "$W/c" --config "$W/par.json" >/dev/null 2>&1; rc=$?
d=$(($(date +%s) - s))
check "TP-2 three sleeps exit 0" test "$rc" -eq 0
check "TP-2 three sleeps under 5s (took ${d}s)" test "$d" -lt 5

# TP-3: missing tool and rc 127 skip, never run
cfg "$W/skip.json" '[{"name":"nt","needs":["no-such-tool-xyz"],"cmd":"touch '"$W"'/ran"},{"name":"r127","needs":[],"cmd":"exit 127"}]'
out="$(bash "$PP" run --repo "$W/c" --config "$W/skip.json" 2>&1)"; rc=$?
check "TP-3 exits 0" test "$rc" -eq 0
check "TP-3 needs skip" grep -q "PREPUSH-SKIP nt ENV-MISSING no-such-tool-xyz" <<<"$out"
check "TP-3 cmd never ran" test ! -e "$W/ran"
check "TP-3 127 skip" grep -q "PREPUSH-SKIP r127 ENV-MISSING" <<<"$out"

# TP-4: install idempotent, foreign kept, uninstall clean
out="$(bash "$PP" install --repo "$W/c")"
check "TP-4 installed" grep -q "^PREPUSH-HOOK-INSTALLED" <<<"$out"
out="$(bash "$PP" install --repo "$W/c")"
check "TP-4 nochange" grep -q "^PREPUSH-HOOK-NOCHANGE" <<<"$out"
check "TP-4 hook is 8 lines" test "$(wc -l < "$W/c/.git/hooks/pre-push")" -eq 8
check "TP-4 hook executable" test -x "$W/c/.git/hooks/pre-push"
out="$(bash "$PP" uninstall --repo "$W/c")"
check "TP-4 removed" grep -q "^PREPUSH-HOOK-REMOVED" <<<"$out"
out="$(bash "$PP" uninstall --repo "$W/c")"
check "TP-4 absent" grep -q "^PREPUSH-HOOK-ABSENT" <<<"$out"
printf '#!/bin/sh\necho mine\n' > "$W/c/.git/hooks/pre-push"
before="$(sha256sum "$W/c/.git/hooks/pre-push")"
out="$(bash "$PP" install --repo "$W/c")"
check "TP-4 foreign install" grep -q "^PREPUSH-HOOK-FOREIGN" <<<"$out"
out="$(bash "$PP" uninstall --repo "$W/c")"
check "TP-4 foreign uninstall" grep -q "^PREPUSH-HOOK-FOREIGN" <<<"$out"
check "TP-4 foreign untouched" test "$before" = "$(sha256sum "$W/c/.git/hooks/pre-push")"
rm -f "$W/c/.git/hooks/pre-push"

# TP-5: the installed hook refuses a red push and lets a green one through
bash "$PP" install --repo "$W/c" >/dev/null
git checkout -q -b feat
echo b > b; git add b; git commit -qm change
head0="$(git --git-dir="$W/r.git" rev-parse -q --verify refs/heads/feat || echo none)"
PRE_PUSH_CONFIG="$W/red.json" git push -q origin feat >/dev/null 2>&1; rc=$?
check "TP-5 red push refused" test "$rc" -ne 0
check "TP-5 remote ref unmoved" test "$head0" = "$(git --git-dir="$W/r.git" rev-parse -q --verify refs/heads/feat || echo none)"
PRE_PUSH_CONFIG="$W/green.json" git push -q origin feat >"$W/push.out" 2>&1; rc=$?; [ "$rc" -eq 0 ] || cat "$W/push.out"
check "TP-5 green push passes" test "$rc" -eq 0
check "TP-5 remote ref moved" test "$(git rev-parse HEAD)" = "$(git --git-dir="$W/r.git" rev-parse -q --verify refs/heads/feat || echo none)"

echo "pre-push: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
