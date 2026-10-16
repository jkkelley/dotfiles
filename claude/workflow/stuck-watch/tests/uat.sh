#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq programs are single-quoted on purpose
# uat.sh <line> - the UAT gate (item 34) for stuck-watch: the real bus, real herdr, real gh, a scripted test seat left
# name: uat.sh
# purpose: UAT gate: real bus, a haiku test seat, the test ntfy topic read back, owner topic proven empty
# inputs: line (default stuck-uat), YPC_NTFY_TEST_TOPIC in ENV_FILE
# outputs: log lines and one JSON summary
# writes-to: herdr tab <line> 1, NATS, the test topic, systemd deadman timer, artifact store log/
# cleanup: automatic (trap): deadman removed, seat and tab closed
# idle, the TEST ntfy topic read back by script (item 35). Nothing reaches the owner: every call passes
# NTFY_TOPIC_VAR=YPC_NTFY_TEST_TOPIC, and the last step polls the owner topic to prove it stayed empty (AC6).
# Prints one JSON summary; the full log is written to the artifact store (item 23) and its path printed.
#
#   1 line-up <line> (no architect agent), seat-up uat-idle: a haiku seat that answers once and then sits idle
#   2 AC1 stuck-watch ticks until STK-001 is on the bus and on the test topic, within 2 minutes of the seat going idle
#   3 AC4 one more tick: a second bus message, still one notification
#   4 AC3 a result file claiming done with an open PR: STK-005 on the bus, gh state as evidence
#   5 AC2 the watcher stops (no heartbeat); the deadman timer, installed on the test topic, pages "stuck-watch dead"
#   6 AC6 the owner topic has no message since start; cleanup: deadman removed, test seat and tab closed
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"; SW="$HERE/.."; WF="$SW/.."
LINE="${1:-stuck-uat}"
export NTFY_TOPIC_VAR=YPC_NTFY_TEST_TOPIC SW_IDLE_S="${SW_IDLE_S:-60}"
U="$(mktemp -d)"; export SW_STATE_DIR="$U/state" SW_RUN_DIR="$U/run"; mkdir -p "$SW_RUN_DIR"
# shellcheck source=stuck-watch/lib.sh disable=SC1091
. "$SW/lib.sh"
START="$(date -u +%s)"; LSUB="$(sw_tok "$LINE")"
LOG="$(bash "$WF/../tools/artifact/artifact.sh" new --key log --name "stuck-watch-uat-$LSUB" --ext log --what "stuck-watch UAT gate, line $LINE" --by stuck-watch-uat)"
log() { printf '%s %s\n' "$(sw_now)" "$*" | tee -a "$LOG"; }
declare -A AC=()
cleanup() {
  make -s -C "$WF" deadman-uninstall >/dev/null 2>&1
  make -s -C "$WF" seat-down SEAT=uat-idle LINE="$LINE" FORCE=1 >/dev/null 2>&1
  for t in $(herdr tab list | jq -r --arg l "$LINE " '.result.tabs[] | select((.label // "") | startswith($l)) | .tab_id'); do herdr tab close "$t" >/dev/null 2>&1; done
  rm -rf "$U"
}
trap cleanup EXIT
bus_count() { # bus_count <subject>: messages on the stream for that subject since START (seq walk)
  local n=0 q=1 r s t
  while :; do r="$(sw_js_get "$(jq -nc --argjson q "$q" --arg s "$1" '{seq:$q,next_by_subj:$s}')")" || break
    s="$(jq -r '.message.seq // empty' <<<"$r")"; [ -n "$s" ] || break
    t="$(jq -r .message.time <<<"$r")"; [ "$(date -u -d "$t" +%s)" -ge "$START" ] && n=$((n + 1)); q=$((s + 1)); done
  printf '%s' "$n"
}
topic_titles() { sw_ntfy_poll "$START" | jq -r '.title // ""'; }
tick() { bash "$SW/stuck-watch.sh" --line "$LINE" --once >> "$LOG" 2>&1; }

log "UAT start line=$LINE topic_var=$NTFY_TOPIC_VAR"
ARCH_CMD="echo uat line, no architect agent" make -s -C "$WF" line-up LINE="$LINE" >> "$LOG" 2>&1 || { log "FAIL line-up"; exit 1; }
make -s -C "$WF" seat-up LINE="$LINE" SEAT=uat-idle CMD="claude --model haiku 'Reply with the single word OK and nothing else.'" >> "$LOG" 2>&1 \
  || { log "FAIL seat-up"; exit 1; }
IDLE_AT="$(date -u +%s)"; log "test seat up, idle from $IDLE_AT"

