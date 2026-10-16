#!/usr/bin/env bash
# seat-resources.sh - what each claude seat costs the machine: CPU percent, RSS, process and container count.
#
# usage: seat-resources.sh [--line L] [--json] [--publish] [--loop] [--rss-mb N] [--cpu-pct N] [--floor-mb N] [--sample S]
#   default      table to stdout, one row per seat pane, then the machine line
#   --line L     only seats in tabs labelled "L N" (herdr tab label prefix)
#   --publish    also publish res.<line>.<seat> and res.machine to NATS (core protocol over /dev/tcp, no client binary)
#   --loop       repeat every interval_seconds in the foreground (the monitor pane runs this; Rule 18)
# env/config (resources.json; SR_* env or the flags override): SR_RSS_MB, SR_CPU_PCT, SR_FLOOR_MB, SR_CONFIG, SR_SAMPLE
# One ALERT line per seat over its RSS or CPU ceiling, and one when machine available RAM is under the floor.
#
# Owner, 2026-10-16 UTC: "we need to be conscious of each seat cost the system resouces, so we need a scripted way to
# monitor ram and cpu too".
# BREADCRUMB - seat membership is the pane's process tree, not herdr's foreground_processes.
# What broke: the brief measured by summing ps rss over `herdr pane process-info` foreground_processes; that list is
#   a snapshot of one process group and misses MCP servers that setsid away from it.
# Why this fix: every descendant of the pane's shell_pid, from one ps call, so the table and `ps` agree (AC1).
#   CPU is the delta of utime+stime over a short sample (default 1 s), not ps pcpu, which is a lifetime average.
# Cost: a 1 s sample per run; one herdr call per seat pane.
set -uo pipefail
# shellcheck source=resources/lib.sh disable=SC1091
. "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/lib.sh"
command -v jq >/dev/null || res_die "jq is required"; command -v herdr >/dev/null || res_die "herdr is required"

LINE=""; JSON=0; PUB=0; LOOP=0
RSS_MB="" CPU_PCT="" FLOOR_MB="" SAMPLE="${SR_SAMPLE:-1}"
while [ $# -gt 0 ]; do case "$1" in
  --line) LINE="$2"; shift 2 ;; --json) JSON=1; shift ;; --publish) PUB=1; shift ;; --loop) LOOP=1; shift ;;
  --rss-mb) RSS_MB="$2"; shift 2 ;; --cpu-pct) CPU_PCT="$2"; shift 2 ;; --floor-mb) FLOOR_MB="$2"; shift 2 ;;
  --sample) SAMPLE="$2"; shift 2 ;; -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) res_die "unknown argument $1" ;; esac; done
RSS_MB="${RSS_MB:-$(res_val SR_RSS_MB seat_rss_mb)}"; CPU_PCT="${CPU_PCT:-$(res_val SR_CPU_PCT seat_cpu_pct)}"
FLOOR_MB="${FLOOR_MB:-$(res_val SR_FLOOR_MB floor_mb)}"
KIND="$(res_cfg .agent_kind)"; NATS="$(res_cfg .nats_url)"; PFX="$(res_cfg .subject_prefix)"; INTERVAL="${SR_INTERVAL:-$(res_cfg .interval_seconds)}"

# ticks <pid>...: "pid ticks" from /proc, utime+stime.
ticks() { local p; for p in "$@"; do [ -r "/proc/$p/stat" ] && awk '{ s=$0; sub(/.*\) /, "", s); split(s, f, " "); print '"$p"', f[12]+f[13] }' "/proc/$p/stat"; done; }

nats_pub() { # nats_pub <subject> <payload>: fire-and-forget; never fails the sweep
  local host="${NATS%%:*}" port="${NATS##*:}" s="$1" m="$2"
  { exec 9<>"/dev/tcp/$host/$port"; } 2>/dev/null || { echo "WARN nats $NATS unreachable, not published" >&2; return 0; }
  printf 'CONNECT {"verbose":false}\r\nPUB %s %d\r\n%s\r\nPING\r\n' "$s" "${#m}" "$m" >&9; read -r -t 2 _ <&9 2>/dev/null; exec 9>&-
}

