#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq programs are single-quoted on purpose
# deadman.sh - who watches stuck-watch? A separate process, started by a systemd --user timer, never by herdr or a seat.
# name: deadman.sh
# purpose: page the owner when stuck-watch stops heartbeating or the bus is down
# inputs: stuck-watch/config.json, --lines, SW_* env, the LINE stream
# outputs: one log line per line per pass
# writes-to: ntfy, ~/.local/state/zenith/stuck-watch/deadman.log and notified.json
# cleanup: make deadman-uninstall
#
# usage: deadman.sh [--lines "a b"] [--config FILE]     (one pass; the timer runs it every minute)
#   per line: the last line.<line>.heartbeat on the LINE stream older than heartbeat_max_seconds (or none) -> STK-090
#   "stuck-watch dead" at priority high; the bus unreachable -> STK-091 "bus down" at priority high. Deduped per
#   line+code per dedupe_minutes, so a dead watcher pages once per 30 min, not every minute. One log line per pass.
#   per line, before the bus check: GET 127.0.0.1:<port from ~/.bearings/<line>/server.json>/state returns 000 (or no
#   server.json) -> STK-092 "bearings down" at priority high. Any other code is alive (a keyless probe gets 403).
# env (each overrides config.json): SW_CONFIG, SW_LINES (default: config .lines), SW_HB_MAX_S, SW_STATE_DIR,
#   NTFY_TOPIC_VAR (gates pass YPC_NTFY_TEST_TOPIC, item 35), ENV_FILE, SW_JS_GET_CMD, SW_CURL_BIN, SW_DEADMAN_LOG,
#   SW_BEARINGS_DIR.
#
# BREADCRUMB - the deadman reads the heartbeat from the bus, not from a file stuck-watch writes.
# What broke: nothing yet; the rejected alternative. A heartbeat file proves the loop runs but not that its events reach
#   the bus, so a watcher publishing into a dead bus would look healthy and the owner would hear nothing.
# Why this fix: one JetStream last_by_subj read per line; it fails loudly both ways (stale heartbeat, unreachable bus).
#   systemd --user, not herdr: the owner's order was that nothing which can die with the line may watch the line.
# Cost: with the bus down the deadman cannot tell which lines are alive; it pages STK-091 once and stops there.
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
while [ $# -gt 0 ]; do case "$1" in
  --lines) SW_LINES="$2"; shift 2 ;; --config) SW_CONFIG="$2"; shift 2 ;;
  -h|--help) sed -n '11,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; *) echo "deadman: unknown argument $1" >&2; exit 2 ;; esac; done
# shellcheck source=stuck-watch/lib.sh disable=SC1091
. "$HERE/lib.sh"
command -v jq >/dev/null || sw_die "jq is required"
LINES="${SW_LINES:-$(sw_cfg '.lines // [] | join(" ")')}"; MAX="$(sw_val SW_HB_MAX_S heartbeat_max_seconds)"
ROOT="$(sw_val SW_SUBJECT_ROOT subject_root)"; now="$(date -u +%s)"
LOG="${SW_DEADMAN_LOG:-$(sw_state_dir)/deadman.log}"

log() { printf '%s %s\n' "$(sw_now)" "$*" | tee -a "$LOG"; }
page() { # page <line> <code> <title> <message>
  local key="deadman/$1/$2" http
  if sw_due "$key"; then http="$(sw_ntfy "$3" high "$4")" && sw_stamp "$key"; log "$2 line=$1 ntfy=$http"
  else log "$2 line=$1 ntfy=deduped"; fi
}

[ -n "$LINES" ] || { log "OK no lines configured"; exit 0; }
# STK-092 probe runs before the bus loop: a bus outage exits 1 there and must not mask a dead Bearings server.
BDIR="$(sw_expand "$(sw_val SW_BEARINGS_DIR bearings.dir)")"; BPATH="$(sw_cfg '.bearings.probe_path')"; BTMO="$(sw_cfg '.bearings.timeout_s')"
for line in $LINES; do
  f="$BDIR/$line/server.json"; port=""; [ -f "$f" ] && port="$(jq -r '.port // empty' "$f" 2>/dev/null)"
  if [ -z "$port" ]; then http=000
  else http="$("${SW_CURL_BIN:-curl}" -s -o /dev/null -m "$BTMO" -w '%{http_code}' "http://127.0.0.1:$port$BPATH" 2>/dev/null)" || http=000; fi
  [ -n "$http" ] || http=000
  if [ "$http" = 000 ]; then
    page "$line" STK-092 "bearings down" "line $line: Bearings server probe returned 000 (port ${port:-none}). Break glass: make -C claude/workflow bearings-up LINE=$line"
  else log "OK line=$line bearings_http=$http"; fi
done
for line in $LINES; do
  r="$(sw_js_get "$(jq -nc --arg s "$ROOT.$(sw_tok "$line").heartbeat" '{last_by_subj:$s}')")"; rc=$?
  if [ "$rc" = 2 ] || ! jq -e . <<<"$r" >/dev/null 2>&1; then
    page all STK-091 "bus down" "NATS $(sw_val SW_NATS_URL nats_url) unreachable from the deadman; stuck-watch cannot publish. Break glass: bring the bus up."
    exit 1
  fi
  t="$(jq -r '.message.time // empty' <<<"$r")"
  if [ -z "$t" ]; then age=-1; else age=$(( now - $(date -u -d "$t" +%s) )); fi
  if [ "$age" -lt 0 ] || [ "$age" -gt "$MAX" ]; then
    page "$line" STK-090 "stuck-watch dead" "line $line: last heartbeat ${t:-never} (age ${age}s, max ${MAX}s). Break glass: make -C claude/workflow stuck-watch-up LINE=$line"
  else log "OK line=$line heartbeat_age=${age}s"; fi
done