# AC1: within 2 minutes of the seat going idle, STK-001 on the bus and on the (test) phone
until [ "$(topic_titles | grep -c "^STK-001 uat-idle")" -ge 1 ] || [ $(( $(date -u +%s) - IDLE_AT )) -gt 120 ]; do tick; sleep 20; done
T1=$(( $(date -u +%s) - IDLE_AT )); B1="$(bus_count "line.$LSUB.stuck.STK-001")"; N1="$(topic_titles | grep -c "^STK-001 uat-idle")"
[ "$B1" -ge 1 ] && [ "$N1" = 1 ] && [ "$T1" -le 120 ] && AC[AC1]=pass || AC[AC1]=fail
log "AC1 ${AC[AC1]}: bus STK-001=$B1, test topic STK-001=$N1, ${T1}s after idle"

# AC4: the same condition again -> another bus message, still one notification
tick; B2="$(bus_count "line.$LSUB.stuck.STK-001")"; N2="$(topic_titles | grep -c "^STK-001 uat-idle")"
[ "$B2" -gt "$B1" ] && [ "$N2" = 1 ] && AC[AC4]=pass || AC[AC4]=fail
log "AC4 ${AC[AC4]}: bus STK-001 $B1 -> $B2, notifications $N2"

# AC3: a done claim with a PR that is not merged
PR="$(gh pr list --repo jkkelley/dotfiles --state open --limit 1 --json url -q '.[0].url' 2>/dev/null)"
[ -n "$PR" ] || PR="$(gh pr list --repo jkkelley/dotfiles --state closed --limit 20 --json url,mergedAt -q 'map(select(.mergedAt==null))[0].url')"
jq -n --arg p "$PR" '{schema:"zenith.a2a.result.v1",status:"done",status_code:"A2A-002",facts:{pr:$p}}' > "$SW_RUN_DIR/uat-idle-result.json"
tick; B3="$(bus_count "line.$LSUB.stuck.STK-005")"
[ "$B3" -ge 1 ] && AC[AC3]=pass || AC[AC3]=fail
log "AC3 ${AC[AC3]}: done claim on $PR -> bus STK-005=$B3"

# AC2: the watcher is now stopped (no more ticks); the deadman timer on the test topic must page within 4 minutes
LAST_HB="$(date -u +%s)"
N="$HOME/.local/state/zenith/stuck-watch/notified.json"; [ -s "$N" ] && jq --arg p "deadman/$LSUB/" 'with_entries(select(.key | startswith($p) | not))' "$N" > "$N.tmp" && mv "$N.tmp" "$N"
make -s -C "$WF" deadman-install LINES="$LINE" NTFY_TOPIC_VAR=YPC_NTFY_TEST_TOPIC >> "$LOG" 2>&1
until topic_titles | grep -q '^stuck-watch dead' || [ $(( $(date -u +%s) - LAST_HB )) -gt 300 ]; do sleep 15; done
T2=$(( $(date -u +%s) - LAST_HB ))
topic_titles | grep -q '^stuck-watch dead' && [ "$T2" -le 240 ] && AC[AC2]=pass || AC[AC2]=fail
log "AC2 ${AC[AC2]}: 'stuck-watch dead' on the test topic ${T2}s after the last heartbeat; deadman log: $(grep -c "line=$LINE" "$HOME/.local/state/zenith/stuck-watch/deadman.log" 2>/dev/null) lines"
grep "line=$LINE" "$HOME/.local/state/zenith/stuck-watch/deadman.log" 2>/dev/null | tail -3 >> "$LOG"

# AC6: no test run published to the owner topic
# a failed poll must fail AC6, never read as "zero messages"
if OWNJ="$(NTFY_TOPIC_VAR=YPC_NTFY_TOPIC sw_ntfy_poll "$START")"; then
  OWN="$(jq -r '.title // ""' <<<"$OWNJ" | grep -cE '^(STK-|A2A-|stuck-watch dead|bus down)')"; else OWN=poll-failed; fi
[ "$OWN" = 0 ] && AC[AC6]=pass || AC[AC6]=fail
log "AC6 ${AC[AC6]}: owner topic stuck-watch messages since start: $OWN"

jq -nc --arg log "$LOG" --arg line "$LINE" --arg a1 "${AC[AC1]}" --arg a2 "${AC[AC2]}" --arg a3 "${AC[AC3]}" --arg a4 "${AC[AC4]}" --arg a6 "${AC[AC6]}" \
  '{gate:"uat",line:$line,AC1:$a1,AC2:$a2,AC3:$a3,AC4:$a4,AC6:$a6,log:$log}' | tee -a "$LOG"
for v in "${AC[@]}"; do [ "$v" = pass ] || exit 1; done
