#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# sweep-clean.sh - R7 of the inbox sweep: take a finished run down, and expire old runs.
#
#   sweep-clean.sh clean [--run <run-id>]   close this run's agent-sweep-* tabs, remove its briefs and seat dirs,
#                                           write clean.json .cleaned_at. No --run: the latest run; with no run dirs
#                                           at all, removes the test output dir instead.
#   sweep-clean.sh prune --days <n>         remove run dirs older than n days (by the UTC stamp in the run id),
#                                           a dangling latest link, and record rows of those runs.
#
# Refuses (exit 3): clean on a run whose status is RUN-RUNNING; prune with --days below 1 (exit 2).
# Never touches config.json or owner-words.md: they are owner data (design section 9).
#
# Environment (tests point these at a sandbox):
#   SWEEP_RUNS_ROOT  default <win-home>/.local/state/zenith/inbox-sweep/runs
#   SWEEP_LATEST     default ~/.local/state/zenith/inbox-sweep/latest
#   SWEEP_EXEC_DIR   default ~/.local/state/dotfiles/execution (holds seats/ and records/)
#   SWEEP_TEST_OUT   default ${XDG_CACHE_HOME:-~/.cache}/dotfiles/inbox-sweep-test
#
# Design: docs/design/inbox-sweep.md sections 5 (R7), 9 and D6; spec node `scripts` / `sweep-clean.sh`.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sweep-lib.sh
. "$HERE/sweep-lib.sh"

STAMP_RE='^[0-9]{8}T[0-9]{6}Z$'
usage() { echo "usage: sweep-clean.sh clean [--run <run-id>] | prune --days <n>" >&2; exit 2; }
runs_root() { printf '%s\n' "${SWEEP_RUNS_ROOT:-$(sweep_win_home)/.local/state/zenith/inbox-sweep/runs}"; }
latest_link() { printf '%s\n' "${SWEEP_LATEST:-$HOME/.local/state/zenith/inbox-sweep/latest}"; }
exec_dir() { printf '%s\n' "${SWEEP_EXEC_DIR:-$HOME/.local/state/dotfiles/execution}"; }
test_out() { printf '%s\n' "${SWEEP_TEST_OUT:-${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/inbox-sweep-test}"; }

