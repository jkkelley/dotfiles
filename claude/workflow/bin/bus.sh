#!/usr/bin/env bash
# bus.sh - the line's event bus: one NATS JetStream server in podman, one stream, durable pull consumers.
# name: bus.sh
# purpose: the line event bus - NATS JetStream in podman, stream LINE, durable pull consumers, tail
# inputs: config/line-watch.json (LW_BUS), subcommand args, BUS_NATS
# outputs: status lines, fetched payloads, published events
# writes-to: podman container zenith-nats, JetStream store ~/.local/state/zenith/state/nats
# cleanup: make bus-down (keep store) or make bus-clean (delete store)
#
# usage: bus.sh up | logs | down | status | health | health-loop | clean | pub <subject> <json> | next <consumer> | ack <ack-subject> | pull <consumer>
#   up      start the server (127.0.0.1 only, restart always, health check) and ensure the stream and every consumer
#   down    stop and remove the container; the JetStream store stays
#   status  container state, live health, the stream, every consumer with its pending and unacked counts
#   health  run each configured container's podman healthcheck, print and publish HEALTHY|UNHEALTHY|ABSENT|HEALTHCHECK-NOT-RUN; exit 3 unless all HEALTHY
#   health-loop  health every .health.interval seconds forever (the bus monitor's foreground)
#   clean   down, then delete the store (retention already drops events older than max_age)
#   pub     publish one event
#   next    fetch one message without acking: prints "<ack-subject>\t<payload>", nothing when the queue is empty
#   ack     ack a message fetched by next, after the caller acted on it
#   pull    fetch and ack every waiting message, payload per line (a model consumer reading its queue)
#   tail    print every event as it lands, one line each (the events pane of the monitor tab; reads, never acks)
# env: LW_BUS (config/line-watch.json), BUS_NATS (command that runs the nats CLI; default the pinned nats-box image)
#
# BREADCRUMB - why a bus, why NATS, and why acks are published by hand.
# What broke: line-watch first prompted the architect's pane per event, then wrote jsonl queues with offset files.
#   Owner, 2026-10-16T04:32Z: "drop that shit on a bus we have nats or some open source liteweight tool" (item 26).
# Why this fix: NATS JetStream is one small binary, its image was already local, and a durable pull consumer is exactly
#   "each consumer pulls when ready, nothing lost or read twice". The nats CLI acks only at fetch time, so `next` fetches
#   with --no-ack and `ack` publishes to the $JS.ACK subject built from the delivery's stream, consumer and sequences;
#   the server reads the sequences from that subject (verified 2026-10-16T04:34Z: floor moved, outstanding 0).
#   Rejected: --ack at fetch, which loses an event if the consumer dies before it acts; a client library, which adds
#   a language runtime to a bash toolset.
# Cost: an unacked message comes back after ack_wait, so every consumer action must be safe to repeat.
# Kubernetes path, no AWS (item 25): the same stream and consumers move to the owner's cluster as a NATS StatefulSet
#   deployed by Argo CD from git; only BUS url changes (bus.port here, or NATS_URL), the subjects and consumers do not.
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=bin/workflow-lib.sh disable=SC1091
. "$HERE/workflow-lib.sh"
wf_need jq
CFG="${LW_BUS:-$WF_REPO/config/line-watch.json}"
[ -f "$CFG" ] || wf_die "no bus config at $CFG (set LW_BUS)"
c() { jq -r "$1" "$CFG"; }
NAME="$(c .bus.name)"; STREAM="$(c .bus.stream)"; PORT="$(c .bus.port)"; MPORT="$(c .bus.monitor_port)"
BIND="$(c '.bus.bind // "127.0.0.1"')"
STORE="$(wf_expand "$(c .bus.store)")"
URL="${NATS_URL:-nats://127.0.0.1:$PORT}"

nats_() { # every CLI call through one place; BUS_NATS lets a test put a stub here
  if [ -n "${BUS_NATS:-}" ]; then $BUS_NATS -s "$URL" "$@"
  else podman run --rm --network=host "$(c .bus.box_image)" nats -s "$URL" "$@"; fi
}
retry3() { local _; for _ in 1 2 3; do "$@" && return 0; sleep "${BUS_RETRY_SLEEP:-1}"; done; return 1; }
healthy() { podman exec "$NAME" wget -qO- "http://127.0.0.1:$MPORT/healthz" 2>/dev/null | grep -q '"ok"'; }

