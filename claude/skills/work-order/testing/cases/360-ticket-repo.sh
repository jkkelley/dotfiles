#!/usr/bin/env bash
# name: 360-ticket-repo.sh
# purpose: prove the ticket repo field - new --repo, set --repo/--clear-repo, submit -R, stale-merged precedence (WO-20261016-f57d, 2d5b TP-3)
# inputs: SKILL (skill dir), a project built with testing/assert.sh, a canned gh on PATH that logs its argv
# outputs: ok/FAIL lines from assert.sh
# writes-to: a temporary project and the sandbox gh log only
# cleanup: the sandbox is removed by the test harness
# A bare pr number carries no repo; .repo names it, and the precedence is
# URL pr > ticket .repo > --pr-repo > the project repo.
source "${SKILL:-/skill}/testing/assert.sh"
has() {
  if printf '%s\n' "$1" | grep -qF -- "$2"; then _pass "$3"; else _fail "$3" "not found: $2" "in: ${1:0:300}"; fi
}

d=$(git_project)
mk() { local t="$1"; shift; wo new --project "$d" --title "$t" --type chore --problem P --out X --ac "w" "$@" 2>/dev/null | tail -1; }
ff() { find "$d/work-orders" -name "$1-*.md" | head -1; }
set_fm() { # set_fm <id> <status> <pr|null>
  sed -i -E "s|^  \"status\": \".*\",|  \"status\": \"$2\",|; s|^  \"pr\": .*,|  \"pr\": $3,|" "$(ff "$1")"
}

stub="$WORK/stub-360"; mkdir -p "$stub"; glog="$WORK/gh360.log"; : >"$glog"
cat >"$stub/gh" <<STUB
#!/usr/bin/env bash
echo "\$*" >>"$glog"
case "\$*" in
  "repo view"*) echo "acme/shop" ;;
  *"pr view"*) echo '{"state":"MERGED","mergeCommit":{"oid":"abc123abc123abc1"},"mergedAt":"2026-10-15T01:00:00Z","url":"https://x/pull/1","number":1}' ;;
  *) echo '[]' ;;
esac
STUB
chmod +x "$stub/gh"; export PATH="$stub:$PATH"

# new --repo writes the key; a bad repo is exit 2 bad_repo
a=$(mk "with repo" --top-level --repo own/code)
assert_eq own/code "$(sed -n '/^---$/,/^---$/p' "$(ff "$a")" | grep -v '^---$' | jq -r .repo)" "new --repo writes the key"
run 2 "new --repo bad" wo new --project "$d" --title t --type chore --problem P --out X --ac w --top-level --repo nonsense
run 2 "set --repo bad exits 2" wo set --project "$d" --id "$a" --repo "no slash"

# set --repo: idempotent, byte-identical on a re-run
b=$(mk "bare pr" --top-level); set_fm "$b" ready 52
git -C "$d" add -A && git -C "$d" commit -qm fixtures
run 0 "set --repo" wo set --project "$d" --id "$b" --repo acme/code
git -C "$d" add -A && git -C "$d" commit -qm repo-set
run 0 "set --repo twice" wo set --project "$d" --id "$b" --repo acme/code
git -C "$d" diff --quiet && _pass "second set --repo left git diff --quiet" || _fail "second set --repo rewrote the file"

# stale-merged: .repo wins over --pr-repo for a bare number
: >"$glog"
capture js wo stale-merged --project "$d" --pr-repo other/x --json
assert_eq acme/code "$(jq -r --arg i "$b" '.[]|select(.id==$i)|.repo' <<<"$js")" "bare pr + .repo -> row repo is .repo"
has "$(cat "$glog")" "pr view 52 -R acme/code" "gh called with -R the ticket repo"

# no .repo: --pr-repo applies
run 0 "clear-repo" wo set --project "$d" --id "$b" --clear-repo
assert_eq null "$(sed -n '/^---$/,/^---$/p' "$(ff "$b")" | grep -v '^---$' | jq -c .repo)" "--clear-repo writes null"
: >"$glog"
capture js wo stale-merged --project "$d" --pr-repo other/x --json
assert_eq other/x "$(jq -r --arg i "$b" '.[]|select(.id==$i)|.repo' <<<"$js")" "no .repo + --pr-repo -> --pr-repo"

# a URL pr names its own repo even when .repo is set
run 0 "set repo again" wo set --project "$d" --id "$b" --repo acme/code
set_fm "$b" ready '"https://github.com/url/owner/pull/9"'
capture js wo stale-merged --project "$d" --json
assert_eq url/owner "$(jq -r --arg i "$b" '.[]|select(.id==$i)|.repo' <<<"$js")" "URL pr wins over .repo"

# submit with .repo calls gh pr view <n> -R <repo>
c=$(mk "to submit" --top-level --repo acme/code); set_fm "$c" in-progress null
: >"$glog"
run 0 "submit with .repo" wo submit --project "$d" --id "$c" --pr 77
has "$(cat "$glog")" "pr view 77 -R acme/code" "submit calls gh pr view 77 -R acme/code"
