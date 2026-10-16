#!/usr/bin/env bash
# herdr-bus.sh - herdr agent status changes onto NATS, and the owner-tagged ones back out as herdr toasts. No model calls.
#
# usage: herdr-bus.sh <publish|notify|tick|status> [--config FILE]
#   publish   subscribe to herdr's event stream; on any event, diff the agent snapshot against the last one and publish
#             only the changes to herdr.<workspace>.<tab>.<pane>.<agent>.<status>. A slow reconcile covers events_lost.
#   notify    durable pull consumer: events with owner=true become `herdr notification show`, everything else is acked.
#   tick      one reconcile pass (what publish runs per event); the unit tests drive this.
#   status    config, state age, stream and consumer info.
# env (each overrides config.json): HB_CONFIG, HB_STATE_DIR, NATS_BIN (a nats CLI; default: nats-box through podman),
#   HERDR_BIN, HB_TEST_ONCE=1 (publish/notify do one pass and exit).
#
# BREADCRUMB - the first tick is a silent baseline, and state is kept on disk.
# What broke: nothing yet; this is the rejected alternative. Publishing every agent on start would flood the bus with
#   "changes" that are only the current state, and AC2 (no message on quiet ticks) would fail at every restart.
# Why this fix: the first pass only writes state.json; later passes publish the difference. State on disk means a restart
#   still publishes what changed while the publisher was down. Cost: a brand-new install reports nothing until something moves.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${HB_CONFIG:-$HERE/config.json}"
[ "${2:-}" = "--config" ] && CFG="${3:?--config needs a file}"
die() { printf 'herdr-bus: %s\n' "$*" >&2; exit 1; }
command -v jq >/dev/null || die "jq is required"
[ -f "$CFG" ] || die "no config at $CFG"
cfg() { jq -r "$1" "$CFG"; }
expand() { case "$1" in [~]/*) printf '%s/%s' "$HOME" "${1#[~]/}" ;; *) printf '%s' "$1" ;; esac; }

HERDR="${HERDR_BIN:-herdr}"
STATE_DIR="$(expand "${HB_STATE_DIR:-$(cfg .state_dir)}")"; mkdir -p "$STATE_DIR"
STATE="$STATE_DIR/state.json"
NATS_URL="$(cfg .nats_url)"; STREAM="$(cfg .stream)"; ROOT="$(cfg .subject_root)"; CONSUMER="$(cfg .consumer)"
IMAGE="$(cfg .nats_box_image)"; RECON="$(cfg .reconcile_s)"; OWNER_ST="$(cfg '.owner_statuses')"

# The nats CLI: a real one if NATS_BIN is set, otherwise the pinned nats-box image on the host network.
natscli() {
  if [ -n "${NATS_BIN:-}" ]; then "$NATS_BIN" --server "$NATS_URL" "$@"
  else podman run --rm --network=host "$IMAGE" nats --server "$NATS_URL" "$@"; fi
}
tok() { printf '%s' "${1:-none}" | tr -c 'A-Za-z0-9_\n-' '-' | sed 's/^$/none/'; }

# snapshot -> [{ws,ws_label,tab,tab_label,pane,agent,name,status}] for panes that hold an agent, sorted by pane.
reduce() {
  jq -c '.result.snapshot as $s | [ $s.agents[] | . as $a | {
      ws: .workspace_id, ws_label: ([$s.workspaces[] | select(.workspace_id == $a.workspace_id) | .label][0] // ""),
      tab: .tab_id, tab_label: ([$s.tabs[] | select(.tab_id == $a.tab_id) | .label][0] // ""),
      pane: .pane_id, agent: (.agent // "none"), name: (.name // ""), status: (.agent_status // "unknown") } ] | sort_by(.pane)'
}

# diff <old.json> <new.json> -> one JSON event per line (schema herdr-bus/event/1), nothing when nothing moved.
diff_events() {
  jq -cn --slurpfile o "$1" --slurpfile n "$2" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson own "$OWNER_ST" '
    def ev($a; $st; $prev): { schema: "herdr-bus/event/1", at: $at, workspace: $a.ws, workspace_label: $a.ws_label,
        tab: $a.tab, tab_label: $a.tab_label, pane: $a.pane, agent: $a.agent, name: $a.name, status: $st, prev: $prev,
        owner: ($own | index($st) != null) };
    ($o[0] | map({key: .pane, value: .}) | from_entries) as $old
    | ($n[0] | map({key: .pane, value: .}) | from_entries) as $new
    | ( $n[0][] | select(($old[.pane] // null) == null or $old[.pane].status != .status or $old[.pane].agent != .agent)
        | ev(.; .status; ($old[.pane].status // "none")) ),
      ( $o[0][] | select(($new[.pane] // null) == null) | ev(.; "gone"; .status) )'
}

publish_event() {  # publish_event <event-json>
  local subj
  subj="$ROOT.$(jq -r '[.workspace,.tab,.pane,.agent,.status] | map(gsub("[^A-Za-z0-9_-]"; "-")) | join(".")' <<<"$1")"
  natscli pub "$subj" "$1" >/dev/null 2>"$STATE_DIR/last-pub.err" || { printf 'herdr-bus: publish to %s failed: %s\n' "$subj" "$(cat "$STATE_DIR/last-pub.err")" >&2; return 1; }
  printf '%s pub %s\n' "$(date -u +%H:%M:%SZ)" "$subj"
}

tick() {
  local snap new=$STATE_DIR/new.json ev rc=0
  snap="$("$HERDR" api snapshot)" || die "herdr api snapshot failed"
  printf '%s' "$snap" | reduce >"$new" || die "snapshot did not parse"
  if [ -f "$STATE" ]; then
    # Publish first, replace state only when every event went out, so a failed publish is retried next tick, not lost.
    while IFS= read -r ev; do [ -n "$ev" ] && { publish_event "$ev" || rc=1; }; done < <(diff_events "$STATE" "$new")
    [ "$rc" = 0 ] && mv "$new" "$STATE"
  else
    mv "$new" "$STATE"; printf '%s baseline %s agents\n' "$(date -u +%H:%M:%SZ)" "$(jq length "$STATE")"
  fi
  return "$rc"
}

cmd_publish() {
  command -v python3 >/dev/null || die "python3 is required for the event subscriber"
  local sock="${HERDR_SOCKET_PATH:?HERDR_SOCKET_PATH is not set (run inside herdr)}" line panes
  tick
  [ "${HB_TEST_ONCE:-0}" = 1 ] && return 0
  while :; do
    readarray -t panes < <(jq -r '.[].pane' "$STATE")
    # One subscription per pane list. The subscriber exits on a structural event or events_lost; the read timeout is the
    # slow reconcile that covers anything the stream dropped.
    python3 "$HERE/events.py" "$sock" "${panes[@]}" | while IFS= read -r -t "$RECON" line || [ $? -gt 128 ]; do
      case "$line" in structural*|error*|eof*) tick; break ;; *) tick ;; esac
    done
    tick; sleep 1
  done
}

# notify_one <event-json>: owner events become a toast, the rest are ignored (the caller acks all of them).
notify_one() {
  jq -e '.schema == "herdr-bus/event/1" and .owner == true' <<<"$1" >/dev/null 2>&1 || return 0
  "$HERDR" notification show "$(jq -r '"\(.name | select(. != "") // .agent) is \(.status)"' <<<"$1")" \
    --body "$(jq -r '"\(.workspace_label) / \(.tab_label) / \(.pane)"' <<<"$1")" --sound request >/dev/null
}

cmd_notify() {
  natscli consumer info "$STREAM" "$CONSUMER" >/dev/null 2>&1 || natscli consumer add "$STREAM" "$CONSUMER" --pull \
    --filter "$ROOT.>" --deliver new --ack explicit --replay instant --defaults >/dev/null \
    || die "cannot create consumer $CONSUMER on stream $STREAM (does the stream cover $ROOT.>? line-watch's make bus-up owns it)"
  # BREADCRUMB - one message per pull, 5s wait.
  # What broke: `consumer next --count 10 --wait 30s` blocks until 10 messages or the timeout, so a lone owner event sat
  #   unacked and un-toasted for 30s and a one-shot run overran 60s (measured on nats-box against nats:2.15.1).
  # Why this fix: --count 1 returns the moment a message exists; an empty pull times out after 5s with rc 1 and loops.
  # Cost: one nats-box container start per pull (~0.4s), fine at this event rate.
  local msg
  while :; do
    while IFS= read -r msg; do [ -n "$msg" ] && notify_one "$msg"; done \
      < <(natscli consumer next "$STREAM" "$CONSUMER" --count 1 --wait 5s --raw 2>/dev/null)
    [ "${HB_TEST_ONCE:-0}" = 1 ] && return 0
  done
}

cmd_status() {
  printf 'config   %s\nstate    %s (%s)\n' "$CFG" "$STATE" "$([ -f "$STATE" ] && date -u -r "$STATE" +%Y-%m-%dT%H:%M:%SZ || echo none)"
  [ -f "$STATE" ] && jq -r '.[] | "  \(.pane)\t\(.agent)\t\(.status)\t\(.name)"' "$STATE"
  natscli consumer info "$STREAM" "$CONSUMER" 2>&1 | sed -n '1,25p'
}

case "${1:-}" in
  publish) cmd_publish ;;
  notify) cmd_notify ;;
  tick) tick ;;
  status) cmd_status ;;
  diff) diff_events "$2" "$3" ;;
  *) sed -n '2,12p' "$0"; exit 2 ;;
esac
