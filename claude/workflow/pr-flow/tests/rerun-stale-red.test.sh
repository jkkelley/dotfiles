#!/usr/bin/env bash
# name: rerun-stale-red.test.sh
# purpose: dev gate for the pr-flow-consume.sh rerun-stale-red verb - a red older than the base head is refreshed once per base sha, a newer red is left to the worker
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
printf '#!/usr/bin/env bash\necho "$1 $2" >> "%s/pub.log"\n' "$W" > "$W/bin/pub"; chmod +x "$W/bin/pub"; : > "$W/pub.log"; : > "$W/calls.log"
cfg() { # cfg MODE
  cat > "$W/cfg.json" <<CFG
{"defaults": {"line": "test", "records": "bus", "ticket_re": "(WO-[0-9]{8}-[0-9a-f]{4})", "required_check": "ci-ok", "regen": {"paths": ""},
  "cleanup": {"slots": false}, "backstop_s": 0, "stale_red": {"mode": "$1"}, "budgets": {"sweep": {"budget_s": 60, "timeout_s": 60}}},
 "repos": {"o/r": {"clone": "/nonexistent"}}}
CFG
}
H1=1111111111111111111111111111111111111111
M1=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
M2=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
cat > "$W/bin/gh" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "$W/calls.log"
JQ=""; a=(); while [ $# -gt 0 ]; do if [ "$1" = --jq ]; then JQ=$2; shift 2; else a+=("$1"); shift; fi; done; set -- "${a[@]}"
out() { if [ -n "$JQ" ]; then jq -r "$JQ" <<<"$1"; else printf '%s\n' "$1"; fi; }
case "$*" in
  "pr list -R o/r --state open"*) out "$(cat "$W/open.json")" ;;
  "pr list -R o/r --state merged"*) out '[]' ;;
  "api repos/o/r/commits/main") out "$(cat "$W/main.json")" ;;
  "api repos/o/r/commits/"*"/check-runs"*) out "$(cat "$W/checks.json")" ;;
  "pr update-branch "*) [ ! -e "$W/fail.update-branch" ] ;;
  "api -X PUT repos/o/r/pulls/1/update-branch"*) [ ! -e "$W/fail.put" ] ;;
  "run list "*) out '[{"databaseId": 555}]' ;;
  "run rerun "*) [ ! -e "$W/fail.rerun" ] ;;
  *) echo "fake gh: unexpected $*" >&2; exit 9 ;;
