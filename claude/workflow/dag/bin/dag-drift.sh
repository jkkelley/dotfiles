#!/usr/bin/env bash
# shellcheck disable=SC2016 # single-quoted bash -c body and jq filters expand in the child, which is the point
# dag-drift.sh - compares a run's state file with the design and the world, prints one DR line per mismatch, never repairs.
#   name:       dag-drift.sh
#   purpose:    the `drift` verb of docs/design/dag-state.spec.xml: checks design worktree lease ticket pr ci output
#   inputs:     --run <run-id> (or RUN), --config <dag.json> (or DAG_CONFIG; reads state_dir, required_checks, base_branch),
#               --nodes-dir <dir of *.node.json> (or DAG_NODES_DIR; default ../nodes beside this script), DAG_STATE_DIR,
#               world tools by env so tests can fake them: DAG_GIT (git), DAG_GH (gh), DAG_SLOT (slot.sh), DAG_WO (work-order.sh),
#               DAG_RETRY_WAITS, DAG_SLEEP (see dag-lib.sh)
#   outputs:    stdout: one line per mismatch "<DR-CODE> [node] state=<v> world=<v>"; stderr: usage errors.
#               exit 0 no drift, 1 drift found, 2 bad usage, 3 DG-SCHEMA on the state file
#   writes-to:  <state_dir>/runs/<run-id>/ledger.jsonl only (one drift row per mismatch, or one DG-DONE row "no drift")
#   cleanup:    removes its own temp dir on exit
# Spec: docs/design/dag-state.spec.xml <verb name="drift"> and rule R6; design docs/design/dag-state.md section 8.
#
# BREADCRUMB (WO-20261016-bf7f, dag-state T4). Rule R6: every line carries the state value and the world value, and the
# script never writes state. A world read (git, gh, slot.sh, work-order.sh) is tried up to 3 times with dag-lib's waits; one
# that still fails is reported as a drift line with world=unreadable, because silence there would read as "no drift".
# Design hash = sha256 of the sorted "sha256sum" listing of *.node.json in the nodes dir, the same value N1 pins; a nodes dir
# that is missing is world=missing. Ledger: the schema wants a DG- or DR- code, so a clean run logs DG-DONE with detail.
# Rejected: repairing drift here; repair is apply after plan marks the node DG-STALE. Cost: a flaky gh shows up as drift.

_DRIFT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dag-lib.sh disable=SC1091
. "$_DRIFT_DIR/dag-lib.sh"

DRIFT_N=0
drift() { # drift <DR-CODE> <node|-> <state> <world>
  local node=""; [ "$2" = - ] || node=" $2"
  printf '%s%s state=%s world=%s\n' "$1" "$node" "$3" "$4"
  DRIFT_N=$((DRIFT_N + 1))
  dag_ledger "$RUN" drift "$1" "${node# }" "state=$3 world=$4" || true
}

# world <out-var> <cmd...> - captures stdout of cmd, retrying 3 times; returns 1 when it never succeeds.
world() {
  local __v="$1" __o; shift
  __o="$(mktemp "$TMP/w.XXXXXX")"
  if dag_retry 3 bash -c '"$@" >"$0" 2>/dev/null' "$__o" "$@"; then
    printf -v "$__v" '%s' "$(cat "$__o")"; return 0
  fi
  return 1
}

