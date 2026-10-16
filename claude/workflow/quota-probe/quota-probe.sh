#!/usr/bin/env bash
# quota-probe.sh - probe a rate-limited tool once; QUOTA-OK, QUOTA-OUT or QUOTA-ERR, published on the bus on change.
# usage: quota-probe.sh --name NAME [--config FILE]
# inputs: config.json beside this script (or --config); env QP_STATE_DIR overrides state_dir, QP_BUS overrides the publisher
# outputs: one line '<code> <name> <at>'; exit 0 QUOTA-OK, 5 QUOTA-OUT, 4 QUOTA-ERR, 2 QUOTA-CFG
# writes-to: <state_dir>/<name>.json, <state_dir>/events.jsonl (bus-down fallback)
#
# BREADCRUMB - WO-20261016-8009.
# What broke: FB-006 (config/fallbacks.json) parks Figma-drawing tickets when the tool call limit is hit, and nothing
#   checks when the quota returns, so the parked tickets never resume.
# Why this fix: a probe run once a day by a systemd --user timer, publishing only a transition on the bus. A timer on this
#   machine and not a cluster CronJob because the claude.ai connector login lives here (Design principles 101 item 39
#   allows a local unit for what must read the local machine).
# Rejected: a seat polling the tool, which item 39 forbids (an agent running a loop).
# Cost: one call of the probed tool's quota a day.
# Record: claude/workflow/quota-probe/README.md
# shellcheck disable=SC2016 # the jq programs are single-quoted on purpose
set -uo pipefail
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
name=""; cfg="$DIR/config.json"
while [ $# -gt 0 ]; do
  case "$1" in
    --name) name="${2:-}"; shift 2 ;;
    --config) cfg="${2:-}"; shift 2 ;;
    *) echo "QUOTA-CFG unknown argument $1" >&2; exit 2 ;;
  esac
done
if [ -z "$name" ] || [ ! -f "$cfg" ] || ! jq -e --arg n "$name" '.probes[$n].command' "$cfg" >/dev/null 2>&1; then
  echo "QUOTA-CFG $name"; exit 2
fi
p() { jq -r --arg n "$name" "$1" "$cfg"; }
state_dir="${QP_STATE_DIR:-$(jq -r '.state_dir' "$cfg")}"
state_dir="${state_dir/#\~/$HOME}"
prefix="$(jq -r '.subject_prefix' "$cfg")"
cmd="$(p '.probes[$n].command')"
ok_re="$(p '.probes[$n].ok_regex')"
out_re="$(p '.probes[$n].out_regex')"
tmo="$(p '.probes[$n].timeout_s // 120')"
resumes="$(jq -c --arg n "$name" '.probes[$n].resumes // []' "$cfg")"
BUS="${QP_BUS:-bash $DIR/../bin/bus.sh pub}"

rc=0; out="$(timeout "$tmo" bash -c "$cmd" 2>&1)" || rc=$?
if [ "$rc" = 0 ] && grep -Eq "$ok_re" <<<"$out"; then code=QUOTA-OK; exit_rc=0
elif grep -Eq "$out_re" <<<"$out"; then code=QUOTA-OUT; exit_rc=5
else code=QUOTA-ERR; exit_rc=4; fi

at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkdir -p "$state_dir"
sf="$state_dir/$name.json"
prev="$(jq -r '.code // empty' "$sf" 2>/dev/null || true)"
jq -n --arg n "$name" --arg c "$code" --arg p "$prev" --arg a "$at" \
  '{name:$n, code:$c, prev:(if $p=="" then null else $p end), at:$a}' > "$sf.tmp" && mv "$sf.tmp" "$sf"

if [ "$code" != "$prev" ]; then
  ev="$(jq -c --argjson r "$resumes" '. + {resumes:$r}' "$sf")"
  # shellcheck disable=SC2086 # QP_BUS is a command with arguments
  if ! $BUS "$prefix.$name" "$ev" >/dev/null 2>&1; then
    echo "$ev" >> "$state_dir/events.jsonl"
    echo "FALLBACK QPROBE-BUS $name" >&2
  fi
fi
echo "$code $name $at"
exit "$exit_rc"
