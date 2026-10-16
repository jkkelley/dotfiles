#!/usr/bin/env bash
# name: a2a-send.sh
# purpose: the one way an agent hands another agent a message: validated, never ack-only, store-named, queued.
# outputs: stdout status code line (A2A-QUEUED, then the delivery pass), stderr refusal code, exit code
# a2a-send.sh - the one way an agent hands another agent a message: validated, never ack-only, named by the artifact
# store, queued, and delivered as one pointer line only when the receiving seat is idle with an empty input line.
#
# usage: a2a-send.sh --to SEAT --file FILE [--line LINE] [--no-deliver]
#   FILE is a draft: a zenith.a2a.brief.v1 or zenith.a2a.result.v1 JSON document. It is copied into the store at a
#   path artifact.sh mints (key a2a, real UTC seconds); the draft's own name never travels.
# exit: 0 queued (prints "A2A-QUEUED <store path>"), 2 usage, 3 refused (A2A-INVALID, A2A-ACK-REFUSED, A2A-AT-FUTURE,
#   A2A-NAME-COLLISION), 4 io.
# inputs: config.json beside this file (A2A_CONFIG), A2A_STATE_DIR, A2A_LINE, ARTIFACT_* (artifact.sh), HERDR_BIN, NATS_BIN.
# writes-to: the artifact store (<root>/a2a/YYYY/MM/), $A2A_STATE/queue/<line>/<seat>/, bus subject a2a.<line>.<seat>.
# cleanup: a2a-deliver.sh moves delivered pointers to delivered/; `make artifact-clean KEY=a2a OLDER_THAN=` prunes the store.
#
# BREADCRUMB - why this exists, brief BR-20261016-a2a-guard (owner 2026-10-16: "YOU SEE THE PROBLEM WHATS THE AUTOMATION
#   TO NOT HAVE IT HAPPEN AGAIN IN A NON DISRUPTIVE WAY?").
# What broke: P1, ack-request orders typed into working panes (sweep-build wD9:p3, stuck-watch wD9:p44) sat queued
#   18-25 min; P3, orchestrator-msg-20261016T0512Z.json was overwritten by a same-minute hand-named file, and order files
#   carried hand-guessed future timestamps.
# Why this fix: the store mints the name (real seconds plus a random tail, and artifact.sh refuses to overwrite), so two
#   sends can never share a file; delivery is gated on herdr's own agent_status, so a busy seat is never typed into.
#   Rejected: herdr agent prompt --wait in the sender, which blocks the sender for as long as the receiver works.
# Cost: a message to a busy seat waits for a2a-deliver's next tick (the line monitor), not for the sender.
set -uo pipefail
# shellcheck source=claude/workflow/a2a-guard/a2a-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/a2a-lib.sh"
WF="$(cd "$A2A_HERE/.." && pwd)"
ARTIFACT_SH="${A2A_ARTIFACT_SH:-$WF/../tools/artifact/artifact.sh}"

to="" file="" line="$A2A_LINE_DEFAULT" deliver=1
while [ $# -gt 0 ]; do
  case $1 in
    --to) to=${2:-}; shift 2 ;; --file) file=${2:-}; shift 2 ;; --line) line=${2:-}; shift 2 ;;
    --no-deliver) deliver=0; shift ;;
    -h|--help) sed -n 2,13p "$0"; exit 0 ;;
    *) a2a_die 2 "A2A-USAGE unknown option $1" ;;
  esac
