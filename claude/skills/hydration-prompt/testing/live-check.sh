#!/usr/bin/env bash
# live-check.sh - slot.sh against the real treehouse binary.
#
#   bash claude/skills/hydration-prompt/testing/live-check.sh
#
# WHY THIS EXISTS SEPARATELY FROM run-tests.sh.
# run-tests.sh stubs treehouse, which is right: treehouse's answer is the input
# under test, and a stub is the only way to script a return that exits 0 without
# freeing anything. But a stub proves how slot.sh reacts to an answer. It cannot
# prove treehouse still gives that answer.
#
# That is not a small gap here. The entire design rests on one observed
# behaviour - `treehouse return` prompts on a dirty worktree, takes its no-TTY
# default, abandons the return, leaves the slot leased and exits 0 - and if a
# future treehouse fixed that, run-tests.sh would stay green while its central
# fixture described a world that no longer exists. This is the half that asks
# the real binary.
#
# Per container-sandbox's "Verifying a host CLI's behaviour": the real binary is
# bind-mounted read-only rather than installed, so the build under test is the
# one on this machine, and TREEHOUSE_ROOT is redirected inside the container, so
# the live pool is never touched. The last case asserts that redirection held.
#
# Not run by the pull request gate: it needs a binary that no runner has.
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SKILL=$(cd -- "$HERE/.." && pwd)
TH=${TREEHOUSE_BIN:-$HOME/.local/bin/treehouse}

# Pinned by digest per root CLAUDE.md Rule 15. The same digest the gate runs the
# wrapped suites on - a second digest for the same purpose is how a repository
# ends up with two answers to "what do the tests run on".
IMAGE="docker.io/bitnami/git@sha256:1baa6ddbde79fa7ba2fdf441cea47c4f04fae067504d9265e416358db0879ab2"

[[ -x $TH ]] || { printf 'live-check: no treehouse at %s\n' "$TH" >&2; exit 4; }
printf 'live-check: treehouse %s at %s\n' "$("$TH" --version 2>&1)" "$TH"

SCRATCH=$(mktemp -d); trap 'rm -rf "$SCRATCH"' EXIT

podman run --rm --userns=keep-id --network=none --entrypoint="" \
  -v "$SKILL:/skill:ro,Z" \
  -v "$TH:/usr/local/bin/treehouse:ro,Z" \
  -v "$SCRATCH:/work:Z" -w /work \
  "$IMAGE" bash /skill/testing/live-inner.sh
