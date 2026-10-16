#!/usr/bin/env bash
# ctx-guard.sh - one entry point that wires the existing compaction-guard into a seat or the whole host.
# usage: ctx-guard.sh install [--global|--project DIR] | status | check | uninstall [--global|--project DIR] | watch
#
# BREADCRUMB - this is a wrapper, not a guard.
# What broke: `compaction-guard doctor` on 2026-10-16 showed global_hooks=false and statusline_tap=false, so the
#   agent seats of sweep-build, yp-line and the architect ran with no 30% ceiling and no checkpoints (owner: "your
#   agents are wild as fuck"). Installing was a by-hand command nobody ran.
# Why this fix: compaction-guard already owns hooks, sensor, threshold (30) and checkpoints, and its `install` already
#   chains the host status line into statusline.next. Owner: "NEVER REINVENT THE WHEEL". This script only adds what the
#   tool lacks: a timestamped backup under ~/.local/state/zenith/backup, 3 retries, and an assertion that the result is
#   really wired. Rejected: a new guard, or copying settings by hand.
# Cost: --global edits ~/.claude/settings.json for every project. A running Claude Code session may not re-read it
#   (docs/ctx-guard.md), so only seats started after the install are guarded. Undo with `uninstall`.
# Backups: ~/.local/state/zenith/backup/YYYY/MM/ (UTC). Record: compaction-guard events ledger.
set -uo pipefail

CG="${COMPACTION_GUARD_BIN:-compaction-guard}"
STATE="${COMPACTION_GUARD_STATE:-$HOME/.local/state/compaction-guard}"
die() { printf 'ctx-guard: %s\n' "$*" >&2; exit 1; }
command -v "$CG" >/dev/null 2>&1 || die "compaction-guard not found; install it first (it is the tool this wraps)"
command -v jq >/dev/null 2>&1 || die "jq is required"

mode_args() { # sets TARGET_ARGS and SETTINGS from --global | --project DIR
  case "${1:---global}" in
    --global) TARGET_ARGS=(--global); SETTINGS="$HOME/.claude/settings.json" ;;
    --project) [ -n "${2:-}" ] || die "--project needs a dir"
               TARGET_ARGS=(--project "$2"); SETTINGS="$2/.claude/settings.json" ;;
    *) die "unknown option $1" ;;
  esac
}

backup() { # UTC-stamped copy of the settings file about to change
  local d; d="$HOME/.local/state/zenith/backup/$(date -u +%Y/%m)"
  mkdir -p "$d"
  [ -f "$SETTINGS" ] || return 0
  cp "$SETTINGS" "$d/$(date -u +%Y%m%d%H%M%S)-$(echo "$SETTINGS" | tr '/' '_')"
}

retry3() { # a step is tried 3 times, then reported, never looped
  local n=1
  until "$@"; do
    [ "$n" -ge 3 ] && return 1
    n=$((n + 1)); sleep 1
  done
}

assert_wired() {
  if [ "${TARGET_ARGS[0]}" = "--global" ]; then
    local d; d=$("$CG" doctor 2>/dev/null | tail -1)
    jq -e '.global_hooks == true and .statusline_tap == true' <<<"$d" >/dev/null || { echo "doctor: $d" >&2; return 1; }
    local next; next=$(cat "$STATE/statusline.next" 2>/dev/null)
    # The host's old status line must still be chained, unless it never had one.
    # statusline.next stores the host command verbatim, so a leading ~ is literal (seen 2026-10-16: ~/.claude/statusline.sh).
    next="${next/#\~/$HOME}"
    [ -z "$next" ] || [ -e "${next%% *}" ] || command -v "${next%% *}" >/dev/null || { echo "chained status line missing: $next" >&2; return 1; }
  else
    jq -e '[.hooks[]?[]?.hooks[]?.command] | any(test("compaction-guard hook"))' "$SETTINGS" >/dev/null &&
    jq -e '.statusLine.command | test("compaction-guard tap")' "$SETTINGS" >/dev/null
  fi
}

cmd="${1:-}"; shift || true
case "$cmd" in
  install)
    mode_args "$@"
    backup
    retry3 "$CG" install "${TARGET_ARGS[@]}" >/dev/null || die "install failed after 3 tries (backup kept)"
    assert_wired || die "installed but not wired as asserted; run: $CG doctor"
    echo "ok  ctx-guard installed (${TARGET_ARGS[*]}); threshold 30; only sessions started from now on are guarded" ;;
  uninstall)
    mode_args "$@"; backup
    retry3 "$CG" uninstall "${TARGET_ARGS[@]}" >/dev/null || die "uninstall failed after 3 tries"
    echo "ok  ctx-guard uninstalled (${TARGET_ARGS[*]})" ;;
  status) # token efficient: doctor plus the 10 fullest sessions, not all of the hundreds on disk
    "$CG" doctor; "$CG" status | jq -cs 'sort_by(-.pct)[:10][] | {session:.session[0:8],name,pct,phase}' ;;
  check)  "$CG" check ;;
  watch)  # one labeled herdr pane, no model calls; alerts on HIGH only (Rule 18: never a background job)
    if [ "${HERDR_ENV:-}" = 1 ] && [ -z "${CTX_WATCH_INPANE:-}" ]; then
      pane=$(herdr pane list 2>/dev/null | jq -r 'first(.result.panes[]? | select(.agent | not) | .pane_id) // empty')
      [ -n "$pane" ] || die "no free herdr pane for ctx-watch"
      herdr pane rename "$pane" ctx-watch >/dev/null 2>&1 || true
      herdr pane run "$pane" "CTX_WATCH_INPANE=1 $0 watch"
      echo "ok  ctx-watch running in pane $pane"
    else
      exec "$CG" watch
    fi ;;
  *) die "usage: ctx-guard.sh install|uninstall [--global|--project DIR] | status | check | watch" ;;
esac
