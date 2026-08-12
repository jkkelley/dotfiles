#!/usr/bin/env bash
#
# run-tests.sh - the only entry point for this skill's test suite.
#
# Everything runs inside Podman, per root CLAUDE.md Rule 14:
#
#   --network=none      no case reaches the network
#   /skills mounted ro  no script writes next to itself
#   /work separate      every output lands where documented
#   --userns=keep-id    files in the scratch mount are owned by you, not root
#   SCAFFOLD_NOW        the clock is fixed, so determinism is provable
#
# The mount is the *skills* directory rather than this skill alone, deliberately.
# cartograph finds work-order as a sibling, and a suite that mounted work-order
# somewhere artificial and pointed CARTO_WORK_ORDER at it would leave the real
# resolution path - the one every user hits - untested.

set -euo pipefail

SKILL_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SKILLS_DIR=$(cd -- "$SKILL_DIR/.." && pwd)
IMAGE="${CARTO_TEST_IMAGE:-localhost/cartography-test:1}"

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/cartography-test.XXXXXX")
cleanup() { rm -rf -- "$SCRATCH"; }
trap cleanup EXIT INT TERM

command -v podman >/dev/null 2>&1 || {
  printf 'podman is required: every check in this suite runs in a container.\n' >&2
  printf 'Running these on the host would prove only that they work on this machine.\n' >&2
  exit 1
}

[[ -r $SKILLS_DIR/work-order/scripts/work-order.sh ]] || {
  printf 'work-order is not a sibling of this skill: %s\n' "$SKILLS_DIR" >&2
  printf 'cartography mints every ticket through work-order and cannot be tested without it.\n' >&2
  exit 1
}

# Build only when the image is absent. The Containerfile pins its base by digest,
# so a rebuild produces the same image rather than silently picking up a newer
# debian point release mid-review.
if ! podman image exists "$IMAGE"; then
  printf 'building %s (needs network; the cases themselves run with --network=none)\n' "$IMAGE"
  podman build -t "$IMAGE" -f "$SKILL_DIR/testing/Containerfile" "$SKILL_DIR/testing" >/dev/null
fi

printf 'cartography test suite\n'
printf '  image:   %s\n' "$IMAGE"
printf '  skills:  %s (read-only)\n' "$SKILLS_DIR"
printf '  scratch: %s (removed on exit)\n\n' "$SCRATCH"

before=$(find "$SKILL_DIR" -type f | sort)

podman run --rm --userns=keep-id --network=none \
  -v "$SKILLS_DIR:/skills:ro,Z" \
  -v "$SCRATCH:/work:Z" \
  -w /work \
  -e SKILL=/skills/cartography \
  -e WO_SKILL=/skills/work-order \
  -e WORK=/work \
  -e SCAFFOLD_NOW=2026-08-05T14:32:11-05:00 \
  "$IMAGE" \
  bash -c '
    set -uo pipefail
    failed=0
    : >/work/.results
    for case_file in /skills/cartography/testing/cases/*.sh; do
      printf "\n  %s\n" "$(basename "$case_file")"
      if bash "$case_file" | tee -a /work/.results; then :; else failed=$((failed + 1)); fi
    done
    # Totals are computed from the run, never hand-maintained. A count in a
    # commit message or a PR body goes stale the moment a case is added.
    files=$(ls /skills/cartography/testing/cases/*.sh | wc -l)
    checks=$(awk -F"[ ,]+" "/checks, [0-9]+ failed\$/ { for (i=1;i<=NF;i++) if (\$(i+1)==\"checks\") t+=\$i } END { print t+0 }" /work/.results)
    printf "\n"
    if ((failed)); then
      printf "%d of %d case file(s) FAILED\n" "$failed" "$files"
      exit 1
    fi
    printf "all cases passed: %s checks across %s case files\n" "$checks" "$files"
  '

rc=$?

after=$(find "$SKILL_DIR" -type f | sort)
if [[ $before != "$after" ]]; then
  printf '\nFAIL: the skill directory changed during the run - a script wrote beside itself:\n' >&2
  diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") >&2 || true
  exit 1
fi

exit $rc
