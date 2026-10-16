#!/usr/bin/env bash
# name: test_merge_train.sh
# purpose: dev gate for tools/merge-train - leaves-first order over a stack, drafts and orphans skipped, merge.sh per PR
# inputs: merge-train.sh; a stub gh and a stub merge.sh in a mktemp directory
# outputs: ok/FAIL lines and pass= fail=; exit 1 on any failure
# writes-to: a mktemp directory
# cleanup: the mktemp directory is removed on exit
# shellcheck disable=SC2015
set -uo pipefail
MT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)/merge-train.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
no() { fail=$((fail + 1)); echo "FAIL $1"; }
eq() { [ "$2" = "$3" ] && ok "$1" || no "$1: got '$2' want '$3'"; }
# a stack: 10 on main <- 11 <- 12, and 13 on main, 14 a draft on main, 15 on a branch nobody owns
cat > "$W/prs.json" <<'J'
[{"number":12,"headRefName":"c","baseRefName":"b","isDraft":false},{"number":10,"headRefName":"a","baseRefName":"main","isDraft":false},
 {"number":11,"headRefName":"b","baseRefName":"a","isDraft":false},{"number":13,"headRefName":"d","baseRefName":"main","isDraft":false},
 {"number":14,"headRefName":"e","baseRefName":"main","isDraft":true},{"number":15,"headRefName":"f","baseRefName":"gone","isDraft":false}]
J
cat > "$W/gh" <<'S'
#!/usr/bin/env bash
case "$1 $2" in "pr list") cat "$W/prs.json" ;; "repo view") echo main ;; *) exit 9 ;; esac
S
cat > "$W/merge.sh" <<'S'
#!/usr/bin/env bash
n=""; while [ $# -gt 0 ]; do [ "$1" = --pr ] && n=$2; shift; done; echo "$n" >> "$W/order"
o=merged; [ "$n" = 13 ] && o=held; [ "$n" = 13 ] && { jq -nc --argjson p "$n" '{pr:$p,outcome:"held",detail:"pending"}'; exit 3; }
jq -nc --argjson p "$n" --arg o "$o" '{pr:$p,outcome:$o,detail:""}'
S
chmod +x "$W/gh" "$W/merge.sh"; export W GH="$W/gh" MERGE_SH="$W/merge.sh"
out=$("$MT" --repo o/r --result "$W/res.json")
eq "leaves first: 12, 11, 10, then 13" "$(tr '\n' ' ' < "$W/order")" "12 11 10 13 "
eq "merged list" "$(jq -c .merged <<<"$out")" "[12,11,10]"
jq -e '.results[] | select(.pr == 14 and .detail == "draft")' <<<"$out" >/dev/null && ok "draft skipped" || no "draft"
jq -e '.results[] | select(.pr == 15 and (.detail|test("orphan-base gone")))' <<<"$out" >/dev/null && ok "orphan base skipped" || no "orphan"
cmp -s <(printf '%s\n' "$out") "$W/res.json" && ok "--result holds the summary" || no "result file"
rm -f "$W/order"; out=$("$MT" --repo o/r --dry)
[ ! -e "$W/order" ] && ok "--dry calls merge.sh for nothing" || no "dry called merge.sh"
eq "--dry lists the order" "$(jq -c '[.results[] | select(.outcome == "would-run") | .pr]' <<<"$out")" "[12,11,10,13]"
"$MT" --repo o/r --dry --method squash >/dev/null 2>&1; eq "a retired flag is ignored, not fatal" "$?" 0
"$MT" --dry >/dev/null 2>&1; eq "no --repo: exit 2" "$?" 2
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
