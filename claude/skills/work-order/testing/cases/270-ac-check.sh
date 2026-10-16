#!/usr/bin/env bash
# rolodex: header drafted by scripts/rolodex.py headers - correct any line that is wrong
# name: 270-ac-check.sh
# purpose: Assert the check verb runs each acceptance criterion's scripted check and done refuses while one fails.
# inputs: env SKILL (skill root, default /skill); sourced assert.sh helpers
# outputs: exit code 0 when every assertion passes, assertion lines on stdout
# writes-to: scratch project dirs under $WORK (mktemp), removed with the test sandbox
# cleanup: the sandbox container is discarded; nothing outside $WORK is touched
# The reason this case exists.
#
# Owner, item 30: every acceptance criterion is a scripted check with its exit
# condition, run by script to tick the box. A box ticked by hand is a claim; one
# ticked by `check` carries the command, its exit code and its output, and `done`
# refuses while any check fails. The refusals call work-order.sh directly so the
# wo() defaults cannot mask them.
source "${SKILL:-/skill}/testing/assert.sh"

wos() { bash "$SKILL/scripts/work-order.sh" "$@"; }
d=$(git_project)
export PATH="$(gh_stub "$WORK/stub-270" MERGED cafebabe1234 "$d"):$PATH"
base=(--project "$d" --title "Checked" --type feature --problem P --top-level --out X
      --owner-words W --context C)

run 3 "an --ac with no --ac-check is refused" wos new "${base[@]}" --ac "bare criterion"
run 0 "the refusal is named missing_ac_check" bash -c \
  "bash '$SKILL/scripts/work-order.sh' new ${base[*]@Q} --ac 'bare criterion' --json 2>&1 | jq -e '.error == \"missing_ac_check\"' >/dev/null"
run 2 "--ac-check before any --ac is a usage error" wos new "${base[@]}" --ac-check true --ac-exit 0

run 0 "new binds three checks to three criteria" wos new "${base[@]}" \
  --ac "passes" --ac-check "echo hello world" --ac-exit 0 --ac-expect 'hello w.rld' \
  --ac "wrong exit" --ac-check "exit 4" --ac-exit 0 \
  --ac "wrong output" --ac-check "echo nope" --ac-exit 0 --ac-expect 'yes'
f=$(find "$d/work-orders" -name 'WO-*.md')
id=$(wos list --project "$d" --json | jq -r '.[0].id')
assert_contains "$f" 'check: `echo hello world` exit 0 expect /hello w.rld/' "the check renders under its criterion"
run 0 "ac_checks lands in the frontmatter with index, command, exit and expect" bash -c \
  "awk 'NR==1{next} /^---\$/{exit} {print}' '$f' | jq -e '(.ac_checks | length) == 3 and .ac_checks[0].index == 1 and .ac_checks[0].exit == 0 and .ac_checks[0].expect == \"hello w.rld\"' >/dev/null"

git -C "$d" add -A && git -C "$d" commit -qm "add"
wos approve --project "$d" --id "$id" --no-lavish --reason "no lavish in CI" >/dev/null
git -C "$d" add -A && git -C "$d" commit -qm "approve"
run 3 "check refuses a ready ticket" wos check --project "$d" --id "$id"
wos start --project "$d" --id "$id" >/dev/null

out=$(wos check --project "$d" --id "$id" 2>&1); rc=$?
assert_eq 1 "$rc" "check exits 1 while any check fails"
case $out in *"AC-PASS 1"*) _pass "the passing check prints AC-PASS 1" ;; *) _fail "AC-PASS 1 missing" "$out" ;; esac
case $out in *"AC-FAIL 2 rc=4"*) _pass "the wrong exit code prints AC-FAIL 2 rc=4" ;; *) _fail "AC-FAIL 2 rc=4 missing" "$out" ;; esac
case $out in *"AC-FAIL 3 rc=0"*) _pass "the unmatched output prints AC-FAIL 3 rc=0" ;; *) _fail "AC-FAIL 3 rc=0 missing" "$out" ;; esac
assert_contains "$f" '- [x] `AC-H1`' "the passing criterion was ticked"
assert_contains "$f" 'check: echo hello world exit 0 output: hello world' "the tick records command, exit code and output"
assert_contains "$f" '- [ ] `AC-H2`' "the failing criterion stays unticked"

run 0 "check --index runs one criterion" wos check --project "$d" --id "$id" --index 1

git -C "$d" add -A && git -C "$d" commit -qm "evidence"
wos submit --project "$d" --id "$id" --pr 9 >/dev/null
run 3 "done refuses while a check fails" wos done --project "$d" --id "$id"
run 0 "the refusal is named ac_check_failed" bash -c \
  "bash '$SKILL/scripts/work-order.sh' done --project '$d' --id '$id' --json 2>/dev/null | jq -e '.error == \"ac_check_failed\"' >/dev/null"

# A fresh all-green ticket proves the passing path through done.
d2=$(git_project)
export PATH="$(gh_stub "$WORK/stub-270b" MERGED cafebabe1234 "$d2"):$PATH"
wos new --project "$d2" --title "All green" --type feature --problem P --top-level --out X \
  --owner-words W --context C --ac "ok" --ac-check "echo fine" --ac-exit 0 >/dev/null
id2=$(wos list --project "$d2" --json | jq -r '.[0].id')
git -C "$d2" add -A && git -C "$d2" commit -qm "add"
wos approve --project "$d2" --id "$id2" --no-lavish --reason "no lavish in CI" >/dev/null
git -C "$d2" add -A && git -C "$d2" commit -qm "approve"
wos start --project "$d2" --id "$id2" >/dev/null
git -C "$d2" add -A && git -C "$d2" commit -qm "start"
wos submit --project "$d2" --id "$id2" --pr 3 >/dev/null
run 0 "check on an all-green ticket exits 0 and ticks it" wos check --project "$d2" --id "$id2"
f2=$(find "$d2/work-orders" -name 'WO-*.md')
assert_contains "$f2" '- [x] `AC-H1`' "the criterion is ticked by check"
run 0 "done on an all-green ticket closes" wos done --project "$d2" --id "$id2"
run 0 "the closed ticket is archived" bash -c "find '$d2/work-orders/archive' -name 'WO-*.md' | grep -q ."

# amend: a check is required per --ac, and a withdrawal needs none.
d3=$(new_project)
wos new --project "$d3" --title "Amendable" --type feature --problem P --top-level --out X \
  --owner-words W --context C --ac "old" --ac-check true --ac-exit 0 >/dev/null
id3=$(wos list --project "$d3" --json | jq -r '.[0].id')
run 3 "amend --ac without --ac-check is refused" wos amend --project "$d3" --id "$id3" --ac "new"
run 0 "amend --ac with a check succeeds" \
  wos amend --project "$d3" --id "$id3" --ac "new" --ac-check "echo z" --ac-exit 0
f3=$(find "$d3/work-orders" -name 'WO-*.md')
assert_contains "$f3" 'check: `echo z` exit 0' "the amended criterion carries its new check"
assert_not_contains "$f3" 'true' "the old check is gone with the old criterion"
finish
