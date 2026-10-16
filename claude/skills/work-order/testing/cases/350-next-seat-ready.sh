#!/usr/bin/env bash
# name: 350-next-seat-ready.sh
# purpose: prove work-order.sh next lists only seat-ready leaves and the set verb writes labels (WO-20261016-67c7, ORD-0932 Q2)
# inputs: SKILL (skill dir), a project built with testing/assert.sh, a canned gh on PATH
# outputs: ok/FAIL lines from assert.sh
# writes-to: a temporary project under the test sandbox only
# cleanup: the sandbox project is removed by the test harness
# next fed seats epics, merged tickets and other lines' tickets. It must hold
# only leaves of its own line, and set is the only thing that writes the label.
source "${SKILL:-/skill}/testing/assert.sh"
has() { # has <text> <needle> <label> - assert_contains takes a file; these are strings
  if printf '%s\n' "$1" | grep -qF -- "$2"; then _pass "$3"; else _fail "$3" "not found: $2" "in: ${1:0:300}"; fi
}

d=$(git_project)
mk() { # mk <title> [extra new flags...] -> id
  local t="$1"; shift
  wo new --project "$d" --title "$t" --type chore --problem P --out X --ac "w" "$@" 2>/dev/null | tail -1
}
ff() { find "$d/work-orders" -name "$1-*.md" | head -1; }
set_fm() { # set_fm <id> <status> <pr|null> <branch|null>
  sed -i -E "s|^  \"status\": \".*\",|  \"status\": \"$2\",|; s|^  \"pr\": .*,|  \"pr\": $3,|; s|^  \"branch\": .*,|  \"branch\": $4,|" "$(ff "$1")"
}

epic=$(mk "the epic" --top-level);               set_fm "$epic" ready null null
kid=$(mk "ready child" --parent "$epic");        set_fm "$kid" ready null null
epic2=$(mk "epic two" --top-level);              set_fm "$epic2" ready null null
dead=$(mk "archived child" --parent "$epic2");   set_fm "$dead" done null null
mkdir -p "$d/work-orders/archive/2026"
mv "$(ff "$dead")" "$d/work-orders/archive/2026/"
prm=$(mk "pr merged" --top-level);               set_fm "$prm" ready 11 null
pro=$(mk "pr open" --top-level);                 set_fm "$pro" ready 12 null
brm=$(mk "branch merged" --top-level);           set_fm "$brm" ready null '"feat/merged-one"'
git -C "$d" add -A && git -C "$d" commit -qm fixtures

stub="$WORK/stub-350"; mkdir -p "$stub"
cat >"$stub/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  "repo view"*) echo "acme/shop" ;;
  *"pr view 11 "*) echo '{"state":"MERGED","mergeCommit":{"oid":"0e8a5934aaaaaaaa"},"mergedAt":"2026-10-15T01:00:00Z","url":"https://x/pull/11"}' ;;
  *"pr view 12 "*) echo '{"state":"OPEN","mergeCommit":null,"mergedAt":null,"url":"https://x/pull/12"}' ;;
  *"pr list"*"--head feat/merged-one"*) echo '[{"number":21,"mergeCommit":{"oid":"5ee83b0ccccccccc"},"mergedAt":"2026-10-15T03:00:00Z","url":"https://x/pull/21"}]' ;;
  *"pr list"*) echo '[]' ;;
  *) echo '{}' ;;
esac
STUB
chmod +x "$stub/gh"
export PATH="$stub:$PATH"

before=$(git -C "$d" status --porcelain | sort)
capture js wo next --project "$d" --json
ids=$(jq -r '.[].id' <<<"$js" | sort | tr '\n' ' ')
want=$(printf '%s\n' "$kid" "$pro" | sort | tr '\n' ' ')
assert_eq "$want" "$ids" "next lists the ready child and the open-pr ticket only"
assert_eq "[]" "$(jq -c '.[0].labels' <<<"$js")" "--json rows carry labels"
after=$(git -C "$d" status --porcelain | sort)
assert_eq "$before" "$after" "next wrote nothing (git status unchanged)"

