#!/usr/bin/env bash
# ci-template.test.sh - the pr-flow CI and merge-on-green templates render whole, and the merge decision follows
# coq's gate minus review: merge only a green, current, non-conflicting head (pr-process.md rules R2, R3, R6).
# Runs in the workflow test image, --network=none; gh is a stub, so nothing reaches GitHub.
# shellcheck disable=SC2015 # ok/no only echo, so the A && B || C form cannot misfire
set -euo pipefail
here="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
R="$here/bin/pr-flow-ci-render.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
no() { fail=$((fail + 1)); echo "FAIL $1"; }

# --- render ---------------------------------------------------------------------------------------------------
for t in ci merge-on-green; do
  "$R" --template "$t" --out "$tmp/$t.yml"
  if ! grep -q '@@' "$tmp/$t.yml" && python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "$tmp/$t.yml"; then
    ok "render $t: no placeholder left, YAML parses"
  else no "render $t"; fi
done
grep -q 'cancel-in-progress: true' "$tmp/ci.yml" && ok "ci cancels a superseded run" || no "ci concurrency"
grep -q 'needs: \[check\]' "$tmp/ci.yml" && grep -q 'if: always()' "$tmp/ci.yml" && ok "ci-ok always runs after check" || no "ci-ok"
if grep -E 'uses: [^ ]+@' "$tmp/ci.yml" | grep -vqE '@[0-9a-f]{40} #'; then no "an action is not SHA-pinned"; else ok "every action SHA-pinned"; fi
grep -hv '^ *#' "$tmp/ci.yml" "$tmp/merge-on-green.yml" | grep -q 'ubuntu-latest' && no "ubuntu-latest used" || ok "no ubuntu-latest"
grep -v '^ *#' "$tmp/merge-on-green.yml" | grep -q -- '--auto' && no "merge-on-green uses --auto" || ok "never gh pr merge --auto"
"$R" --template merge-on-green --set 'WORKFLOWS=["skill PR gate","rolodex check"]' --set REQUIRED_CHECK=x \
  | grep -q 'workflows: \["skill PR gate","rolodex check"\]' && ok "--set WORKFLOWS renders" || no "--set WORKFLOWS"
rc=0; "$R" --template nope >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] && ok "unknown template exits 2" || no "unknown template rc=$rc"
rc=0; "$R" --template ci --set BOGUS=1 >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] && ok "unknown key exits 2" || no "unknown key rc=$rc"
rc=0; "$R" --template ci --set 'PR_TARGETS=[]' >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] && ok "empty target list exits 2" || no "empty targets rc=$rc"

# --- merge decision, stub gh ----------------------------------------------------------------------------------
sed -n '/# >>> merge-on-green/,/# <<< merge-on-green/p' "$here/templates/merge-on-green.yml" | sed 's/^          //' > "$tmp/mog.sh"
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >> "$LOG"
case "$*" in
  "api repos/o/r/commits/$HEAD_SHA/pulls"*) [ "${F_PR:-}" = none ] && echo "" || echo 7 ;;
  "pr view 7 -R o/r --json headRefOid,mergeable,state"*) echo "${F_HEAD:-$HEAD_SHA} ${F_MERGEABLE:-MERGEABLE} ${F_STATE:-OPEN}" ;;
  "api repos/o/r/commits/$HEAD_SHA/check-runs"*) echo "${F_CHECKS}" ;;
  "pr merge"*) [ "${F_MERGE_FAIL:-}" = 1 ] && exit 1; exit 0 ;;
  "pr view 7 -R o/r --json state"*) echo "${F_AFTER:-OPEN}" ;;
  "workflow run"*) exit 0 ;;
  *) echo "stub gh: unexpected $*" >&2; exit 9 ;;
esac
STUB
chmod +x "$tmp/bin/gh"
green='[{"n":"ci-ok","s":"completed","c":"success"},{"n":"lint","s":"completed","c":"skipped"}]'
run() { # name expect-merge expect-out [VAR=val ...]
  local name="$1" want="$2" pat="$3"; shift 3
  : > "$tmp/log"
  out="$(env PATH="$tmp/bin:$PATH" LOG="$tmp/log" REPO=o/r HEAD_SHA=abc REQUIRED_CHECK=ci-ok DISPATCH="${DISPATCH:-}" \
    F_CHECKS="$green" "$@" bash "$tmp/mog.sh" 2>&1)" || true
  local merged=no; grep -q '^gh pr merge 7 -R o/r --squash --delete-branch --match-head-commit abc$' "$tmp/log" && merged=yes
  if [ "$merged" = "$want" ] && grep -q -- "$pat" <<<"$out"; then ok "$name"; else no "$name: merged=$merged out=$out"; fi
}
run "green head merges with --match-head-commit"     yes '^200 '
run "no open PR for the head holds"                   no  '^3 .*no open PR'         F_PR=none
run "head moved holds"                                no  '^3 .*head moved'         F_HEAD=def
run "conflicting posts 409, no merge"                 no  '^409 '                   F_MERGEABLE=CONFLICTING
run "already merged posts nothing"                    no  '^0 '                     F_STATE=MERGED
run "pending check holds"                             no  '^3 .*pending lint'       F_CHECKS='[{"n":"ci-ok","s":"completed","c":"success"},{"n":"lint","s":"in_progress","c":""}]'
run "failed check holds"                              no  '^3 .*failed lint'        F_CHECKS='[{"n":"ci-ok","s":"completed","c":"success"},{"n":"lint","s":"completed","c":"failure"}]'
run "zero checks holds (F3)"                          no  '^3 .*required check'     F_CHECKS='[]'
run "required check missing holds"                    no  '^3 .*required check'     F_CHECKS='[{"n":"lint","s":"completed","c":"success"}]'
run "lost merge race reads already-merged"            yes '^0 .*already-merged'       F_MERGE_FAIL=1 F_AFTER=MERGED
DISPATCH="skill-publish.yml" run "dispatch after merge" yes '^200 '
grep -q '^gh workflow run skill-publish.yml -R o/r --ref main$' "$tmp/log" && ok "post-merge workflow dispatched" || no "dispatch not called"

echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