cmd_clean() {
  local run="" root
  while [ $# -gt 0 ]; do
    case "$1" in
      --run) run="${2:?--run needs a run id}"; shift 2 ;;
      *) usage ;;
    esac
  done
  root="$(runs_root)"
  if [ -z "$run" ]; then
    if compgen -G "$root/*/run.json" >/dev/null; then
      [ -L "$(latest_link)" ] || { echo "sweep-clean: run dirs exist but there is no latest link; pass --run <run-id>" >&2; exit 2; }
      run="$(basename "$(readlink "$(latest_link)")")"
    else
      rm -rf "$(test_out)"
      echo "no runs; removed test output"
      return 0
    fi
  fi
  [[ $run =~ $STAMP_RE ]] || { echo "sweep-clean: bad run id '$run'" >&2; exit 2; }
  local dir="$root/$run"
  [ -f "$dir/run.json" ] || { echo "sweep-clean: no run.json in $dir" >&2; exit 2; }
  # Status lives in controller.json (WO-20261016-002d, ruling R3); no controller.json means the run never started: RUN-RUNNING.
  if [ "$(jq -r '.status // "RUN-RUNNING"' "$dir/controller.json" 2>/dev/null || echo RUN-RUNNING)" = RUN-RUNNING ]; then
    echo "sweep-clean: run $run is RUN-RUNNING; refusing to clean" >&2
    exit 3
  fi

  mkdir -p "$dir/logs"
  local log="$dir/logs/clean.log" bad=0 seats pane seat link d label tab
  export SWEEP_RUN_DIR="$dir"
  # A seat belongs to this run only if its seat-link says ticket IS-<run-id>: that is what the spawner writes
  # (--ticket IS-<run-id>). Matching on the tab label alone would close another run's seat tab.
  seats="$(exec_dir)/seats"
  local -a tabs=() dirs=()
  for link in "$seats"/*/seat-link; do
    [ -f "$link" ] || continue
    [ "$(jq -r '.ticket // empty' "$link")" = "IS-$run" ] || continue
    d="$(dirname "$link")"
    seat="$(jq -r '.seat // empty' "$link")"
    pane="$(jq -r '.pane // empty' "$link")"
    dirs+=("$d")
    # Tab label is agent-sweep-<seat>; both halves are required so a tab named agent-sweep-* for another seat survives.
    label="agent-sweep-$seat"
    tab="$(herdr tab list | jq -r --arg l "$label" 'first(.result.tabs[] | select(.label == $l) | .tab_id) // empty')"
    [ -z "$tab" ] || tabs+=("$tab")
    : "$pane"
  done
  for tab in "${tabs[@]}"; do
    if sweep_retry 3 "close-tab-$tab" herdr tab close "$tab"; then
      echo "closed tab $tab" >>"$log"
    else
      echo "FAILED to close tab $tab after 3 tries" >>"$log"
      bad=1
    fi
  done
  { echo "--- herdr tab list after close"; herdr tab list || true; } >>"$log" 2>&1
  sweep_check R7 "no agent-sweep-* herdr tab for this run" "logs/clean.log" || true

  rm -rf "$dir/briefs"
  for d in "${dirs[@]}"; do rm -rf "$d"; done
  # cleaned_at is set only when every tab closed: a run with a stuck tab must not read as cleaned.
  if [ "$bad" = 0 ]; then
    # clean.json is this script's own record; run.json is written once by init and is not touched (ruling R3).
    jq -n --arg r "$run" --arg at "$(sweep_now)" '{schema_version:1, run_id:$r, cleaned_at:$at}' >"$dir/clean.json.tmp" && mv "$dir/clean.json.tmp" "$dir/clean.json"
    echo "cleaned $run"
  else
    echo "sweep-clean: run $run partly cleaned; see $log" >&2
    exit 1
  fi
}

cmd_prune() {
  local days=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --days) days="${2:?--days needs a number}"; shift 2 ;;
      *) usage ;;
    esac
  done
  if ! [[ $days =~ ^[0-9]+$ ]] || [ "$days" -lt 1 ]; then echo "sweep-clean: --days must be an integer >= 1" >&2; exit 2; fi
  local root cutoff d id f tmp removed=0
  root="$(runs_root)"
  # Run ids are fixed-width UTC stamps, so a string compare against the cutoff stamp is a time compare.
  cutoff="$(date -u -d "-$days days" +%Y%m%dT%H%M%SZ)"
  for d in "$root"/*/; do
    [ -d "$d" ] || continue
    id="$(basename "$d")"
    [[ $id =~ $STAMP_RE ]] || continue
    if [[ $id < $cutoff ]]; then
      rm -rf "${d%/}"
      removed=$((removed + 1))
    fi
  done
  # -L and not -e: a dangling link fails -e, which is exactly the case to catch.
  if [ -L "$(latest_link)" ] && [ ! -e "$(latest_link)" ]; then rm -f "$(latest_link)"; fi
  for f in "$(exec_dir)"/records/inbox-sweep-*.jsonl; do
    [ -f "$f" ] || continue
    tmp="$(mktemp "$(dirname "$f")/.sweep-prune.XXXXXX")"
    # Unparsable rows and rows without a run id are kept: pruning must never destroy what it cannot read.
    if jq -rR --arg c "$cutoff" '. as $l | (try ($l | fromjson) catch null) as $r
        | if ($r | type) == "object" and ($r.run_id | type) == "string"
             and (($r.run_id | ltrimstr("IS-")) | test("^[0-9]{8}T[0-9]{6}Z$"))
             and (($r.run_id | ltrimstr("IS-")) < $c) then empty else $l end' "$f" >"$tmp"; then
      mv "$tmp" "$f"
    else
      rm -f "$tmp"
      echo "sweep-clean: could not prune $f" >&2
      return 1
    fi
  done
  echo "pruned $removed run(s) older than $days day(s)"
}

[ $# -ge 1 ] || usage
verb="$1"; shift
case "$verb" in
  clean) cmd_clean "$@" ;;
  prune) cmd_prune "$@" ;;
  *) usage ;;
esac
