#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# sweep.sh - R0 of the inbox sweep: the one controller behind `make sweep`.
#
#   sweep.sh start --seats all|gmail|proton|linkedin   create the run, hand it to a labeled herdr pane, return at once
#   sweep.sh run --run <run-id>                        the run itself; foreground of the sweep-ctl pane (Rule 18)
#   sweep.sh status [--run <run-id>]                   run.json summary, latest run by default; reads no pane
#   sweep.sh clean [--run <run-id>]                    sweep-clean.sh clean
#   sweep.sh prune --days <n>                          sweep-clean.sh prune
#   sweep.sh test --changed | --all | --suite <name>   the Podman suites, through the Makefile
#
# Platform: WSL only (design D2). It needs herdr, Windows interop and the Windows home, so no justfile (Rule 17).
#
# `run` order, one script per step (spec run-dag R2 to R7): preflight; baseline tab bar; spawn one seat per enabled seat
# the preflight allows; watch; collect; verify tab bar; collect again; cards; clean. Every step that can fail goes
# through sweep_retry 3, then is recorded and the run moves on, never loops and never fails silently.
#
# BREADCRUMB - collect runs twice, and a controller error is passed down, not stored.
# What broke: sweep-collect.sh derives RUN-OK only when proof/R7-verdict.json says CLEAN-OK, and sweep-proof.sh writes that
#   verdict after the first collect (sweep-collect.sh header, design section 5 R7). One collect call can never say RUN-OK.
# Why this fix: collect is idempotent, so the controller calls it again once verify has written the verdict, and run.json
#   .status is set from that second answer. A controller error (a step that failed all 3 tries and left the run in a state
#   the seats' results do not describe) is handed over as --controller-error, which collect maps to RUN-FAILED.
#   Rejected: a run.json field for the error, which collect and this script would have to agree on out of band.
# Cost: summary.json is written twice; the first copy lives for the length of one proof capture.
#
# BREADCRUMB - run.json .status is set by this script before clean, not by clean.
# sweep-clean.sh refuses a run whose status is RUN-RUNNING (it would pull tabs out from under live seats), and init writes
# RUN-RUNNING. Something has to move it; the controller is the only script that knows the run is over.
#
# BREADCRUMB - `start` returns before the run does, and the run lives in a pane, never in a background job.
# Rule 18: invisible work reads as nothing happening. `start` creates the `inbox-sweep` tab, renames its pane `sweep-ctl`,
#   and types `sweep.sh run` into it, so the owner watches the run where they watch everything else. `make sweep` must
#   return within 5 seconds (spec B9), and init, a tab create and a pane run are all of its work.
#
# Exit: 0 done (run finished, whatever its code; the code is in summary.json); 1 a start step failed; 2 usage;
#       3 precondition refused (PF-NO-OWNER-WORDS from init, PF-NO-HERDR from preflight).
#
# Environment (tests point these at a sandbox; each is also read by the scripts this one calls):
#   SWEEP_RUNS_ROOT       default <win-home>/.local/state/zenith/inbox-sweep/runs
#   SWEEP_LATEST          default ~/.local/state/zenith/inbox-sweep/latest
#   SWEEP_SEATS_DIR       default ~/.local/state/dotfiles/execution/seats (where workflow-spawn.sh writes seat-link)
#   SWEEP_SPAWN           default claude/workflow/bin/workflow-spawn.sh; tests point it at a recorder
#   SWEEP_HERDR_WORKSPACE herdr workspace label for the sweep-ctl tab (default dotfiles)
# Design: docs/design/inbox-sweep.md section 5 and section 10 (B9); spec script `sweep.sh`.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWEEP="$(cd "$HERE/.." && pwd)"
# shellcheck source=sweep-lib.sh
. "$HERE/sweep-lib.sh"

