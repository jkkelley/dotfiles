#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq programs are single-quoted on purpose
# stuck-audit.sh - the morning audit: every node that was stuck, for how long, and where its evidence is. Read only.
# name: stuck-audit.sh
# purpose: list every stuck seat+code of a line with duration and evidence path from the LINE stream
# inputs: --line, --since, --json, the LINE stream
# outputs: a table or JSON on stdout
# writes-to: nothing
# cleanup: none (read only)
#
# usage: stuck-audit.sh --line L [--since YYYY-MM-DDTHH:MM:SSZ] [--json]
#   walks line.<L>.stuck.> on the LINE stream (JetStream next_by_subj, one message at a time) and prints one row per
#   seat+code: first seen, last seen, duration, ticks, last evidence path. --since skips older messages.
# env: SW_CONFIG, SW_JS_GET_CMD (tests), SW_NATS_URL, SW_STREAM.
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LINE=""; SINCE=""; JSON=0
while [ $# -gt 0 ]; do case "$1" in
  --line) LINE="$2"; shift 2 ;; --since) SINCE="$2"; shift 2 ;; --json) JSON=1; shift ;;
  -h|--help) sed -n '11,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; *) echo "stuck-audit: unknown argument $1" >&2; exit 2 ;; esac; done
# shellcheck source=stuck-watch/lib.sh disable=SC1091
. "$HERE/lib.sh"
[ -n "$LINE" ] || sw_die "--line is required"
SUBJ="$(sw_val SW_SUBJECT_ROOT subject_root).$(sw_tok "$LINE").stuck.>"
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
seq=1
while :; do
  r="$(sw_js_get "$(jq -nc --argjson q "$seq" --arg s "$SUBJ" '{seq:$q,next_by_subj:$s}')")"; rc=$?
  [ "$rc" = 2 ] && sw_die "bus unreachable"
  s="$(jq -r '.message.seq // empty' <<<"$r" 2>/dev/null)"; [ -n "$s" ] || break
  sw_b64 "$(jq -r .message.data <<<"$r")" >> "$tmp"; echo >> "$tmp"
  seq=$((s + 1))
done
jq -sc --arg since "$SINCE" '
  map(select(type=="object" and .code and ($since=="" or .at >= $since)))
  | group_by([.seat,.code]) | map({seat:.[0].seat, code:.[0].code, first:(map(.at)|min), last:(map(.at)|max), ticks:length,
      duration_s:(((map(.at)|max)|fromdateiso8601) - ((map(.at)|min)|fromdateiso8601) + 60),
      evidence:([.[] | .evidence_path | select(. != null)] | last)}) | sort_by(.first)' "$tmp" > "$tmp.rows"
if [ "$JSON" = 1 ]; then cat "$tmp.rows"
else
  printf '%-22s %-8s %-20s %-20s %8s %5s %s\n' SEAT CODE FIRST LAST DURATION TICKS EVIDENCE
  jq -r '.[] | [.seat,.code,.first,.last,"\(.duration_s/60|floor)m",.ticks,(.evidence // "-")] | @tsv' "$tmp.rows" \
    | awk -F'\t' '{printf "%-22s %-8s %-20s %-20s %8s %5s %s\n",$1,$2,$3,$4,$5,$6,$7}'
  printf 'line %s: %s stuck node+code pairs\n' "$LINE" "$(jq length "$tmp.rows")"
fi
rm -f "$tmp.rows"