ensure() { # the stream and every configured consumer, created only when missing
  nats_ stream info "$STREAM" >/dev/null 2>&1 || nats_ stream add "$STREAM" --subjects "$(c .bus.subjects)" --storage file \
    --retention limits --discard old --max-age "$(c .bus.max_age)" --defaults >/dev/null || return 1
  local con
  for con in $(c '.consumers | keys[]'); do
    local -a f=()
    while read -r code; do f+=(--filter "line.*.event.$code"); done < <(c ".consumers[\"$con\"].codes[]")
    # Drift repair (item 28, idempotent): a consumer whose filters no longer match config is edited in place, keeping
    # its position in the stream; created-only-when-missing left new codes (LW-ORDER) undelivered after a config change.
    local have want
    if have="$(nats_ consumer info "$STREAM" "$con" -j 2>/dev/null | jq -r '(.config.filter_subjects // [.config.filter_subject]) | sort | join(",")')"; then
      want="$(c ".consumers[\"$con\"].codes | map(\"line.*.event.\" + .) | sort | join(\",\")")"
      [ "$have" = "$want" ] || nats_ consumer edit "$STREAM" "$con" "${f[@]}" --force >/dev/null || return 1
      continue
    fi
    nats_ consumer add "$STREAM" "$con" --pull --ack explicit --deliver all --wait "$(c ".consumers[\"$con\"].ack_wait")" \
      "${f[@]}" --defaults >/dev/null || return 1
  done
}

# BREADCRUMB - health_of runs the healthcheck itself; State.Health is never trusted.
# What broke: bus.sh status printed State.Health.Status from `podman inspect`, and that value only moves when podman's
#   transient systemd timer fires `podman healthcheck run`. This WSL host has no such timer (0 timers for the container id),
#   so zenith-nats ran its check once since 04:43Z (interval 30s): a fresh container read "starting" forever and a dead
#   server kept its last "healthy". Evidence: ~/.local/state/zenith/evidence/2026/10/20261016-103641-podman-health-no-timer.txt
# Why this fix: run `podman healthcheck run <name>` ourselves each tick and map the exit code (0 HEALTHY, 1 UNHEALTHY, absent
#   container ABSENT, anything else such as 125 = no healthcheck defined HEALTHCHECK-NOT-RUN), so health reflects reality.
#   Rejected: a systemd --user timer per container - systemd timers are absent on this host, which is the bug itself.
# Cost: one podman exec per container per tick (.health.interval seconds).
health_of() { # $1 container name -> one code on stdout
  podman container exists "$1" >/dev/null 2>&1 || { echo ABSENT; return; }
  podman healthcheck run "$1" >/dev/null 2>&1; case $? in 0) echo HEALTHY ;; 1) echo UNHEALTHY ;; *) echo HEALTHCHECK-NOT-RUN ;; esac
}
health_once() { # print and publish every configured container's code; exit 0 only when all are HEALTHY
  local n code rc=0 at
  for n in $(c '.health.containers // [] | .[]'); do
    code="$(health_of "$n")"; at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "$code $n"
    bash "$HERE/bus.sh" pub "line.${LINE:-system}.health.$n" "$(jq -nc --arg at "$at" --arg n "$n" --arg s "$code" '{at:$at,container:$n,status_code:$s}')" >/dev/null 2>&1 \
      || echo "BUS-PUB-FAILED line.${LINE:-system}.health.$n"
    [ "$code" = HEALTHY ] || rc=3
  done
  return $rc
}

