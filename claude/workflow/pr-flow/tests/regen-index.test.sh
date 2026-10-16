#!/usr/bin/env bash
# name: regen-index.test.sh
# purpose: dev gate for the pr-flow-consume.sh regen-index verb - a REGEN record once per new head, a real conflict posts nothing
# inputs: bin/pr-flow-consume.sh and the scripts beside it; a fake gh, a stub regen-conflicts.sh and a stub publisher in a mktemp directory
# outputs: ok/FAIL lines and pass= fail=; exit 1 on any failure
# writes-to: a mktemp directory
# cleanup: the mktemp directory is removed on exit
# shellcheck disable=SC2015
set -uo pipefail
PF=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; mkdir -p "$W/bin" "$W/state" "$W/clone/.git"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
no() { fail=$((fail + 1)); echo "FAIL $1"; }
eq() { [ "$2" = "$3" ] && ok "$1" || no "$1: got '$2' want '$3'"; }
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\necho "$1 $2" >> "%s/pub.log"\n' "$W" > "$W/bin/pub"; chmod +x "$W/bin/pub"; : > "$W/pub.log"
cat > "$W/cfg.json" <<CFG
{"defaults": {"line": "test", "records": "bus", "ticket_re": "(WO-[0-9]{8}-[0-9a-f]{4})", "required_check": "ci-ok",
  "regen": {"paths": "work-orders/INDEX.md", "cmd": "true"}, "cleanup": {"slots": false}, "backstop_s": 0,
  "budgets": {"sweep": {"budget_s": 60, "timeout_s": 60}}},
 "repos": {"o/r": {"clone": "$W/clone"}}}
CFG
H7=7777777777777777777777777777777777777777
cat > "$W/bin/gh" <<'FAKE'
#!/usr/bin/env bash
case "$*" in
  "pr view 7 -R o/r"*) echo '{"headRefOid": "7777777777777777777777777777777777777777", "title": "feat: x", "body": "WO-20261016-aaaa - x"}' ;;
  *) echo "fake gh: unexpected $*" >&2; exit 9 ;;
esac
FAKE
chmod +x "$W/bin/gh"
mkdir -p "$W/pf/bin"; cp "$PF"/bin/*.sh "$W/pf/bin/"; cp -r "$PF/schemas" "$W/pf/"
printf '#!/usr/bin/env bash\ncat "%s/regen.out"\n' "$W" > "$W/pf/bin/regen-conflicts.sh"; chmod +x "$W/pf/bin/regen-conflicts.sh"
export GH="$W/bin/gh" PR_FLOW_PUB="$W/bin/pub" PR_FLOW_STATE="$W/state" PR_FLOW_CONFIG="$W/cfg.json" RECORDS_BACKOFF=0 PR_FLOW_UNTIMED=1

# TP-1: a regenerated index conflict posts REGEN once per head
echo "PR 7 regenerated: work-orders/INDEX.md" > "$W/regen.out"
REPO=o/r "$W/pf/bin/pr-flow-consume.sh" regen-index > "$W/out1" 2>&1
eq "TP-1 one REGEN record" "$(grep -c '^line.test.event.regen ' "$W/pub.log")" 1
grep '^line.test.event.regen ' "$W/pub.log" | cut -d' ' -f2- | jq -e --arg h "$H7" '.code == "REGEN" and .pr == 7 and .sha == $h' >/dev/null && ok "TP-1 code REGEN, pr 7, head sha" || no "TP-1 record: $(cat "$W/pub.log")"
"$W/pf/bin/records.sh" seen --key "REGEN/o/r/7/$H7" && ok "TP-1 key REGEN/o/r/7/<head> marked posted" || no "TP-1 key not marked"
REPO=o/r "$W/pf/bin/pr-flow-consume.sh" regen-index > "$W/out2" 2>&1
eq "TP-1 second tick on the same head posts nothing" "$(wc -l < "$W/pub.log" | tr -d ' ')" 1

# TP-2: a real conflict posts no regen record and is echoed
: > "$W/pub.log"; echo "PR 8 real-conflict: x.sh" > "$W/regen.out"
REPO=o/r "$W/pf/bin/pr-flow-consume.sh" regen-index > "$W/out3" 2>&1
eq "TP-2 no record for a real conflict" "$(wc -l < "$W/pub.log" | tr -d ' ')" 0
grep -q '^o/r PR 8 real-conflict' "$W/out3" && ok "TP-2 real-conflict echoed with the slug" || no "TP-2 stdout: $(cat "$W/out3")"
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