main() {
  local RUN="${RUN:-}" cfg="${DAG_CONFIG:-}" nodes="${DAG_NODES_DIR:-$_DRIFT_DIR/../nodes}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --run) RUN="${2:-}"; shift 2 ;;
      --config) cfg="${2:-}"; shift 2 ;;
      --nodes-dir) nodes="${2:-}"; shift 2 ;;
      *) dag_err "usage: dag-drift.sh --run <run-id> [--config dag.json] [--nodes-dir dir]"; return 2 ;;
    esac
  done
  [ -n "$RUN" ] || { dag_err "usage: dag-drift.sh --run <run-id> [--config dag.json] [--nodes-dir dir]"; return 2; }
  export DAG_CONFIG="$cfg"
  local git="${DAG_GIT:-git}" gh="${DAG_GH:-gh}" slot="${DAG_SLOT:-slot.sh}" wo="${DAG_WO:-work-order.sh}"
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

  local st rd rc=0
  rd="$(dag_run_dir "$RUN")" || return 2
  st="$(dag_read "$RUN")" || { rc=$?; return "$rc"; }
  export RUN

  local v w
  # design: pinned hash vs the declarations now
  v="$(jq -r '.design.sha256' <<<"$st")"
  if [ -d "$nodes" ] && compgen -G "$nodes/*.node.json" >/dev/null; then
    w="$(cd "$nodes" && sha256sum -- *.node.json | LC_ALL=C sort -k2 | sha256sum | cut -d' ' -f1)"
  else w=missing; fi
  [ "$v" = "$w" ] || drift DR-DESIGN - "$v" "$w"

  # worktree: path and branch vs git worktree list
  local wp wb listing found cur
  wp="$(jq -r '.worktree.path' <<<"$st")"; wb="$(jq -r '.worktree.branch' <<<"$st")"
  if world listing "$git" worktree list --porcelain; then
    found="$(awk -v p="$wp" '$1=="worktree"{on=($2==p)} on&&$1=="branch"{sub("refs/heads/","",$2); print $2; exit} on&&$1=="detached"{print "detached"; exit}' <<<"$listing")"
    [ -n "$found" ] || found=absent
    [ "$found" = "$wb" ] || drift DR-WORKTREE - "$wp@$wb" "$wp@$found"
  else drift DR-WORKTREE - "$wp@$wb" unreadable; fi

  # lease: the slot state holds must be leased to someone
  local slotn
  slotn="$(jq -r '.worktree.slot // empty' <<<"$st")"
  if [ -n "$slotn" ]; then
    if world cur "$slot" status --repo "$wp"; then
      found="$(awk -F'\t' -v s="$slotn" '$2==s{print ($1=="-"?"free":$1); exit}' <<<"$cur")"
      [ -n "$found" ] || found=absent
      case "$found" in free | absent) drift DR-LEASE - "held:$slotn" "$found" ;; esac
    else drift DR-LEASE - "held:$slotn" unreadable; fi
  fi

  # ticket: the status the finished nodes imply vs work-order.sh show
  local tid want
  tid="$(jq -r '.ticket.id' <<<"$st")"
  ns() { jq -r --arg n "$1" '.nodes[$n].status // "absent"' <<<"$st"; }
  want=""
  if [ "$(ns N7)" = DG-DONE ]; then want="done"
  elif [ "$(ns N6)" = DG-DONE ]; then want="in-review|in-progress"
  elif [ "$(ns N3)" = DG-DONE ]; then want="in-progress"; fi
  if [ -n "$want" ]; then
    if world cur "$wo" show --id "$tid" --json; then
      found="$(jq -r '.status // "unknown"' <<<"$cur" 2>/dev/null || echo unreadable)"
      case "|$want|" in *"|$found|"*) ;; *) drift DR-TICKET - "$want" "$found" ;; esac
    else drift DR-TICKET - "$want" unreadable; fi
  fi

  # pr: number recorded in state vs gh pr view
  local prn pst
  prn="$(jq -r '.pr.number // empty' <<<"$st")"
  if [ -n "$prn" ]; then
    [ "$(ns N9)" = DG-DONE ] && pst=MERGED || pst=OPEN
    if world cur "$gh" pr view "$prn" --json number,state; then
      found="$(jq -r '"\(.number):\(.state)"' <<<"$cur" 2>/dev/null || echo unreadable)"
      [ "$found" = "$prn:$pst" ] || drift DR-PR - "$prn:$pst" "$found"
    else drift DR-PR - "$prn:$pst" unreadable; fi

    # ci: N8 DG-DONE means every required check passed; ask gh now
    if [ "$(ns N8)" = DG-DONE ]; then
      local req name bad=""
      req="$(jq -r '.required_checks // [] | .[]' "$cfg" 2>/dev/null)"
      if world cur "$gh" pr checks "$prn" --json name,bucket; then
        while IFS= read -r name; do
          [ -n "$name" ] || continue
          found="$(jq -r --arg n "$name" '[.[] | select(.name == $n) | .bucket][0] // "absent"' <<<"$cur")"
          [ "$found" = pass ] || bad="${bad:+$bad,}$name:$found"
        done <<<"$req"
        [ -z "$bad" ] || drift DR-CI N8 "DG-DONE all-pass" "$bad"
      else drift DR-CI N8 "DG-DONE all-pass" unreadable; fi
    fi
  fi

  # output: recorded sha256 vs the file now (relative paths are under the run dir)
  local n out osha f
  while IFS=$'\t' read -r n out osha; do
    [ -n "$n" ] || continue
    f="$out"; case "$f" in /*) ;; *) f="$rd/$f" ;; esac
    if [ -f "$f" ]; then w="$(sha256sum "$f" | cut -d' ' -f1)"; else w=missing; fi
    [ "$osha" = "$w" ] || drift DR-OUTPUT "$n" "$osha" "$w"
  done < <(jq -r '.nodes | to_entries[] | select(.value.output != null and .value.output_sha256 != null) | [.key, .value.output, .value.output_sha256] | @tsv' <<<"$st")

  if [ "$DRIFT_N" = 0 ]; then dag_ledger "$RUN" drift DG-DONE "" "no drift" || true; return 0; fi
  return 1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -uo pipefail
  main "$@"
  exit $?
fi