done
{ [ -n "$to" ] && [ -n "$file" ]; } || a2a_die 2 "A2A-USAGE a2a-send.sh --to SEAT --file FILE [--line LINE]"
[[ $to =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || a2a_die 2 "A2A-USAGE seat '$to' must be a lowercase slug"
[[ $line =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || a2a_die 2 "A2A-USAGE line '$line' must be a lowercase slug"
[ -f "$file" ] || a2a_die 4 "A2A-IO no such file: $file"

# 1. schema, by the document's own schema field. No bespoke validator (item 4): brief.sh and validate-schema.sh exist.
jq -e . "$file" >/dev/null 2>&1 || a2a_die 3 "A2A-INVALID $file is not JSON; agent to agent is schema, never prose"
kind=$(jq -r '.schema // ""' "$file")
case $kind in
  zenith.a2a.brief.v1) bash "$WF/bin/brief.sh" check "$file" >/dev/null 2>&1 || a2a_die 3 "A2A-INVALID $file fails brief.schema.json (make brief-check FILE=$file)" ;;
  zenith.a2a.result.v1) "$WF/tools/validate-schema.sh" "$WF/schemas/result.schema.json" "$file" >/dev/null 2>&1 \
                          || a2a_die 3 "A2A-INVALID $file fails result.schema.json" ;;
  *) a2a_die 3 "A2A-INVALID schema '$kind' is not zenith.a2a.brief.v1 or zenith.a2a.result.v1" ;;
esac

# 2. never an ack. A brief whose every action is an acknowledgement, or any of whose AC asks for one, costs the receiver
#    a turn and proves nothing; the bus already says the seat is alive.
if [ "$kind" = zenith.a2a.brief.v1 ]; then
  ackre=$(jq -r '.ack_patterns | join("|")' "$A2A_CFG")
  n_act=$(jq '.actions | length' "$file")
  n_ack=$(jq -r '.actions[]' "$file" | grep -ciE "$ackre")
  if [ "$n_act" -eq 0 ] || [ "$n_ack" -eq "$n_act" ] \
     || jq -r '.acceptance_criteria[] | .statement, .proof' "$file" | grep -qiE "$ackre"; then
    a2a_die 3 "A2A-ACK-REFUSED $file: an order that is only an acknowledgement, or whose AC asks for one, is never sent"
  fi
fi

# 3. no hand-guessed clocks: a message stamped in the future is refused, not trusted.
at=$(jq -r '.at // ""' "$file")
if [ -n "$at" ]; then
  at_s=$(date -u -d "$at" +%s 2>/dev/null) || a2a_die 3 "A2A-INVALID at '$at' is not a UTC time"
  skew=$(a2a_cfg .future_skew_s)
  [ "$at_s" -le $(( $(date -u +%s) + skew )) ] || a2a_die 3 "A2A-AT-FUTURE at $at is more than ${skew}s ahead of $(a2a_now)"
fi

# 4. the store names it. A random tail makes two sends in one second two names; artifact.sh refuses to overwrite.
key=$(a2a_cfg .artifact_key)
path=""
for _ in 1 2 3; do
  tail=$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')
  path=$(bash "$ARTIFACT_SH" new --key "$key" --name "$to-$tail" --ext json --what "a2a $kind to $to" 2>/dev/null) && break
  path=""
done
[ -n "$path" ] || a2a_die 3 "A2A-NAME-COLLISION the store refused three names for $to; nothing sent"
cp "$file" "$path" || a2a_die 4 "A2A-IO could not write $path"

# 5. queue it (the durable fallback until the bus consumer is stable), then tell the bus.
q=$(a2a_qdir "$line" "$to"); mkdir -p "$q" || a2a_die 4 "A2A-IO could not create $q"
printf '%s\n' "$path" > "$q/$(date -u +%s%N).ptr" || a2a_die 4 "A2A-IO could not queue $path"
if [ "$(a2a_cfg .bus.enabled)" = true ]; then
  subj="$(a2a_cfg .bus.subject_root).$line.$to"
  ev=$(jq -cn --arg at "$(a2a_now)" --arg to "$to" --arg line "$line" --arg p "$path" --arg k "$kind" \
        '{schema:"a2a-guard/event/1",at:$at,line:$line,to:$to,kind:$k,path:$p,status:"A2A-QUEUED"}')
  if [ -n "${NATS_BIN:-}" ]; then "$NATS_BIN" --server "$(a2a_cfg .bus.nats_url)" pub "$subj" "$ev" >/dev/null 2>&1
  else timeout 20 podman run --rm --network=host "$(a2a_cfg .bus.nats_box_image)" \
         nats --server "$(a2a_cfg .bus.nats_url)" pub "$subj" "$ev" >/dev/null 2>&1; fi \
    || printf 'A2A-BUS-DOWN %s not published; the file queue holds it\n' "$subj" >&2
fi
printf 'A2A-QUEUED %s\n' "$path"

# 6. one delivery attempt now; a busy seat keeps it queued for a2a-deliver's monitor tick.
[ $deliver = 1 ] && bash "$A2A_HERE/a2a-deliver.sh" --line "$line" --seat "$to"
exit 0
