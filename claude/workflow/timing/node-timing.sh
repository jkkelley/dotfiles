#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq programs are single-quoted on purpose
# node-timing.sh - start and end events off the bus, durations into the TIMING KV bucket, SLOW and a work order over budget.
# name: node-timing.sh
# purpose: consume start/end events, write durations to KV TIMING, code SLOW and file a work order over budget
# inputs: config/time-budgets.json, the LINE stream, TM_* env
# outputs: status lines on stdout
# writes-to: NATS KV TIMING and line.<line>.timing.SLOW, the bottlenecks work-order project, ~/.local/state/zenith/stuck-watch/node-timing.json
# cleanup: make timing-down
#
# usage: node-timing.sh [--once]      (durable pull consumer "node-timing" on the LINE stream; the monitor pane runs it)
#   timing/event/1 (bin/timed-run.sh): start is remembered, end carries duration_s and budget_s.
#   herdr-bus/event/1: a seat going working is a start, leaving working (idle, done, blocked, gone) is an end, kind seat.
#   each end -> KV TIMING key <line>.<kind>.<node>.<run> = {node,kind,line,start,end,duration_s,budget_s,slow};
#   duration over budget -> line.<line>.timing.SLOW with evidence and one bottleneck work order per node per UTC day.
# env: TM_BUDGETS, TM_CONSUMER (UAT uses its own), NATS_BIN (a nats CLI; default nats-box through podman), SW_PUB_CMD, WO_BIN, SW_STATE_DIR, TM_TEST_ONCE.
#
# BREADCRUMB - KV writes are plain publishes to $KV.TIMING.<key>, no client binary.
# What broke: nothing yet; the rejected alternative. `nats kv put` starts a nats-box container per write (~0.4 s).
# Why this fix: a JetStream KV put is a publish on the bucket's subject, which sw_pub already speaks over /dev/tcp.
#   The bucket itself is created once by `make timing-up` (nats kv add, idempotent). Cost: none beyond the bucket existing.
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=timing/lib.sh disable=SC1091
. "$HERE/lib.sh"
ONCE="${TM_TEST_ONCE:-0}"; [ "${1:-}" = --once ] && ONCE=1
STREAM="$(sw_cfg .stream)"; CONSUMER="${TM_CONSUMER:-$(tm_cfg .consumer)}"; BUCKET="$(tm_cfg .kv_bucket)"
IMAGE="$(jq -r .nats_box_image "$HERE/../herdr-bus/config.json")"; NURL="nats://$(sw_cfg .nats_url)"
STATE="$(sw_state_dir)/node-timing.json"; [ -s "$STATE" ] || echo '{}' > "$STATE"
natscli() { if [ -n "${NATS_BIN:-}" ]; then "$NATS_BIN" --server "$NURL" "$@"; else podman run --rm --network=host "$IMAGE" nats --server "$NURL" "$@"; fi; }

ensure_consumer() {
  natscli consumer info "$STREAM" "$CONSUMER" >/dev/null 2>&1 && return 0
  local args=() f; while IFS= read -r f; do args+=(--filter "$f"); done < <(tm_cfg '.filters[]')
  natscli consumer add "$STREAM" "$CONSUMER" --pull "${args[@]}" --deliver all --ack explicit --replay instant --defaults >/dev/null 2>&1 && return 0
  # the stream may not carry every configured filter (herdr.> lives elsewhere); fall back to the first one, loudly
  echo "WARN consumer with every filter refused; using $(tm_cfg '.filters[0]') only" >&2
  natscli consumer add "$STREAM" "$CONSUMER" --pull --filter "$(tm_cfg '.filters[0]')" --deliver all --ack explicit --replay instant --defaults >/dev/null
}

finish() { # finish <line> <kind> <node> <run> <start-iso> <end-iso> <duration> [budget]
  local b="${8:-}" slow=false key j wo
  [ -n "$b" ] && [ "$b" != null ] || b="$(tm_limit budget_s "$2" "$3")"
  [ "$7" -gt "$b" ] && slow=true
  key="$(sw_tok "$1").$(sw_tok "$2").$(sw_tok "$3").$(sw_tok "$4")"
  j="$(jq -nc --arg l "$1" --arg k "$2" --arg n "$3" --arg r "$4" --arg s "$5" --arg e "$6" --argjson d "$7" --argjson b "$b" --argjson sl "$slow" \
    '{line:$l,kind:$k,node:$n,run_id:$r,start:$s,end:$e,duration_s:$d,budget_s:$b,slow:$sl}')"
  sw_pub "\$KV.$BUCKET.$key" "$j" || echo "WARN bus unreachable, KV $key not written" >&2
  printf '%s %s %s %ss/%ss\n' "$(date -u +%H:%M:%SZ)" "$([ "$slow" = true ] && echo SLOW || echo ok)" "$3" "$7" "$b"
  if [ "$slow" = true ]; then
    tm_code "$1" SLOW "$j"
    wo="$(tm_wo "$3" SLOW "$j")" && echo "  work order: $wo"
  fi
}

one() { # one <event-json>
  local m="$1" sch l n k r p at s d
  sch="$(jq -r '.schema // empty' <<<"$m" 2>/dev/null)" || return 0
  case "$sch" in
    timing/event/1)
      l="$(jq -r .line <<<"$m")"; n="$(jq -r .node <<<"$m")"; k="$(jq -r .kind <<<"$m")"; r="$(jq -r .run_id <<<"$m")"; p="$(jq -r .phase <<<"$m")"; at="$(jq -r .at <<<"$m")"
      if [ "$p" = start ]; then jq --arg r "$r" --arg a "$at" '.[$r]=$a' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
      elif [ "$p" = end ]; then
        s="$(jq -r --arg r "$r" '.[$r] // empty' "$STATE")"; d="$(jq -r '.duration_s // empty' <<<"$m")"
        [ -n "$d" ] || d=$(( $(date -u -d "$at" +%s) - $(date -u -d "${s:-$at}" +%s) ))
        finish "$l" "$k" "$n" "$r" "${s:-unknown}" "$at" "$d" "$(jq -r '.budget_s // empty' <<<"$m")"
        jq --arg r "$r" 'del(.[$r])' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
      fi ;;
    herdr-bus/event/1)
      n="$(jq -r '(.name | select(. != "")) // .pane' <<<"$m")"; l="$(jq -r '.tab_label | sub(" [0-9]+$"; "")' <<<"$m")"; at="$(jq -r .at <<<"$m")"
      r="seat:$(jq -r .pane <<<"$m")"
      if [ "$(jq -r .status <<<"$m")" = working ]; then jq --arg r "$r" --arg a "$at" '.[$r]=$a' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
      elif [ "$(jq -r .prev <<<"$m")" = working ]; then
        s="$(jq -r --arg r "$r" '.[$r] // empty' "$STATE")"; [ -n "$s" ] || return 0
        finish "$l" seat "$n" "$(date -u -d "$s" +%Y%m%dT%H%M%SZ)" "$s" "$at" $(( $(date -u -d "$at" +%s) - $(date -u -d "$s" +%s) ))
        jq --arg r "$r" 'del(.[$r])' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
      fi ;;
  esac
}

ensure_consumer || sw_die "cannot create consumer $CONSUMER on stream $STREAM"
while :; do
  while IFS= read -r msg; do [ -n "$msg" ] && one "$msg"; done < <(natscli consumer next "$STREAM" "$CONSUMER" --count 1 --wait 5s --raw 2>/dev/null)
  [ "$ONCE" = 1 ] && exit 0
done