usage() {
  echo "usage: sweep.sh start --seats all|gmail|proton|linkedin | run --run <run-id> | status [--run <run-id>] | clean [--run <run-id>] | prune --days <n> | test --changed|--all|--suite <name>" >&2
  exit 2
}
[ $# -ge 1 ] || usage
verb="$1"
shift

STAMP_RE='^[0-9]{8}T[0-9]{6}Z$'
runs_root() { printf '%s\n' "${SWEEP_RUNS_ROOT:-$(sweep_win_home)/.local/state/zenith/inbox-sweep/runs}"; }
latest_link() { printf '%s\n' "${SWEEP_LATEST:-$HOME/.local/state/zenith/inbox-sweep/latest}"; }
need_run_arg() { # parses an optional/required --run into $run
  run=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --run) run="${2:?--run needs a run id}"; shift 2 ;;
      *) usage ;;
    esac
  done
}

# ---- start -----------------------------------------------------------------------------------------------------------
cmd_start() {
  if [ $# -ne 2 ] || [ "$1" != "--seats" ]; then usage; fi
  case "$2" in all | gmail | proton | linkedin) ;; *) usage ;; esac
  local rid rc ws tab pane
  rid="$(bash "$HERE/sweep-init.sh" --seats "$2")"
  rc=$?
  if [ "$rc" -ne 0 ] || ! [[ $rid =~ $STAMP_RE ]]; then
    # init already said why on stderr; a refusal (3) keeps its code so make can tell it from a failure
    [ "$rc" -eq 3 ] && exit 3
    exit 1
  fi
  ws="$(herdr workspace list 2>/dev/null | jq -r --arg l "${SWEEP_HERDR_WORKSPACE:-dotfiles}" 'first(.result.workspaces[] | select(.label == $l) | .workspace_id) // empty')"
  [ -n "$ws" ] || { echo "sweep.sh: no herdr workspace labelled '${SWEEP_HERDR_WORKSPACE:-dotfiles}' (PF-NO-HERDR); run $rid created but not started" >&2; exit 3; }
  herdr tab create --workspace "$ws" --cwd "$PWD" --label inbox-sweep --no-focus >/dev/null || { echo "sweep.sh: herdr tab create failed" >&2; exit 1; }
  tab="$(herdr tab list --workspace "$ws" | jq -r 'first(.result.tabs[] | select(.label == "inbox-sweep") | .tab_id) // empty')"
  pane="$(herdr pane list --workspace "$ws" | jq -r --arg t "$tab" 'first(.result.panes[] | select(.tab_id == $t) | .pane_id) // empty')"
  if [ -z "$tab" ] || [ -z "$pane" ]; then
    echo "sweep.sh: the inbox-sweep tab or its pane was not found after creating it" >&2
    exit 1
  fi
  herdr pane rename "$pane" sweep-ctl >/dev/null || exit 1
  herdr pane run "$pane" "bash $HERE/sweep.sh run --run $rid" >/dev/null || exit 1
  printf '%s\n' "$rid"
}