# --offline skips the merged check and says so
out=$(wo next --project "$d" --offline --json 2>"$WORK/err350"); rc=$?
assert_eq 0 "$rc" "--offline exits 0"
has "$(cat "$WORK/err350")" "next: merged check skipped (--offline)" "--offline warns on stderr"
has "$(jq -r '.[].id' <<<"$out")" "$prm" "--offline keeps the merged ticket"
has "$(jq -r '.[].id' <<<"$out")" "$brm" "--offline keeps the merged-branch ticket"

# --line keeps only line:<name>
run 0 "set labels one ticket" wo set --project "$d" --id "$kid" --add-label line:inbox-triage
run 0 "set labels another line" wo set --project "$d" --id "$pro" --add-label line:other
capture js2 wo next --project "$d" --line inbox-triage --json
assert_eq "$kid" "$(jq -r '.[].id' <<<"$js2")" "--line inbox-triage keeps line:inbox-triage only"
assert_eq '["line:inbox-triage"]' "$(jq -c '.[0].labels' <<<"$js2")" "--json carries the label"

# set: idempotent, writes only .labels
git -C "$d" add -A && git -C "$d" commit -qm labeled
cp "$(ff "$kid")" "$WORK/kid350.before"
run 0 "set --add-label twice" wo set --project "$d" --id "$kid" --add-label line:inbox-triage
git -C "$d" diff --quiet && _pass "second set left git diff --quiet" || _fail "second set rewrote the file"
capture txt wo set --project "$d" --id "$kid" --add-label zeta --add-label alpha
assert_eq "LABELED $kid alpha,line:inbox-triage,zeta" "$txt" "text line lists sorted labels"
assert_eq "$(jq -S 'del(.labels)' <<<"$(awk 'NR==1{next}/^---$/{exit}{print}' "$WORK/kid350.before")")" \
  "$(jq -S 'del(.labels)' <<<"$(awk 'NR==1{next}/^---$/{exit}{print}' "$(ff "$kid")")")" "set changed no key but labels (status, updated kept)"
capture js3 wo set --project "$d" --id "$kid" --remove-label zeta --json
assert_eq '[{"id":"'"$kid"'","labels":["alpha","line:inbox-triage"],"changed":true}]' "$js3" "--json row shape"

# set --tree labels descendants and skips archived
run 0 "set --tree" wo set --project "$d" --tree "$epic2" --add-label line:tree
assert_eq '["line:tree"]' "$(wo_labels=$(awk 'NR==1{next}/^---$/{exit}{print}' "$(ff "$epic2")"); jq -c '.labels' <<<"$wo_labels")" "tree root labeled"
grep -q 'line:tree' "$d/work-orders/archive/2026/$(basename "$d/work-orders/archive/2026/${dead}"-*.md)" 2>/dev/null \
  && _fail "archived descendant was labeled" || _pass "archived descendant skipped under --tree"

# new inherits parent labels and --label adds
c2=$(mk "inherits" --parent "$epic2" --label zz.extra)
assert_eq '["line:tree","zz.extra"]' "$(awk 'NR==1{next}/^---$/{exit}{print}' "$(ff "$c2")" | jq -c '.labels')" "new --parent copies labels then adds --label"

# errors
run 2 "bad label exits 2" wo set --project "$d" --id "$kid" --add-label 'Bad Label'
be=$(wo set --project "$d" --id "$kid" --add-label "Bad Label" --json 2>&1)
has "$be" "bad_label" "bad label is named bad_label"
run 2 "set with no label flag exits 2" wo set --project "$d" --id "$kid"
run 3 "set --id on an archived ticket exits 3" wo set --project "$d" --id "$dead" --add-label x
ae=$(wo set --project "$d" --id "$dead" --add-label x --json 2>&1)
has "$ae" "archived" "archived refusal is named archived"

# gh down: next exits 4
printf '#!/usr/bin/env bash\nexit 1\n' >"$stub/gh"
run 4 "gh failing makes next exit 4" wo next --project "$d"
ge=$(wo next --project "$d" --json 2>&1)
has "$ge" "gh_failed" "gh failure is named gh_failed"
finish
