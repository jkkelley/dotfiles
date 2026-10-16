#!/usr/bin/env bash
# name: a2a-lib.sh
# purpose: shared config, queue path and lock helpers for the a2a-guard scripts; sourced, never run.
# inputs: env A2A_CONFIG A2A_STATE_DIR A2A_LINE HERDR_BIN
# outputs: shell variables and functions
# writes-to: nothing
# cleanup: none
# shellcheck disable=SC2034  # A2A_LINE_DEFAULT and HERDR are read by the scripts that source this file.
# a2a-lib.sh - shared config reading for a2a-send.sh, a2a-deliver.sh and a2a-lint.sh. Sourced, never run.
# Inputs: A2A_CONFIG (default config.json beside this file), A2A_STATE_DIR, A2A_LINE, HERDR_BIN, NATS_BIN.
A2A_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
A2A_CFG="${A2A_CONFIG:-$A2A_HERE/config.json}"
a2a_die() { local c=$1; shift; printf '%s\n' "$*" >&2; exit "$c"; }
command -v jq >/dev/null || a2a_die 4 "A2A-IO jq is required"
[ -f "$A2A_CFG" ] || a2a_die 4 "A2A-IO no config at $A2A_CFG"
a2a_cfg() { jq -r "$1" "$A2A_CFG"; }
a2a_expand() { case "$1" in [~]/*) printf '%s/%s' "$HOME" "${1#[~]/}" ;; *) printf '%s' "$1" ;; esac; }
A2A_STATE="$(a2a_expand "${A2A_STATE_DIR:-$(a2a_cfg .state_dir)}")"
A2A_LINE_DEFAULT="${A2A_LINE:-$(a2a_cfg .line)}"
HERDR="${HERDR_BIN:-herdr}"
a2a_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
# The queue: $A2A_STATE/queue/<line>/<seat>/<ns>.ptr, one store path per file. delivered/ keeps what went out.
a2a_qdir() { printf '%s/queue/%s/%s' "$A2A_STATE" "$1" "$2"; }
# mkdir is the lock: atomic everywhere, flock is absent from Git Bash (dotfiles Rule 17).
a2a_lock() { local d="$1/.lock" _; for _ in $(seq 1 50); do mkdir "$d" 2>/dev/null && return 0; sleep 0.1; done; return 1; }
a2a_unlock() { rmdir "$1/.lock" 2>/dev/null || true; }