# ---- run -------------------------------------------------------------------------------------------------------------
cmd_run() {
  need_run_arg "$@"
  [[ $run =~ $STAMP_RE ]] || usage
  if [ -z "${SWEEP_RUN_DIR:-}" ]; then SWEEP_RUN_DIR="$(runs_root)/$run"; fi
  export SWEEP_RUN_DIR
  local RUN="$SWEEP_RUN_DIR"
  [ -f "$RUN/run.json" ] || { echo "sweep.sh: no run.json in $RUN" >&2; exit 2; }
  mkdir -p "$RUN/logs"
  local LOG="$RUN/logs/controller.log"
  log() { printf '%s %s\n' "$(sweep_now)" "$*" >>"$LOG"; }
  local spawn="${SWEEP_SPAWN:-$SWEEP/../bin/workflow-spawn.sh}"
  local seats_dir="${SWEEP_SEATS_DIR:-$HOME/.local/state/dotfiles/execution/seats}"
  local ctl_error=0 pane_id="${HERDR_PANE_ID:-}"
  log "run $run started"

  # Names the pane `sweep-ctl <run-id> <status>` so the owner reads the state off the tab.
  label_pane() { [ -n "$pane_id" ] && herdr pane rename "$pane_id" "sweep-ctl $run $1" >/dev/null 2>&1; return 0; }
  label_pane RUN-RUNNING

  # A result written on a seat's behalf (skipped, or never started), valid against the schema.
  synth() { # <seat> <status> <message>
    local seat="$1" st="$2" msg="$3" t src acct
    t="$(sweep_now)"
    src="$(jq -r --arg s "$seat" '.seats[] | select(.seat==$s) | .source' "$RUN/run.json")"
    acct="$(jq -r --arg s "$seat" '.seats[] | select(.seat==$s) | .account' "$RUN/run.json")"
    jq -n --arg rid "$run" --arg seat "$seat" --arg src "$src" --arg acct "$acct" --arg st "$st" --arg t "$t" --arg msg "$msg" '
      {schema_version:"1.0.0", run_id:$rid, seat:$seat, source:$src, account:$acct, status:$st,
       started_at:$t, finished_at:$t, attempts:1,
       counts:{before:{unread:null}, after:{unread:null}, processed:0, important:0, bulk:0},
       items:[], drafts:[], owner_decisions:[], mutations:[],
       errors:(if $st == "SKIPPED" then [] else [{at:$t, attempt:1, step:"controller", message:$msg}] end),
       tab_closed:true}' >"$RUN/results/$seat.json.tmp" && mv "$RUN/results/$seat.json.tmp" "$RUN/results/$seat.json"
    sweep_json_set "$RUN/run.json" '(.seats[] | select(.seat==$s)) |= (.status=$st)' --arg s "$seat" --arg st "$st"
    log "$seat $st: $msg"
  }

  # R2 preflight. Exit 3 is PF-NO-HERDR: nothing may start, but the run still gets a summary, a card and a clean.
  local halted=0 prc
  bash "$HERE/sweep-preflight.sh" --run "$run" >>"$LOG" 2>&1
  prc=$?
  case "$prc" in
    0) ;;
    3) halted=1; log "PF-NO-HERDR: no seat started" ;;
    *) ctl_error=1; halted=1; log "preflight failed with exit $prc" ;;
  esac

  if [ "$halted" -eq 0 ]; then
    # Browser seats need claude.exe, Chrome and a connected extension; Gmail runs on the connector alone (spec: preflight).
    local browser_ok=1
    if jq -e '[.checks[]?.code] | any(. == "PF-NO-CLAUDE-EXE" or . == "PF-NO-CHROME" or . == "PF-NO-BROWSER")' "$RUN/preflight.json" >/dev/null 2>&1; then
      browser_ok=0
    fi
    # Before the first spawn, so the baseline holds no seat tab (spec sweep-proof baseline).
    bash "$HERE/sweep-proof.sh" baseline --run "$run" >>"$LOG" 2>&1 || log "baseline capture failed; R7 can only reach CLEAN-NO-PROOF"

    local seat source pane
    while IFS=$'\t' read -r seat source; do
      if [ "$source" != gmail ] && [ "$browser_ok" -eq 0 ]; then
        synth "$seat" SKIPPED "browser preflight failed"
        continue
      fi
      # Run-local seat declaration (sweep_seat_config, WO-20261016-73cd): the tracked project.json cannot name these seats.
      if ! sweep_seat_config "$RUN/seats/project.json" "$seat" "inbox-sweep-$source" "agent-sweep-$seat" "$RUN/seats/$seat" >/dev/null; then
        synth "$seat" FAILED-SEAT "could not declare the seat in the run-local config"
        continue
      fi
      if WORKFLOW_CONFIG="$RUN/seats/project.json" sweep_retry 3 "spawn-$seat" "$spawn" "inbox-sweep-$source" "$seat" --brief-file "$RUN/briefs/$seat.md" --ticket "IS-$run" >>"$LOG" 2>&1; then
        # workflow-spawn.sh keeps no pane on stdout the controller can rely on; its seat-link file names the pane.
        pane="$(jq -rs --arg t "IS-$run" --arg s "$seat" 'map(select(.ticket == $t and .seat == $s)) | first | .pane // empty' "$seats_dir"/*/seat-link 2>/dev/null)"
        sweep_json_set "$RUN/run.json" '(.seats[] | select(.seat==$s)) |= (.pane = (if $p == "" then null else $p end))' --arg s "$seat" --arg p "$pane" || true
        sweep_check R3 "seat started in agent-sweep-$seat" "seat-link in $seats_dir, pane ${pane:-unknown}" || true
      else
        synth "$seat" FAILED-SEAT "workflow-spawn.sh failed after 3 tries"
      fi
    done < <(jq -r '.seats[] | select(.status == "RUN-RUNNING") | [.seat, .source] | @tsv' "$RUN/run.json")

    # R4. The watcher ends only when every seat is final; its own failure is a controller error, collect says RUN-FAILED.
    bash "$HERE/sweep-watch.sh" --run "$run" >>"$LOG" 2>&1 || { ctl_error=1; log "watch exited non-zero"; }
  fi

  # R5 to R7. Always reached, so a halted run still leaves a summary, a card and a clean run dir.
  local ce=()
  [ "$ctl_error" -eq 1 ] && ce=(--controller-error)
  finish() { # <collect args...> sets run.json status and finished_at from summary.json
    local st
    st="$(bash "$HERE/sweep-collect.sh" --run "$run" "$@" 2>>"$LOG")" || { log "collect failed"; return 1; }
    sweep_json_set "$RUN/run.json" '.status = $st | .finished_at = $at' --arg st "$st" --arg at "$(sweep_now)" || return 1
    log "run status $st"
  }
  finish ${ce[@]+"${ce[@]}"} || ctl_error=1
  if [ "$halted" -eq 0 ]; then
    bash "$HERE/sweep-proof.sh" verify --run "$run" >>"$LOG" 2>&1 || log "verify exited non-zero"
  fi
  [ "$ctl_error" -eq 1 ] && ce=(--controller-error)
  finish ${ce[@]+"${ce[@]}"} || ctl_error=1
  bash "$HERE/sweep-cards.sh" --run "$run" >>"$LOG" 2>&1 || log "cards exited non-zero"
  bash "$HERE/sweep-clean.sh" clean --run "$run" >>"$LOG" 2>&1 || log "clean exited non-zero"

  local final
  final="$(jq -r .status "$RUN/run.json")"
  label_pane "$final"
  printf '%s\n%s\n' "$final" "$RUN/summary.md"
  [ "$prc" -eq 3 ] && exit 3
  exit 0
}

