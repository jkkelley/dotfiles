#!/usr/bin/env bash
#
# run-tests.sh - the only entry point for this skill's test suite.
#
# Everything runs inside Podman, per root CLAUDE.md Rule 14. The flags are not
# ceremony; each one proves a specific property:
#
#   --network=none      no case reaches the network
#   /skill mounted ro   no script writes next to itself
#   /work separate      every output lands where documented
#   --userns=keep-id    files in the scratch mount are owned by you, not root
#   SCAFFOLD_NOW        the clock is fixed, so determinism is provable
#
# The scratch directory is removed on every exit path, including a failure or a
# Ctrl-C. Nothing this suite creates outlives it.

set -euo pipefail

SKILL_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
IMAGE="${PS_TEST_IMAGE:-docker.io/library/debian:stable-slim}"

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/project-scaffold-test.XXXXXX")
cleanup() { rm -rf -- "$SCRATCH"; }
trap cleanup EXIT INT TERM

command -v podman >/dev/null 2>&1 || {
  printf 'podman is required: every check in this suite runs in a container.\n' >&2
  printf 'Running these on the host would prove only that they work on this machine.\n' >&2
  exit 1
}

printf 'project-scaffold test suite\n'
printf '  image:   %s\n' "$IMAGE"
printf '  skill:   %s (read-only)\n' "$SKILL_DIR"
printf '  scratch: %s (removed on exit)\n\n' "$SCRATCH"

# The read-only mount is what stops a script writing next to itself, but proving
# it means comparing the directory before and after rather than trusting the
# flag. Snapshot first.
before=$(find "$SKILL_DIR" -type f | sort)

# bash, not sh: the scripts use arrays, [[ ]], mapfile and PIPESTATUS. The
# image's /bin/sh is dash and would fail on all of them.
podman run --rm --userns=keep-id --network=none \
  -v "$SKILL_DIR:/skill:ro,Z" \
  -v "$SCRATCH:/work:Z" \
  -w /work \
  -e SKILL=/skill \
  -e WORK=/work \
  -e SCAFFOLD_NOW=2026-08-05T14:32:11-05:00 \
  "$IMAGE" \
  bash -c '
    set -u
    failed=0
    for case_file in /skill/testing/cases/*.sh; do
      printf "\n  %s\n" "$(basename "$case_file")"
      if ! bash "$case_file"; then failed=$((failed + 1)); fi
    done
    printf "\n"
    if ((failed)); then
      printf "%d case file(s) FAILED\n" "$failed"
      exit 1
    fi
    printf "all cases passed\n"
  '

rc=$?

after=$(find "$SKILL_DIR" -type f | sort)
if [[ $before != "$after" ]]; then
  printf '\nFAIL: the skill directory changed during the run - a script wrote beside itself:\n' >&2
  diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") >&2 || true
  exit 1
fi

exit $rc
