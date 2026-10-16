# name: lib-merge.sh
# purpose: shared fixture for the pr-flow merge tests - a fake gh, a stub publisher, a clone with a bare origin
# inputs: sourced by tests/merge*.test.sh; PR_FLOW_DIR set by the caller
# outputs: functions fixture_up, pr_set, run_merge, ok, no, eq, done_tests
# writes-to: a mktemp directory
# cleanup: the mktemp directory is removed on exit by the caller's trap
# shellcheck shell=bash disable=SC2015,SC2034 # H1, OUT and RC are read by the sourcing test
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p "$W/bin" "$W/gh" "$W/state"
export PATH="$W/bin:$PATH" GH_FAKE_DIR="$W/gh" PR_FLOW_STATE="$W/state" PR_FLOW_PUB="$W/bin/pub" PR_FLOW_LINE=test \
  MERGE_BACKOFF_SECONDS=0 GATE_BACKOFF=0 RECORDS_BACKOFF=0 PR_FLOW_SLOTS=0 GH_REPO=o/r
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
no() { fail=$((fail + 1)); echo "FAIL $1"; }
eq() { [ "$2" = "$3" ] && ok "$1" || no "$1: got '$2' want '$3'"; }
done_tests() { echo "pass=$pass fail=$fail"; [ "$fail" = 0 ]; }
# shellcheck disable=SC2016 # expanded by the stub when it runs
printf '#!/usr/bin/env bash\necho "$1 $2" >> "%s/pub.log"\n' "$W" > "$W/bin/pub"; chmod +x "$W/bin/pub"; : > "$W/pub.log"
# The fake gh. State per PR in $D/pr-N.json: {state,title,body,headRefOid,headRefName,mergeable,checks,merge:"ok|refuse|conflict|merged-elsewhere"}.
cat > "$W/bin/gh" <<'FAKE'
#!/usr/bin/env bash
D=$GH_FAKE_DIR; echo "$*" >> "$D/calls.log"
JQ=""; a=(); while [ $# -gt 0 ]; do if [ "$1" = --jq ]; then JQ=$2; shift 2; else a+=("$1"); shift; fi; done; set -- "${a[@]}"
if [ -n "$JQ" ]; then out=$(GH_FAKE_NOJQ=1 "$0" "$@") || exit $?; jq -r "$JQ" <<<"$out"; exit $?; fi
[ ! -e "$D/fail-all" ] || { echo "gh: HTTP 502" >&2; exit 1; }
set_f() { jq "$1" "$D/pr-$2.json" > "$D/t" && mv "$D/t" "$D/pr-$2.json"; }
case "$1 $2" in
  "pr view") n=$3; f="$D/pr-$n.json"; shift 3; fields=""; while [ $# -gt 0 ]; do [ "$1" = --json ] && fields=$2; shift; done
    jq -c --arg f "$fields" '. as $p | ($f | split(",")) as $k
      | reduce $k[] as $x ({}; . + {($x): (if $x == "mergeCommit" then {oid: $p.mergeSha} else $p[$x] end)})' "$f" ;;
  "pr merge") n=$3; m=$(jq -r '.merge // "ok"' "$D/pr-$n.json")
    case $m in
      ok) set_f ".state = \"MERGED\" | .mergeSha = \"$(printf 'e%.0s' {1..38}; printf '%02d' "$n")\"" "$n" ;;
      conflict) set_f '.mergeable = "CONFLICTING"' "$n"; echo "not mergeable" >&2; exit 1 ;;
      moved) set_f '.headRefOid = "ffffffffffffffffffffffffffffffffffffffff"' "$n"; echo "head moved" >&2; exit 1 ;;
      merged-elsewhere) set_f '.state = "MERGED" | .mergeSha = "'"$(printf 'f%.0s' {1..40})"'"' "$n"; echo "already" >&2; exit 1 ;;
    esac ;;
  "pr list") jq -s '[.[] | select(.state == "OPEN") | {number}]' "$D"/pr-*.json ;;
  "api repos/o/r/commits/"*) sha=${2#repos/o/r/commits/}; sha=${sha%%/*}
    jq -c --arg s "$sha" 'select(.headRefOid == $s) | {check_runs: [.checks[] | {name: .n, status: .s, conclusion: (if .c == "" then null else .c end)}]}' "$D"/pr-*.json | head -1 ;;
  "repo view") echo o/r ;;
  *) echo "fake gh: unexpected $*" >&2; exit 9 ;;
esac
FAKE
chmod +x "$W/bin/gh"
GREEN='[{"n":"ci-ok","s":"completed","c":"success"}]'
# BREADCRUMB 2026-10-16 - WO-20261016-0233. hd used to mint aaaa...NN heads that are not commits in the clone, so gate.sh ticket-open could
#   not resolve them: its fetch failed, exit 4, merge.sh routed that to fail_io and merge.test.sh ran pass=13 fail=14 (evidence:
#   inbox-triage/20261015/seats/ticket-open.result.json). A head is now the real commit of feat/tN on origin, minted once and reused, so it
#   stays one distinct, stable 40-hex per PR. merge.sh still does not pass an unresolvable head: a gate that passes what it cannot read
#   merges an open ticket. Cost: the first hd N for an N with no branch pushes an empty commit to the fixture origin.
hd() {
  if git -C "$W/clone" ls-remote --exit-code --heads origin "feat/t$1" >/dev/null 2>&1; then
    git -C "$W/clone" ls-remote origin "refs/heads/feat/t$1" | cut -f1
  else
    git -C "$W/clone" switch -qc "feat/t$1" origin/main && git -C "$W/clone" commit -q --allow-empty -m "t$1" \
      && git -C "$W/clone" push -q origin "feat/t$1"; git -C "$W/clone" switch -q main
    git -C "$W/clone" rev-parse "feat/t$1"
  fi
}
# pr_set N JSON-overrides: a green, mergeable, open PR with a ticket title, overridden by the jq object given
pr_set() { jq -n --argjson n "$1" --arg h "$(hd "$1")" --argjson c "$GREEN" --argjson o "${2:-{\}}" \
  '{number: $n, state: "OPEN", title: "feat: thing", body: "WO-20261016-aaaa - thing", headRefOid: $h, headRefName: "feat/t\($n)",
    mergeable: "MERGEABLE", checks: $c} + $o' > "$W/gh/pr-$1.json"; }
# fixture_up: a clone at $W/clone whose origin is a bare repo holding main and feat/t7
fixture_up() {
  git init -q --bare -b main "$W/origin.git"; git clone -q "$W/origin.git" "$W/clone" 2>/dev/null
  git -C "$W/clone" config user.email t@example.invalid; git -C "$W/clone" config user.name t
  echo a > "$W/clone/a"; git -C "$W/clone" add a; git -C "$W/clone" commit -qm a; git -C "$W/clone" push -q origin main
  git -C "$W/clone" switch -qc feat/t7; echo b > "$W/clone/b"; git -C "$W/clone" add b; git -C "$W/clone" commit -qm b
  git -C "$W/clone" push -q origin feat/t7; git -C "$W/clone" switch -q main; git -C "$W/clone" remote set-head origin main
  H1=$(hd 7)   # feat/t7 now exists on origin; hd reads it, so H1 is set here and not at source time, when there is no clone
}
run_merge() { OUT=$("$PR_FLOW_DIR/bin/merge.sh" --repo "$W/clone" --slug o/r "$@" 2>"$W/err"); RC=$?; }
pubs() { grep -c "^line.test.event.$1 " "$W/pub.log" || true; }
