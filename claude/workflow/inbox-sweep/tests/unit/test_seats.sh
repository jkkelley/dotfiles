#!/usr/bin/env bash
# WO-20261016-73cd: every seat the sweep and the send path start is declared in a run-local project.json, and the REAL
# workflow-spawn.sh accepts it. The other suites stub the spawner (SWEEP_SPAWN, SWEEP_SEAT_START), which is exactly why
# "no seat named gmail" reached main unseen; this suite runs the spawner itself with --dry-run against a stub herdr.
# Rules out: a seat missing from the run-local config, the tracked project.json gaining an owner-specific seat, and a
# workspace label the machine does not have.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
# shellcheck source=../lib/stubs.sh
. "$R/tests/lib/stubs.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
stubs_install "$T/bin"
# shellcheck source=../../bin/sweep-lib.sh
. "$R/bin/sweep-lib.sh"
export STUB_HERDR_AGENT_GONE=1 WIN_HOME="$T/winhome" SWEEP_WIN_HOME="$T/winhome" HERDR_WORKSPACE_ID=wS
mkdir -p "$T/winhome"
SPAWN="$R/../bin/workflow-spawn.sh"
tracked="$(jq -c '[.workflow.seats[].name]' "$R/../config/project.json")"

spawn_ok() { # <cfg> <workflow> <seat> <label>
  local out rc
  out="$(WORKFLOW_CONFIG="$1" bash "$SPAWN" "$2" "$3" --brief-file "$T/brief.md" --ticket IS-t --dry-run 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ] && ! grep -q 'no seat named' <<<"$out"; then ok "$4"; else bad "$4" "rc=$rc $(tail -n2 <<<"$out" | tr '\n' ' ')"; fi
}
echo brief >"$T/brief.md"

# The bug, reproduced against the tracked config, so this suite fails if the fix is ever undone by moving the seats back.
out="$(bash "$SPAWN" inbox-sweep-gmail gmail --brief-file "$T/brief.md" --ticket IS-t --dry-run 2>&1)"
if grep -q 'no seat named gmail' <<<"$out"; then ok "the tracked project.json alone still refuses gmail (the bug, reproduced)"
else bad "the tracked project.json alone still refuses gmail (the bug, reproduced)" "$out"; fi

cfg="$T/run/seats/project.json"
for s in gmail:gmail proton-acct-a:proton proton-acct-b:proton linkedin:linkedin; do
  seat="${s%%:*}" src="${s#*:}"
  sweep_seat_config "$cfg" "$seat" "inbox-sweep-$src" "agent-sweep-$seat" "$T/run/seats/$seat" >/dev/null
  spawn_ok "$cfg" "inbox-sweep-$src" "$seat" "the real spawner accepts sweep seat $seat from the run-local config"
done
check 4 "$(jq '[.workflow.seats[] | select(.tab_label | startswith("agent-sweep-"))] | length' "$cfg")" "one declaration per seat, no duplicate on a second call"
sweep_seat_config "$cfg" gmail inbox-sweep-gmail agent-sweep-gmail "$T/run/seats/gmail" >/dev/null
check 4 "$(jq '[.workflow.seats[] | select(.tab_label | startswith("agent-sweep-"))] | length' "$cfg")" "redeclaring a seat replaces it rather than adding a second"
# The stub herdr labels workspace wS "dotfiles"; a base config naming another workspace proves the label is taken from herdr.
jq '.workflow.herdr.workspace_label = "not-on-this-machine"' "$R/../config/project.json" >"$T/base.json"
WORKFLOW_CONFIG="$T/base.json" sweep_seat_config "$T/ws/project.json" gmail inbox-sweep-gmail agent-sweep-gmail "$T/ws/gmail" >/dev/null
check dotfiles "$(jq -r '.workflow.herdr.workspace_label' "$T/ws/project.json")" "workspace label comes from the caller's own herdr workspace"

rcfg="$T/folder/seats/project.json"
for seat in agent-reply-abc123 agent-reply-clear-abc123; do
  sweep_seat_config "$rcfg" "$seat" inbox-sweep-linkedin-send "$seat" "$T/folder/seats/$seat" >/dev/null
  spawn_ok "$rcfg" inbox-sweep-linkedin-send "$seat" "the real spawner accepts send seat $seat from the run-local config"
done

check "$tracked" "$(jq -c '[.workflow.seats[].name]' "$R/../config/project.json")" "the tracked project.json is never written"
finish
