#!/usr/bin/env bash
# name: test_main_clone_guard.sh
# purpose: proves main-clone-guard.sh check and ff over a fixture bare remote (WO-20261016-3327, TP-1).
# inputs: none (uses bin/main-clone-guard.sh)
# outputs: one 'ok (N) <case>' line per case, then 'ok main-clone-guard: 8 cases'; FAIL and exit 1 otherwise
# writes-to: a mktemp scratch directory only
# cleanup: removes its own temp files on exit
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
G="$R/bin/main-clone-guard.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
fail=0; n=0
ok()  { n=$((n+1)); printf 'ok (%s) %s\n' "$n" "$1"; }
bad() { fail=1; printf 'FAIL %s\n' "$1"; }
# expect NAME RC PATTERN -- args ; runs the guard, checks exit code and a substring of stdout+stderr
expect() { local name=$1 rc=$2 pat=$3; shift 4; local out; out=$("$G" "$@" 2>&1); local got=$?
  if [ "$got" -eq "$rc" ] && grep -q -- "$pat" <<<"$out"; then ok "$name"; else bad "$name (rc $got: $out)"; fi; }
git init -q --bare -b main "$T/remote.git"
git clone -q "$T/remote.git" "$T/seed" 2>/dev/null
git -C "$T/seed" checkout -q -b main 2>/dev/null; echo a > "$T/seed/f"; git -C "$T/seed" add f; git -C "$T/seed" commit -qm one; git -C "$T/seed" push -q origin main
newclone() { rm -rf "$T/c"; git clone -q "$T/remote.git" "$T/c"; }
push1() { echo "$1" >> "$T/seed/f"; git -C "$T/seed" commit -qam "$1"; git -C "$T/seed" push -q origin main; }

newclone
expect "up to date check" 0 "ok main-clone" -- check "$T/c"

push1 two
expect "behind check" 3 "behind origin/main by 1" -- check "$T/c"
c2=0
"$G" ff "$T/c" 2>&1 | grep -q fast-forwarded || c2=1
"$G" ff "$T/c" 2>&1 | grep -q "^ok main-clone" || c2=1
"$G" check "$T/c" >/dev/null 2>&1 || c2=1
if [ "$c2" -eq 0 ]; then ok "ff then ff again then check"; else bad "ff idempotent"; fi

newclone; git -C "$T/c" checkout -q -b feat
expect "on feat check" 3 "on feat" -- check "$T/c"
expect "on feat ff" 3 "on feat" -- ff "$T/c"
if [ "$(git -C "$T/c" symbolic-ref --short HEAD)" = feat ]; then ok "ff left HEAD on feat"; else bad "ff switched branch"; fi

newclone; push1 three; echo x >> "$T/c/f"
expect "dirty ff" 3 "dirty" -- ff "$T/c"

newclone; echo loc >> "$T/c/f"; git -C "$T/c" commit -qam local; push1 four
expect "diverged ff" 3 "diverged" -- ff "$T/c"

newclone; mv "$T/remote.git" "$T/gone.git"
expect "remote gone warns and answers" 0 "fetch failed" -- check "$T/c"
mv "$T/gone.git" "$T/remote.git"

mkdir "$T/plain"
expect "non-git dir skips" 0 "skip main-clone" -- check "$T/plain"
expect "no arguments" 2 "usage" --

if [ "$fail" -eq 0 ]; then echo "ok main-clone-guard: 8 cases"; fi
exit "$fail"