# ---- status ----------------------------------------------------------------------------------------------------------
cmd_status() {
  need_run_arg "$@"
  if [ -z "$run" ]; then
    [ -L "$(latest_link)" ] || { echo "sweep.sh: no latest run" >&2; exit 2; }
    run="$(basename "$(readlink "$(latest_link)")")"
  fi
  [[ $run =~ $STAMP_RE ]] || usage
  local f
  f="$(runs_root)/$run/run.json"
  [ -f "$f" ] || { echo "sweep.sh: no run.json for $run" >&2; exit 2; }
  jq -r '"run \(.run_id) \(.status)\nstarted \(.started_at) finished \(.finished_at // "n/a")",
         (.seats[] | "  \(.seat) \(.status) deadline \(.deadline_at)"),
         "seats \(.seats | length), final \([.seats[] | select(.status != "RUN-RUNNING")] | length), running \([.seats[] | select(.status == "RUN-RUNNING")] | length)"' "$f"
}

# ---- test: the Makefile owns the Podman call, so a plain `make` and this verb can never disagree ---------------------
cmd_test() {
  case "${1:-}" in
    --changed) exec make -C "$SWEEP" test ;;
    --all) exec make -C "$SWEEP" test-all ;;
    --suite)
      [ $# -eq 2 ] || usage
      exec make -C "$SWEEP" suite SUITE="$2" ;;
    *) usage ;;
  esac
}

case "$verb" in
  start) cmd_start "$@" ;;
  run) cmd_run "$@" ;;
  status) cmd_status "$@" ;;
  clean) exec bash "$HERE/sweep-clean.sh" clean "$@" ;;
  prune) exec bash "$HERE/sweep-clean.sh" prune "$@" ;;
  test) cmd_test "$@" ;;
  *) usage ;;
esac
