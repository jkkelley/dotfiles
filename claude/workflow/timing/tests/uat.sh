#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq programs are single-quoted on purpose
# uat.sh <line> - the UAT gate (item 34) for timing: the real bus and the real TIMING KV bucket, a slow node and a hung
# node run through bin/timed-run.sh, node-timing.sh on its own consumer, then make line-timing. Nothing is sent to anyone
# (item 35); bottleneck work orders go to a throwaway work-order project. Log in the artifact store; JSON summary printed.
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"; WF="$HERE/../.."
LINE="${1:-timing-uat}"
U="$(mktemp -d)"; export SW_STATE_DIR="$U/state" TM_WO_PROJECT="$U/wo" TM_CONSUMER="node-timing-uat-$$"
# shellcheck source=timing/lib.sh disable=SC1091
. "$WF/timing/lib.sh"
LSUB="$(sw_tok "$LINE")"; BOX="$(jq -r .nats_box_image "$WF/herdr-bus/config.json")"
nats() { podman run --rm --network=host "$BOX" nats --server "nats://$(sw_cfg .nats_url)" "$@"; }
LOG="$(bash "$WF/../tools/artifact/artifact.sh" new --key log --name "timing-uat-$LSUB" --ext log --what "timing UAT gate, line $LINE" --by timing-uat)"
log() { printf '%s %s\n' "$(sw_now)" "$*" | tee -a "$LOG"; }
cleanup() { nats consumer rm LINE "$TM_CONSUMER" -f >/dev/null 2>&1; nats stream purge "KV_$(tm_cfg .kv_bucket)" --subject "\$KV.$(tm_cfg .kv_bucket).$LSUB.>" -f >/dev/null 2>&1; rm -rf "$U"; }
trap cleanup EXIT
START="$(date -u +%Y-%m-%dT%H:%M:%S)"
# last <subject>: the newest message on it, only when published by this run (a previous run's message never counts)
last() { sw_js_get "$(jq -nc --arg s "$1" '{last_by_subj:$s}')" | jq -r --arg t "$START" 'select((.message.time // "") >= $t) | .message.data // empty' | base64 -d 2>/dev/null; }
declare -A AC=()

log "UAT start line=$LINE consumer=$TM_CONSUMER"
make -s -C "$WF" timing-up >> "$LOG" 2>&1 || { log "FAIL timing-up"; exit 1; }
bash "$WF/bin/timed-run.sh" --node uat-slow --kind make --line "$LINE" --budget 1 -- sleep 3 >> "$LOG" 2>&1
bash "$WF/bin/timed-run.sh" --node uat-hang --kind make --line "$LINE" --timeout 2 --retries 3 -- sleep 30 >> "$LOG" 2>&1; HRC=$?
TO="$(last "line.$LSUB.timing.TIMEOUT")"
WOS="$(grep -rl --include='WO-*.md' 'Bottleneck: uat-hang TIMEOUT' "$TM_WO_PROJECT/work-orders" 2>/dev/null | wc -l)"
[ "$HRC" = 124 ] && [ -n "$TO" ] && [ "$WOS" = 1 ] && AC[AC9]=pass || AC[AC9]=fail
log "AC9 ${AC[AC9]}: hung step exit $HRC after 3 attempts, TIMEOUT on bus: $(jq -c '{node,attempts,timeout_s}' <<<"$TO" 2>/dev/null), work orders: $WOS"

for _ in $(seq 1 80); do bash "$WF/timing/node-timing.sh" --once >> "$LOG" 2>&1; [ -n "$(last "line.$LSUB.timing.SLOW")" ] && break; done
SL="$(last "line.$LSUB.timing.SLOW")"; WOS2="$(grep -rl --include='WO-*.md' 'Bottleneck: uat-slow SLOW' "$TM_WO_PROJECT/work-orders" 2>/dev/null | wc -l)"
[ "$(jq -r .node <<<"$SL" 2>/dev/null)" = uat-slow ] && [ "$WOS2" = 1 ] && AC[AC7]=pass || AC[AC7]=fail
log "AC7 ${AC[AC7]}: SLOW on bus: $(jq -c '{node,duration_s,budget_s}' <<<"$SL" 2>/dev/null), work orders: $WOS2"

REP="$(make -s -C "$WF" line-timing LINE="$LINE" 2>&1)"; echo "$REP" >> "$LOG"; RF="$(sed -n 's/^report: //p' <<<"$REP")"
[ -f "$RF" ] && grep -q '| uat-slow | make |' "$RF" && AC[AC8]=pass || AC[AC8]=fail
log "AC8 ${AC[AC8]}: report $RF"
jq -nc --arg log "$LOG" --arg line "$LINE" --arg r "$RF" --arg a7 "${AC[AC7]}" --arg a8 "${AC[AC8]}" --arg a9 "${AC[AC9]}" \
  '{gate:"uat",line:$line,AC7:$a7,AC8:$a8,AC9:$a9,report:$r,log:$log}' | tee -a "$LOG"
for v in "${AC[@]}"; do [ "$v" = pass ] || exit 1; done
