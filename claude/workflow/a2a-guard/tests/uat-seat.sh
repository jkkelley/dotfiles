#!/usr/bin/env bash
# name: uat-seat.sh
# purpose: the no-model test seat the UAT gate runs as the foreground process of a real herdr pane.
# inputs: <control-file> <received-file>; env HERDR_BIN
# outputs: herdr lifecycle reports, exit code
# writes-to: <received-file>
# cleanup: releases its herdr agent report on exit; uat.sh closes the pane
# uat-seat.sh - the no-model test seat the UAT gate runs in a real herdr pane. It is the pane's foreground process, so
#   herdr accepts its own lifecycle reports and `herdr agent prompt` types into it, like a real agent.
# usage: uat-seat.sh <control-file> <received-file>
#   control-file holds the state to report (working|idle); each typed line is appended to received-file.
# No model, no network, no notification (Design principles 101 item 35). Exits when control-file reads "exit".
set -uo pipefail
ctl=$1 rcv=$2 cur="" HERDR="${HERDR_BIN:-herdr}"
pane=$("$HERDR" pane current 2>/dev/null | jq -r '.result.pane.pane_id // empty')
while :; do
  want=$(cat "$ctl" 2>/dev/null)
  [ "$want" = exit ] && { "$HERDR" pane release-agent --source a2a-uat --agent claude "$pane" >/dev/null 2>&1; exit 0; }
  if [ -n "$want" ] && [ "$want" != "$cur" ]; then
    "$HERDR" pane report-agent --source a2a-uat --agent claude --state "$want" "$pane" >/dev/null 2>&1 && cur=$want
  fi
  IFS= read -r -t 1 l && printf '%s\n' "$l" >> "$rcv"
done