esac
FAKE
chmod +x "$W/bin/gh"
mkdir -p "$W/pf/bin"; cp "$PF"/bin/*.sh "$W/pf/bin/"; cp -r "$PF/schemas" "$W/pf/"
printf '#!/usr/bin/env bash\nexit 0\n' > "$W/pf/bin/gate.sh"; chmod +x "$W/pf/bin/gate.sh"
export W GH="$W/bin/gh" PR_FLOW_PUB="$W/bin/pub" PR_FLOW_STATE="$W/state" PR_FLOW_CONFIG="$W/cfg.json" RECORDS_BACKOFF=0 GATE_BACKOFF=0 PR_FLOW_UNTIMED=1
echo "[{\"number\": 1, \"headRefOid\": \"$H1\", \"title\": \"feat: x\", \"body\": \"WO-20261016-aaaa - x\", \"baseRefName\": \"main\"}]" > "$W/open.json"
main() { echo "{\"sha\": \"$1\", \"commit\": {\"committer\": {\"date\": \"$2\"}}}" > "$W/main.json"; }
red() { echo "{\"check_runs\": [{\"name\": \"claude/workflow\", \"status\": \"completed\", \"conclusion\": \"failure\", \"started_at\": \"$1\", \"completed_at\": \"$1\"}]}" > "$W/checks.json"; }
tick() { REPO=o/r "$W/pf/bin/pr-flow-consume.sh" rerun-stale-red; }
calls() { grep -c -- "$1" "$W/calls.log"; }
recs() { grep -c '^line.test.event.ci.rerun ' "$W/pub.log"; }

# TP-1: red older than main refreshes once, with one RERUN record
cfg update-branch; main $M1 2026-10-16T08:00:00Z; red 2026-10-16T07:00:00Z
tick > "$W/out1" 2>&1
eq "TP-1 one update-branch call" "$(calls 'pr update-branch 1 -R o/r')" 1
eq "TP-1 one RERUN record" "$(recs)" 1
grep '^line.test.event.ci.rerun ' "$W/pub.log" | cut -d' ' -f2- | jq -e '.code == "RERUN" and .pr == 1' >/dev/null && ok "TP-1 code RERUN, pr 1" || no "TP-1 record: $(cat "$W/pub.log")"
"$W/pf/bin/records.sh" seen --key "RERUN/o/r/1/$M1" && ok "TP-1 key RERUN/o/r/1/<main> marked posted" || no "TP-1 key not marked"

# TP-2: same main adds nothing; a new main adds exactly one of each
tick > "$W/out2" 2>&1
eq "TP-2 same main: no second update-branch" "$(calls 'pr update-branch 1 -R o/r')" 1
eq "TP-2 same main: no second record" "$(recs)" 1
main $M2 2026-10-16T09:00:00Z; tick > "$W/out3" 2>&1
eq "TP-2 new main: one more update-branch" "$(calls 'pr update-branch 1 -R o/r')" 2
eq "TP-2 new main: one more record" "$(recs)" 2

# TP-3: a red newer than main is the worker's, never refreshed
: > "$W/calls.log"; : > "$W/pub.log"; rm -rf "$W/state"; mkdir "$W/state"
red 2026-10-16T10:00:00Z; REPO=o/r "$W/pf/bin/pr-flow-consume.sh" sweep > "$W/out4" 2>&1
eq "TP-3 no update-branch" "$(calls 'update-branch')" 0
eq "TP-3 no RERUN record" "$(recs)" 0
eq "TP-3 ci.failed 422 still posted" "$(grep -c '^line.test.event.ci.failed ' "$W/pub.log")" 1

# TP-4: fallbacks
: > "$W/calls.log"; : > "$W/pub.log"; rm -rf "$W/state"; mkdir "$W/state"; red 2026-10-16T07:00:00Z
touch "$W/fail.update-branch"; tick > "$W/out5" 2>&1
eq "TP-4 update-branch refused: REST PUT called" "$(calls 'api -X PUT repos/o/r/pulls/1/update-branch')" 1
eq "TP-4 REST fallback posts RERUN" "$(recs)" 1
: > "$W/calls.log"; : > "$W/pub.log"; rm -rf "$W/state"; mkdir "$W/state"; touch "$W/fail.put"; tick > "$W/out6" 2>&1
grep -q '^o/r PR 1 stale-red-fail: update-branch' "$W/out6" && ok "TP-4 both refused: stale-red-fail" || no "TP-4 stdout: $(cat "$W/out6")"
eq "TP-4 both refused: no RERUN record" "$(recs)" 0
rm -f "$W/fail."*; : > "$W/calls.log"; : > "$W/pub.log"; rm -rf "$W/state"; mkdir "$W/state"; cfg rerun; tick > "$W/out7" 2>&1
eq "TP-4 mode rerun: gh run rerun --failed" "$(calls 'run rerun 555 -R o/r --failed')" 1
eq "TP-4 mode rerun: no update-branch" "$(calls 'update-branch')" 0
eq "TP-4 mode rerun: one RERUN record" "$(recs)" 1
: > "$W/calls.log"; : > "$W/pub.log"; rm -rf "$W/state"; mkdir "$W/state"; cfg off; tick > "$W/out8" 2>&1
eq "TP-4 mode off: no refresh call" "$(grep -c -e update-branch -e 'run rerun' "$W/calls.log")" 0
cfg update-branch; DRY=1 tick > "$W/out9" 2>&1
grep -q '^o/r PR 1 would-rerun: update-branch' "$W/out9" && ok "DRY prints would-rerun" || no "DRY stdout: $(cat "$W/out9")"
eq "DRY posts nothing" "$(recs)" 0
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
