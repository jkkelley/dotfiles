#!/usr/bin/env bash
# name: test_review_publish.sh
# purpose: proves review-publish.sh publishes merged content only, idempotently, keeping hand copies (WO-20261016-8c45, TP-1).
# inputs: none (uses bin/review-publish.sh)
# outputs: one 'ok (N) <case>' line per case, then 'ok review-publish: 8 cases'; FAIL and exit 1 otherwise
# writes-to: a mktemp scratch directory only
# cleanup: removes its own temp files on exit
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
P="$R/bin/review-publish.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
fail=0; n=0
ok()  { n=$((n+1)); printf 'ok (%s) %s\n' "$n" "$1"; }
bad() { fail=1; printf 'FAIL %s\n' "$1"; }
ROOT="$T/root"
printf '{"root":"%s","bind":"127.0.0.1","port":45610,"ref":"origin/main"}\n' "$ROOT" > "$T/review.json"
export REVIEW_CONFIG="$T/review.json"

git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$T/seed" 2>/dev/null
git -C "$T/seed" checkout -q -b main 2>/dev/null
mkdir -p "$T/seed/docs/sub"; echo a > "$T/seed/docs/index.html"; echo b > "$T/seed/docs/sub/p.html"; echo x > "$T/seed/other.txt"
git -C "$T/seed" add -A; git -C "$T/seed" commit -qm one; git -C "$T/seed" push -q origin main
git clone -q "$T/origin.git" "$T/c"

# 1 publish docs/
out=$("$P" "$T/c" docs site 2>&1); rc=$?
if [ $rc -eq 0 ] && [ -f "$ROOT/site/index.html" ] && [ -f "$ROOT/site/sub/p.html" ] \
  && grep -qx 'http://127.0.0.1:45610/site/index.html' <<<"$out" && grep -qx 'http://127.0.0.1:45610/site/sub/p.html' <<<"$out" \
  && [ "$(grep -c '^http://' <<<"$out")" -eq 2 ] && grep -q '^ok review site [0-9a-f]\{12\} (2 files)$' <<<"$out"; then ok "publish docs/ prints a URL per file"; else bad "publish ($rc: $out)"; fi

# 2 same sha is unchanged
m1=$(stat -c %y "$ROOT/site/.review-publish.json")
out=$("$P" "$T/c" docs site 2>&1); rc=$?
m2=$(stat -c %y "$ROOT/site/.review-publish.json")
if [ $rc -eq 0 ] && grep -q '^ok review site unchanged at ' <<<"$out" && [ "$m1" = "$m2" ]; then ok "same sha is unchanged"; else bad "idempotent ($rc: $out)"; fi

# 3 new commit removing a file republishes
git -C "$T/seed" rm -q docs/sub/p.html; git -C "$T/seed" commit -qm two; git -C "$T/seed" push -q origin main
out=$("$P" "$T/c" docs site 2>&1); rc=$?
if [ $rc -eq 0 ] && [ ! -e "$ROOT/site/sub/p.html" ] && grep -q '(1 files)' <<<"$out"; then ok "new commit republishes, removed file gone"; else bad "republish ($rc: $out)"; fi

# 4 SRC absent
out=$("$P" "$T/c" nope site 2>&1); rc=$?
if [ $rc -eq 3 ] && grep -q '^REVIEW-NOSRC nope not on origin/main$' <<<"$out"; then ok "absent SRC is REVIEW-NOSRC"; else bad "nosrc ($rc: $out)"; fi

# 5 bad NAME
before=$(find "$ROOT" | sort)
out=$("$P" "$T/c" docs ../x 2>&1); rc=$?
after=$(find "$ROOT" | sort)
if [ $rc -eq 2 ] && [ "$before" = "$after" ] && [ ! -e "$T/x" ]; then ok "NAME ../x is usage, nothing written"; else bad "badname ($rc: $out)"; fi

# 6 hand copy preserved
mkdir -p "$ROOT/hand"; echo h > "$ROOT/hand/old.html"
out=$("$P" "$T/c" docs hand 2>&1); rc=$?
if [ $rc -eq 0 ] && [ -f "$ROOT/hand/index.html" ] && [ ! -e "$ROOT/hand/old.html" ] \
  && [ -f "$(find "$ROOT/.retired" -name old.html -path '*hand-*' | head -1)" ] && grep -q 'hand copy moved to' <<<"$out"; then ok "hand copy moved to .retired"; else bad "handcopy ($rc: $out)"; fi

# 7 unpushed local commit not published
echo local > "$T/c/docs/local.html"; git -C "$T/c" add -A; git -C "$T/c" commit -qm local
out=$("$P" "$T/c" docs local7 2>&1); rc=$?
if [ $rc -eq 0 ] && [ ! -e "$ROOT/local7/local.html" ] && [ -f "$ROOT/local7/index.html" ]; then ok "unpushed commit not published"; else bad "unpushed ($rc: $out)"; fi

# 8 fetch fails: warn, publish from last fetched ref
git -C "$T/c" remote set-url origin "$T/gone.git"
out=$("$P" "$T/c" docs fallback 2>&1); rc=$?
if [ $rc -eq 0 ] && grep -q '^warn review fetch failed, using last fetched origin/main$' <<<"$out" && [ -f "$ROOT/fallback/index.html" ]; then ok "fetch failure falls back to last fetched ref"; else bad "fetchfail ($rc: $out)"; fi

[ $fail -eq 0 ] || exit 1
echo "ok review-publish: $n cases"