once() {
  local tmp panes tabs hz; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  res_ps > "$tmp/ps"; res_client_container_map > "$tmp/cc"
  panes="$(herdr pane list)" || res_die "herdr pane list failed"
  tabs="$(herdr tab list)" || res_die "herdr tab list failed"
  jq -r --arg k "$KIND" --arg l "$LINE" --argjson tabs "$tabs" '
    ($tabs.result.tabs | map({(.tab_id): .label}) | add) as $tl
    | .result.panes[] | select(.agent==$k)
    | ($tl[.tab_id] // "") as $t
    | select($l=="" or ($t | startswith($l + " ")))
    | [.pane_id, (.label // "-"), $t] | @tsv' <<<"$panes" > "$tmp/seats"
  hz="$(getconf CLK_TCK)"
  : > "$tmp/rows"; : > "$tmp/t0"
  while IFS=$'\t' read -r pane label tab; do
    sp="$(herdr pane process-info --pane "$pane" 2>/dev/null | jq -r '.result.process_info.shell_pid // empty')"
    [ -n "$sp" ] || continue
    res_descendants "$sp" "$tmp/ps" > "$tmp/d.$pane"
    # shellcheck disable=SC2046
    ticks $(cat "$tmp/d.$pane") | sed "s/^/$pane /" >> "$tmp/t0"
  done < "$tmp/seats"
  sleep "$SAMPLE"
  : > "$tmp/t1"
  while IFS=$'\t' read -r pane label tab; do
    [ -f "$tmp/d.$pane" ] || continue
    # shellcheck disable=SC2046
    ticks $(cat "$tmp/d.$pane") | sed "s/^/$pane /" >> "$tmp/t1"
    awk -v P="$pane" 'NR==FNR { r[$1]=$3; next } ($1 in r) { rss+=r[$1]; n++ } END { printf "%s %d %d\n", P, rss, n }' "$tmp/ps" "$tmp/d.$pane" > "$tmp/s.$pane"
    cpu="$(awk -v P="$pane" -v hz="$hz" -v dt="$SAMPLE" 'NR==FNR { if ($1==P) a[$2]=$3; next } $1==P && ($2 in a) { d+=$3-a[$2] } END { printf "%.1f", d/hz/dt*100 }' "$tmp/t0" "$tmp/t1")"
    read -r _ rss n < "$tmp/s.$pane"
    cn="$(awk 'NR==FNR { d[$1]=1; next } ($1 in d) { c++ } END { print c+0 }' "$tmp/d.$pane" "$tmp/cc")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$pane" "$label" "$tab" "$cpu" "$((rss/1024))" "$n" "$cn" >> "$tmp/rows"
  done < "$tmp/seats"
  local avail total; avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo); total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
  local at; at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [ "$JSON" = 1 ]; then
    jq -Rn --arg at "$at" --argjson av "$avail" --argjson tot "$total" '
      {at:$at, machine:{available_mb:$av,total_mb:$tot},
       seats:[inputs | split("\t") | {pane:.[0],seat:.[1],tab:.[2],cpu_pct:(.[3]|tonumber),rss_mb:(.[4]|tonumber),processes:(.[5]|tonumber),containers:(.[6]|tonumber)}]}' < "$tmp/rows"
  else
    printf '%-8s %-22s %-20s %7s %8s %6s %6s\n' PANE SEAT TAB CPU% RSS_MB PROCS CONTS
    sort -t$'\t' -k5,5nr "$tmp/rows" | awk -F'\t' '{printf "%-8s %-22s %-20s %7s %8s %6s %6s\n", $1,$2,$3,$4,$5,$6,$7}'
    awk -F'\t' '{r+=$5; p+=$6; c+=$7} END {printf "%-8s %-22s %-20s %7s %8d %6d %6d\n", "TOTAL","","","",r,p,c}' "$tmp/rows"
    printf 'machine: %d MB available of %d MB (floor %d MB)\n' "$avail" "$total" "$FLOOR_MB"
  fi
  # ALERTs: one line per breach (stderr-free, stdout, the log contract of bin/workflow-lib.sh: ALERT prefix)
  awk -F'\t' -v r="$RSS_MB" -v c="$CPU_PCT" '$5>r {printf "ALERT seat %s (%s) RSS %d MB over ceiling %d MB\n",$2,$1,$5,r} $4>c {printf "ALERT seat %s (%s) CPU %s%% over ceiling %d%%\n",$2,$1,$4,c}' "$tmp/rows"
  [ "$avail" -lt "$FLOOR_MB" ] && printf 'ALERT machine available RAM %d MB under floor %d MB\n' "$avail" "$FLOOR_MB"
  if [ "$PUB" = 1 ]; then
    local lsub="${LINE:-all}"; lsub="${lsub//[^A-Za-z0-9_-]/-}"
    while IFS=$'\t' read -r pane label tab cpu rss n cn; do
      nats_pub "$PFX.$lsub.${label//[^A-Za-z0-9_-]/-}" "$(jq -nc --arg at "$at" --arg p "$pane" --arg s "$label" --argjson c "$cpu" --argjson r "$rss" --argjson n "$n" --argjson k "$cn" '{at:$at,pane:$p,seat:$s,cpu_pct:$c,rss_mb:$r,processes:$n,containers:$k}')"
    done < "$tmp/rows"
    nats_pub "$PFX.machine" "$(jq -nc --arg at "$at" --argjson a "$avail" --argjson t "$total" '{at:$at,available_mb:$a,total_mb:$t}')"
  fi
}

if [ "$LOOP" = 1 ]; then while true; do once; sleep "$INTERVAL"; done; else once; fi
