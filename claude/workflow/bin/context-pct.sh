#!/usr/bin/env bash
# context-pct.sh <pane|transcript.jsonl> - percent of the context window a seat occupies now.
# Thin wrapper over wf_context_pct so a runbook and a human read the same number the watcher acts on.
# CONTEXT_WINDOW overrides the 1M default for a seat on a smaller window.
set -uo pipefail
# shellcheck source=bin/workflow-lib.sh disable=SC1091
. "$(dirname "$(readlink -f "$0")")/workflow-lib.sh"
wf_need jq
[ $# -ge 1 ] || wf_die "usage: context-pct.sh <pane|transcript.jsonl>"
tr="$(wf_transcript "$1")" || wf_die "no transcript for $1"
wf_context_pct "$tr"; echo
