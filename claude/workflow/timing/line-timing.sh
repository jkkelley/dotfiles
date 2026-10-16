#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq programs are single-quoted on purpose
# line-timing.sh - where did the line's time go: durations against budgets and the top 5 bottlenecks. Read only.
# name: line-timing.sh
# purpose: report durations against budgets and the top 5 bottlenecks of a line
# inputs: --line, --since, KV TIMING
# outputs: the report on stdout and its path
# writes-to: artifact store report/
# cleanup: artifact.sh clean --key report
#
# usage: line-timing.sh --line L [--since YYYY-MM-DDTHH:MM:SSZ]
#   walks the TIMING KV bucket (stream KV_TIMING, keys <line>.>) with JetStream next_by_subj, writes a Markdown report to
#   the artifact store (key report, item 23), prints it and its path. The morning audit (make morning-audit) runs it.
# env: TM_BUDGETS, SW_JS_GET_CMD (tests), ARTIFACT_ROOT.
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=timing/lib.sh disable=SC1091
. "$HERE/lib.sh"
LINE=""; SINCE=""
while [ $# -gt 0 ]; do case "$1" in --line) LINE="$2"; shift 2 ;; --since) SINCE="$2"; shift 2 ;;
  -h|--help) sed -n '11,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; *) echo "line-timing: unknown argument $1" >&2; exit 2 ;; esac; done
[ -n "$LINE" ] || sw_die "--line is required"
SW_STREAM="KV_$(tm_cfg .kv_bucket)"; export SW_STREAM
SUBJ="\$KV.$(tm_cfg .kv_bucket).$(sw_tok "$LINE").>"
tmp="$(mktemp)"; trap 'rm -f "$tmp" "$tmp.md"' EXIT; seq=1
while :; do
  r="$(sw_js_get "$(jq -nc --argjson q "$seq" --arg s "$SUBJ" '{seq:$q,next_by_subj:$s}')")"; [ $? = 2 ] && sw_die "bus unreachable"
  s="$(jq -r '.message.seq // empty' <<<"$r" 2>/dev/null)"; [ -n "$s" ] || break
  sw_b64 "$(jq -r .message.data <<<"$r")" >> "$tmp"; echo >> "$tmp"; seq=$((s + 1))
done
jq -sr --arg l "$LINE" --arg since "$SINCE" --arg at "$(sw_now)" '
  map(select(type=="object" and .duration_s != null and ($since=="" or (.end // "") >= $since)))
  | (group_by([.kind,.node]) | map({kind:.[0].kind, node:.[0].node, runs:length, budget_s:(map(.budget_s)|max),
      max_s:(map(.duration_s)|max), avg_s:((map(.duration_s)|add)/length|floor), slow:(map(select(.slow))|length),
      overrun_s:(map([.duration_s - .budget_s, 0]|max)|add)})) as $rows
  | "# Line timing: \($l)\n\nGenerated \($at)\(if $since != "" then ", since \($since)" else "" end). \(length) runs, \($rows|length) nodes.\n\n"
  + "## Top 5 bottlenecks\n\n| Node | Kind | Runs | Slow | Overrun s | Max s | Budget s |\n| --- | --- | --- | --- | --- | --- | --- |\n"
  + ([$rows | sort_by(-.overrun_s, -.max_s) | .[:5][] | "| \(.node) | \(.kind) | \(.runs) | \(.slow) | \(.overrun_s) | \(.max_s) | \(.budget_s) |"] | join("\n"))
  + "\n\n## Durations against budgets\n\n| Node | Kind | Runs | Avg s | Max s | Budget s | Slow |\n| --- | --- | --- | --- | --- | --- | --- |\n"
  + ([$rows | sort_by(.kind, .node) | .[] | "| \(.node) | \(.kind) | \(.runs) | \(.avg_s) | \(.max_s) | \(.budget_s) | \(.slow) |"] | join("\n")) + "\n"' "$tmp" > "$tmp.md"
art="$HERE/../../tools/artifact/artifact.sh"
f="$(bash "$art" new --key report --name "line-timing-$(sw_tok "$LINE" | cut -c1-24)" --ext md --what "line timing report for $LINE" --by line-timing)" \
  || sw_die "artifact store refused the report"
cat "$tmp.md" >> "$f"; cat "$tmp.md"; echo "report: $f"
