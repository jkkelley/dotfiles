#!/usr/bin/env bash
#
# require-podman.sh - assert the runner has Podman, and say something useful
# when it does not.
#
# Rule 14 puts every suite in this repository inside a container, and every one
# of them reaches for Podman rather than Docker. The plan for this workflow
# assumed the job would have to install it, on the grounds that ubuntu-24.04
# ships Docker. It also ships Podman - 5.8.4 in the runner image as of
# 2026-08-25 - so there is nothing to install, and installing it anyway would
# mean an apt version this repository cannot pin to an immutable identifier the
# way Rule 15 asks.
#
# So this asserts instead. The cost of the assertion is one line of log; the
# cost of not having it is a suite that fails with "podman is required" from
# inside a skill's own test harness, where the missing thing looks like the
# skill's problem rather than the runner's.
set -euo pipefail

if ! command -v podman >/dev/null 2>&1; then
  cat >&2 <<'EOF'
podman is not on this runner.

Every test suite in this repository runs inside a container and reaches for
podman, not docker. The ubuntu-24.04 runner image shipped Podman 5.8.4 when this
workflow was written, so its absence means the runner image changed underneath
us rather than that a step is missing.

Fix it deliberately, in a commit: add an install step, pinned per Rule 15, and
record the version that was checked. Do not fall back to docker - the suites
mount with :Z and run --userns=keep-id, and neither means the same thing there.
EOF
  exit 1
fi

printf 'podman %s\n' "$(podman --version)"