cmd="${1:-status}"; shift || true
case "$cmd" in
  up)
    # BREADCRUMB - bind guard (ORD-0553 R1, owner ruling: "local NATS binds 127.0.0.1 only, never the LAN").
    # What broke: nothing yet; the -p flags below were literal 127.0.0.1, so a config edit could not widen them, but the
    #   bind is now a config value and so could be set to 0.0.0.0. Why this fix: refuse any value but 127.0.0.1 before
    #   podman runs, so a widened config never reaches the network. Rejected: trusting the config. Cost: none.
    [ "$BIND" = 127.0.0.1 ] || { echo "BUS-BIND-REFUSED $BIND" >&2; exit 3; }
    if ! podman container exists "$NAME"; then
      mkdir -p "$STORE"
      podman run -d --name "$NAME" --restart=always -p "$BIND:$PORT:4222" -p "$BIND:$MPORT:8222" -v "$STORE:/data:Z" \
        --health-cmd "wget -qO- http://127.0.0.1:$MPORT/healthz || exit 1" --health-interval 30s \
        "$(c .bus.image)" -js -sd /data -m "$MPORT" >/dev/null || wf_die "podman could not start $NAME"
    elif [ "$(podman inspect -f '{{.State.Running}}' "$NAME")" != true ]; then podman start "$NAME" >/dev/null; fi
    retry3 healthy || wf_die "$NAME did not report healthy; read: podman logs $NAME"
    retry3 ensure || wf_die "could not create stream $STREAM or its consumers"
    echo "bus up: $NAME on $BIND:$PORT, stream $STREAM, store $STORE"
    ;;
  logs) exec podman logs -f --tail 20 "$NAME" ;;   # the bus monitor's foreground: the pane lives as long as the server
  down) podman rm -f "$NAME" >/dev/null 2>&1; echo "bus down: $NAME removed, store kept at $STORE" ;;
  clean)
    podman rm -f "$NAME" >/dev/null 2>&1
    case "$STORE" in "$HOME"/.local/state/*) rm -rf "$STORE"; echo "bus clean: $NAME removed, $STORE deleted" ;;
      *) wf_die "refusing to delete $STORE: not under ~/.local/state" ;; esac
    ;;
  status)
    printf 'container %s: %s\n' "$NAME" "$(st="$(podman inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null)" && echo "$st health=$(health_of "$NAME")" || echo absent)"
    healthy && echo "healthz: ok" || echo "healthz: not ok"
    nats_ stream info "$STREAM" -j 2>/dev/null | jq -r '"stream \(.config.name): subjects \(.config.subjects|join(",")), max_age \(.config.max_age/1e9/86400)d, messages \(.state.messages)"'
    for con in $(c '.consumers | keys[]'); do
      nats_ consumer info "$STREAM" "$con" -j 2>/dev/null | jq -r '"consumer \(.name): filters \(.config.filter_subjects // [.config.filter_subject] | join(",")), pending \(.num_pending), unacked \(.num_ack_pending)"' \
        || echo "consumer $con: missing"
    done
    ;;
  health) health_once; exit $? ;;
  health-loop) while :; do health_once; sleep "$(c '.health.interval // 30')"; done ;;   # a non-zero tick never ends the loop
  pub) [ $# -eq 2 ] || wf_die "usage: bus.sh pub <subject> <json>"; retry3 nats_ pub "$1" "$2" >/dev/null 2>&1 || wf_die "publish to $1 failed after 3 tries" ;;
  next)
    [ $# -eq 1 ] || wf_die "usage: bus.sh next <consumer>"
    out="$(nats_ consumer next "$STREAM" "$1" --no-ack --timeout 3s 2>/dev/null)" || exit 0
    hdr="$(grep -m1 -E '^\[[^]]*\] subj: ' <<<"$out")"; [ -n "$hdr" ] || exit 0
    # "[hh:mm:ss] subj: S / tries: D / cons seq: C / str seq: S / pending: P" -> $JS.ACK.<stream>.<con>.D.S.C.0.P
    ack="$(sed -E 's/.*tries: ([0-9]+) \/ cons seq: ([0-9]+) \/ str seq: ([0-9]+) \/ pending: ([0-9]+).*/\1 \3 \2 \4/' <<<"$hdr" \
      | awk -v s="$STREAM" -v k="$1" '{printf "$JS.ACK.%s.%s.%s.%s.%s.0.%s", s, k, $1, $2, $3, $4}')"
    printf '%s\t%s\n' "$ack" "$(sed -n '/^\[[^]]*\] subj: /,$p' <<<"$out" | sed '1d' | grep -v '^$' | head -1)"
    ;;
  ack) [ $# -eq 1 ] || wf_die "usage: bus.sh ack <ack-subject>"; retry3 nats_ pub "$1" '' >/dev/null 2>&1 || wf_die "ack $1 failed after 3 tries" ;;
  pull)
    [ $# -eq 1 ] || wf_die "usage: bus.sh pull <consumer>"
    while line="$(bash "$HERE/bus.sh" next "$1")" && [ -n "$line" ]; do
      printf '%s\n' "${line#*$'\t'}"; bash "$HERE/bus.sh" ack "${line%%$'\t'*}"
    done
    ;;
  tail) # a core subscription sees every published event without touching any durable consumer
    nats_ sub 'line.>' --raw 2>/dev/null | jq -rc --unbuffered '"\(.at // "-") \(.status_code // .code // "-") \(.seat // .from // "-") \(.subject // .do // "" | tostring | .[0:120])"' ;;
  *) sed -n '4,16p' "$HERE/bus.sh" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
