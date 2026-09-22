#!/usr/bin/env bash
# session-arm.sh - SessionStart hook, matcher "startup|resume": arm this session's compaction watcher.
#
# BREADCRUMB - why arming happens at session start and not only in the spawner.
# What broke: bin/workflow-spawn.sh arms every seat it starts, but the principal is started by the owner, and a seat
#   restarted by hand after a crash is started by nobody the spawner knows about. Both ran unwatched.
# Why it mattered: the seat the owner talks to is the one with the longest conversation, so it is the most likely to
#   run out of context, and it was the one seat guaranteed to have no watcher.
# Why this fix: every session that starts in this repository inside herdr arms itself. `watch-ctl.sh on` is idempotent,
#   so a spawned seat that is already armed is left alone. Rejected: a reminder in CLAUDE.md, which is prose.
# Cost: the first session start in a herdr session opens a `monitors` tab. Outside herdr nothing is armed and the
#   hook says so in one line, per Rule 18, rather than backgrounding a watcher.
# Never fails the session: a hook that exits non-zero at startup is worse than an unarmed watcher.
set -uo pipefail
BIN="$(dirname "$(readlink -f "$0")")"
if [ "${HERDR_ENV:-}" != 1 ] || [ -z "${HERDR_PANE_ID:-}" ]; then
  printf 'compaction watcher: not armed, this session is not in a herdr pane (dotfiles Rule 18).\n'; exit 0
fi
out="$("$BIN/watch-ctl.sh" on compact "$HERDR_PANE_ID" 2>&1)" \
  && printf 'compaction watcher: %s\n' "$out" \
  || printf 'compaction watcher: FAILED to arm for %s: %s\n' "$HERDR_PANE_ID" "$out"
exit 0
