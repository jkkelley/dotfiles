#!/usr/bin/env bash
# name: consume.test.sh
# purpose: dev gate for pr-flow bin/pr-flow-consume.sh - records once per head, ci.failed, merged timing, backstop to merge.sh
# inputs: bin/pr-flow-consume.sh and the scripts beside it; a fake gh and a stub publisher in a mktemp directory
# outputs: ok/FAIL lines and pass= fail=; exit 1 on any failure
# writes-to: a mktemp directory
# cleanup: the mktemp directory is removed on exit
# shellcheck disable=SC2015
set -uo pipefail
PF=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; mkdir -p "$W/bin" "$W/state"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
no() { fail=$((fail + 1)); echo "FAIL $1"; }
eq() { [ "$2" = "$3" ] && ok "$1" || no "$1: got '$2' want '$3'"; }
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\necho "$1 $2" >> "%s/pub.log"\n' "$W" > "$W/bin/pub"; chmod +x "$W/bin/pub"; : > "$W/pub.log"
cat > "$W/cfg.json" <<'CFG'
{"defaults": {"line": "test", "records": "bus", "ticket_re": "(WO-[0-9]{8}-[0-9a-f]{4})", "required_check": "ci-ok", "regen": {"paths": ""},
  "cleanup": {"slots": false}, "backstop_s": 0, "budgets": {"sweep": {"budget_s": 60, "timeout_s": 60}}},
 "repos": {"o/r": {"clone": "/nonexistent"}}}
CFG
cat > "$W/bin/gh" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "$W/calls.log"
JQ=""; a=(); while [ $# -gt 0 ]; do if [ "$1" = --jq ]; then JQ=$2; shift 2; else a+=("$1"); shift; fi; done; set -- "${a[@]}"
out() { if [ -n "$JQ" ]; then jq -r "$JQ" <<<"$1"; else printf '%s\n' "$1"; fi; }
case "$*" in
  "pr list -R o/r --state open"*) out "$(cat "$W/open.json")" ;;
  "pr list -R o/r --state merged"*) out "$(cat "$W/merged.json")" ;;
  "api repos/o/r/commits/"*) s=${2#repos/o/r/commits/}; s=${s%%/*}; out "$(jq -c --arg s "$s" '.[$s] // {check_runs: []}' "$W/checks.json")" ;;
  "pr view "*) out "$(jq -c --arg n "$3" '.[] | select((.number|tostring) == $n) | {headRefOid}' "$W/open.json")" ;;
  *) echo "fake gh: unexpected $*" >&2; exit 9 ;;
esac
FAKE
chmod +x "$W/bin/gh"
# merge.sh is stubbed: the backstop is asserted by its call, merge.sh's own behaviour is merge.test.sh's
mkdir -p "$W/pf/bin"; cp "$PF"/bin/*.sh "$W/pf/bin/"; cp -r "$PF/schemas" "$W/pf/"
printf '#!/usr/bin/env bash\necho "merge.sh $*" >> "%s/merge.log"\n' "$W" > "$W/pf/bin/merge.sh"; chmod +x "$W/pf/bin/merge.sh"
export W GH="$W/bin/gh" PR_FLOW_PUB="$W/bin/pub" PR_FLOW_STATE="$W/state" PR_FLOW_CONFIG="$W/cfg.json" RECORDS_BACKOFF=0 GATE_BACKOFF=0 PR_FLOW_UNTIMED=1
A=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; B=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb; M=cccccccccccccccccccccccccccccccccccccccc
cat > "$W/open.json" <<J
[{"number": 1, "headRefOid": "$A", "title": "feat: a", "body": "WO-20261016-aaaa - a"},
 {"number": 2, "headRefOid": "$B", "title": "fix: b", "body": ""}]
J
cat > "$W/checks.json" <<J
{"$A": {"check_runs": [{"name": "ci-ok", "status": "completed", "conclusion": "success", "completed_at": "2026-10-16T06:00:00Z"}]},
 "$B": {"check_runs": [{"name": "ci-ok", "status": "completed", "conclusion": "failure", "completed_at": "2026-10-16T06:00:00Z"}]},
 "$M": {"check_runs": [{"name": "ci-ok", "status": "completed", "conclusion": "success", "completed_at": "2026-10-16T06:00:00Z"}]}}
J
now=$(date -u +%FT%TZ); last=$(date -u -d '-14 seconds' +%FT%TZ)
jq -n --arg at "$now" --arg m "$M" '[{number: 3, title: "WO-20261016-cccc - c", body: "", mergedAt: $at, mergeCommit: {oid: "dddddddddddddddddddddddddddddddddddddddd"}, headRefOid: $m}]' > "$W/merged.json"
jq --arg l "$last" '.[$ARGS.named.m].check_runs[0].completed_at = $l' --arg m "$M" "$W/checks.json" > "$W/c" && mv "$W/c" "$W/checks.json"
n() { grep -c "^line.test.event.$1 " "$W/pub.log" || true; }

REPO=o/r "$W/pf/bin/pr-flow-consume.sh" sweep > "$W/out1" 2>&1
eq "pr.opened once per open PR" "$(n pr.opened)" 2
eq "ci.passed for the green head" "$(n ci.passed)" 1
eq "ci.failed for the red head (fix work order, N3)" "$(n ci.failed)" 1
grep '^line.test.event.ci.failed ' "$W/pub.log" | cut -d' ' -f2- | jq -e '.pr == 2 and .ticket == "PR-2" and (.note|test("failed: ci-ok"))' >/dev/null && ok "ci.failed names the check" || no "ci.failed record"
eq "merged 200 for the merged PR" "$(n merged)" 1
grep '^line.test.event.merged ' "$W/pub.log" | cut -d' ' -f2- | jq -e '.note|test("ci_to_merge_s 1[0-9]")' >/dev/null && ok "merged note carries seconds from last check to merge (AC2)" || no "merged note: $(grep merged "$W/pub.log")"
[ -s "$W/merge.log" ] && no "backstop on the first green sight" || ok "no backstop on the first green sight"
sleep 1; REPO=o/r "$W/pf/bin/pr-flow-consume.sh" sweep > "$W/out2" 2>&1
eq "second sweep posts nothing new" "$(wc -l < "$W/pub.log" | tr -d ' ')" 5
grep -q -- '--slug o/r --repo /nonexistent --pr 1$' "$W/merge.log" 2>/dev/null && ok "still open past backstop_s: merge.sh --pr 1" || no "backstop: $(cat "$W/merge.log" 2>/dev/null)"
grep -q -- '--pr 2' "$W/merge.log" && no "backstop on a red PR" || ok "never a backstop merge for a red PR"
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
