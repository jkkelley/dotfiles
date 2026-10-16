#!/usr/bin/env bash
# name: 320-stale-merged.sh
# purpose: prove work-order.sh stale-merged lists open tickets whose PR or branch merged, and writes nothing (WO-20261016-2d5b, ORD-0848 Y3)
# inputs: SKILL (skill dir), a project built with testing/assert.sh, a canned gh on PATH
# outputs: ok/FAIL lines from assert.sh
# writes-to: a temporary project under the test sandbox only
# cleanup: the sandbox project is removed by the test harness
# A ticket whose PR merged without close-out stays open and the line reads it as
# work. The verb asks gh and reports; it must not touch the tree.
source "${SKILL:-/skill}/testing/assert.sh"

d=$(git_project)
mk() { # mk <title> -> id; the ticket stays a draft until set_fm rewrites it
  wo new --project "$d" --title "$1" --type chore --problem P --out X --top-level --ac "w" 2>/dev/null | tail -1
}
set_fm() { # set_fm <id> <status> <pr|null> <branch|null>
  local f; f=$(find "$d/work-orders" -name "$1-*.md" | head -1)
  sed -i -E "s|^  \"status\": \".*\",|  \"status\": \"$2\",|; s|^  \"pr\": .*,|  \"pr\": $3,|; s|^  \"branch\": .*,|  \"branch\": $4,|" "$f"
}
a=$(mk "ready merged pr");   set_fm "$a" ready 11 null
b=$(mk "review open pr");    set_fm "$b" in-review 12 null
c=$(mk "progress by branch"); set_fm "$c" in-progress null '"feat/merged-one"'
e=$(mk "draft with pr");     set_fm "$e" draft 11 null
g=$(mk "review merged pr");  set_fm "$g" in-review 13 null
h=$(mk "branch not merged"); set_fm "$h" in-progress null '"feat/open-one"'
git -C "$d" add -A && git -C "$d" commit -qm "fixtures"

stub="$WORK/stub-320"; mkdir -p "$stub"
cat >"$stub/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  "repo view"*) echo "acme/shop" ;;
  *"pr view 11 "*) echo '{"state":"MERGED","mergeCommit":{"oid":"0e8a5934aaaaaaaa"},"mergedAt":"2026-10-15T01:00:00Z","url":"https://x/pull/11"}' ;;
  *"pr view 12 "*) echo '{"state":"OPEN","mergeCommit":null,"mergedAt":null,"url":"https://x/pull/12"}' ;;
  *"pr view 13 "*) echo '{"state":"MERGED","mergeCommit":{"oid":"131a4bc4bbbbbbbb"},"mergedAt":"2026-10-15T02:00:00Z","url":"https://x/pull/13"}' ;;
  *"pr list"*"--head feat/merged-one"*) echo '[{"number":21,"mergeCommit":{"oid":"5ee83b0ccccccccc"},"mergedAt":"2026-10-15T03:00:00Z","url":"https://x/pull/21"}]' ;;
  *"pr list"*) echo '[]' ;;
  *) echo '{}' ;;
esac
STUB
chmod +x "$stub/gh"
export PATH="$stub:$PATH"

before=$(git -C "$d" status --porcelain | sort)
out=$(wo stale-merged --project "$d" --pr-repo acme/shop 2>/dev/null); rc=$?
assert_eq 0 "$rc" "stale-merged exits 0 with findings"
assert_eq 3 "$(printf '%s\n' "$out" | grep -c '^READY-MERGED ')" "three stale tickets listed"
printf '%s\n' "$out" | grep -q "^READY-MERGED $a ready pr=11 merge=0e8a5934aaaa ready merged pr\$" \
  && _pass "text line shape for a ready ticket with a merged pr" || _fail "text line shape" "$out"
printf '%s\n' "$out" | grep -q "^READY-MERGED $c in-progress pr=21 merge=5ee83b0ccccc " \
  && _pass "in-progress ticket found by merged branch" || _fail "branch lookup" "$out"
printf '%s\n' "$out" | grep -q "^READY-MERGED $g in-review pr=13 " \
  && _pass "in-review ticket listed" || _fail "in-review" "$out"
for x in "$b" "$e" "$h"; do
  printf '%s\n' "$out" | grep -q "$x" && _fail "$x must not be listed" "$out" || _pass "$x not listed"
done

capture js wo stale-merged --project "$d" --pr-repo acme/shop --json
assert_eq 3 "$(jq 'length' <<<"$js")" "--json is an array of three"
assert_eq "id,title,status,pr,repo,merge_commit,merged_at,url" \
  "$(jq -r '.[0]|keys_unsorted|join(",")' <<<"$js")" "--json row keys"
assert_eq acme/shop "$(jq -r '.[0].repo' <<<"$js")" "--json carries the repo"

# default repo comes from gh repo view in the project
capture js2 wo stale-merged --project "$d" --json
assert_eq acme/shop "$(jq -r '.[0].repo' <<<"$js2")" "repo defaults to gh repo view"

# archived done ticket is not scanned
f=$(find "$d/work-orders" -name "$a-*.md" | head -1)
mkdir -p "$d/work-orders/archive/2026"; git -C "$d" mv "$f" "$d/work-orders/archive/2026/" >/dev/null 2>&1 \
  || mv "$f" "$d/work-orders/archive/2026/"
git -C "$d" add -A && git -C "$d" commit -qm "archive a"
before=$(git -C "$d" status --porcelain | sort)
capture js3 wo stale-merged --project "$d" --pr-repo acme/shop --json
assert_eq 2 "$(jq 'length' <<<"$js3")" "archived ticket is not scanned"

# nothing stale -> []
cat >"$stub/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in *"pr view"*) echo '{"state":"OPEN"}' ;; *"pr list"*) echo '[]' ;; *) echo '{}' ;; esac
STUB
capture js4 wo stale-merged --project "$d" --pr-repo acme/shop --json
assert_eq '[]' "$js4" "no findings prints []"
run 0 "no findings still exits 0" wo stale-merged --project "$d" --pr-repo acme/shop

# gh down: 3 tries then exit 4
printf '#!/usr/bin/env bash\nexit 1\n' >"$stub/gh"
run 4 "gh failing exits 4 gh_failed" wo stale-merged --project "$d" --pr-repo acme/shop

after=$(git -C "$d" status --porcelain | sort)
assert_eq "$before" "$after" "the verb wrote nothing (git status unchanged)"
finish
