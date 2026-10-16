#!/usr/bin/env bash
# AC-H3: tests/run.sh selects suites from changed paths. Uses a fixture table so the real suites never run here.
# Rules out: `make test` running everything on every edit (the cost the selector exists to remove), `--changed` with no
# change silently running or silently printing nothing, a path outside the sweep selecting a suite, and a failing
# suite being swallowed.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
P=claude/workflow/inbox-sweep
printf '%s\t%s\t%s\n' \
  cards 'bin/sweep-cards.sh' 'echo cards-ran' \
  clean 'bin/sweep-clean.sh' 'echo clean-ran' \
  herdr-first 'bin/' 'echo hf-ran' \
  schemas 'schemas/,tests/fixtures/results/' 'echo schemas-ran' \
  broken 'tests/broken.sh' 'echo boom; exit 1' > "$T/suites.tsv"
export SWEEP_SUITES="$T/suites.tsv"
run() { bash "$R/tests/run.sh" "$@" 2>&1; }

out="$(SWEEP_CHANGED="" run --changed)"; rc=$?
check "ran 0 suites" "$out" "no change prints exactly: ran 0 suites"
check 0 "$rc" "no change exits 0"

out="$(SWEEP_CHANGED="$P/bin/sweep-cards.sh" run --changed)"
check "ok  cards
ok  herdr-first
ran 2 suites" "$out" "a change to bin/sweep-cards.sh runs the cards suite and herdr-first, nothing else"

out="$(SWEEP_CHANGED="$P/schemas/result.schema.json" run --changed)"
check "ok  schemas
ran 1 suite" "$out" "a directory entry selects by prefix; one suite is singular"

out="$(SWEEP_CHANGED="docs/design/inbox-sweep.md
README.md" run --changed)"
check "ran 0 suites" "$out" "paths outside the sweep select nothing"

out="$(SWEEP_CHANGED="$P/bin/sweep-cards.sh-not" run --changed)"
check "ok  herdr-first
ran 1 suite" "$out" "a file entry matches exactly, not by prefix (only the bin/ directory entry hits)"

printf '%s\n' "$P/bin/sweep-clean.sh" | { out="$(run --changed)"; check "ok  clean
ok  herdr-first
ran 2 suites" "$out" "without SWEEP_CHANGED the paths are read from stdin"; }

out="$(run --all)"
check "ok  cards
ok  clean
ok  herdr-first
ok  schemas
FAIL broken
     boom
ran 5 suites, 1 failed" "$out" "--all runs every suite, shows a failing suite's output, and counts it"
run --all >/dev/null; check 1 "$?" "a failing suite makes the run exit 1"

out="$(run --suite clean)"; check "ok  clean
ran 1 suite" "$out" "--suite runs one suite"
run --suite nope >/dev/null; check 2 "$?" "--suite with an unknown name exits 2"
run >/dev/null; check 2 "$?" "no mode exits 2"
run --bogus >/dev/null; check 2 "$?" "an unknown mode exits 2"

unset SWEEP_SUITES
while IFS=$'\t' read -r s _; do
  [ -f "$R/tests/unit/test_${s//-/_}.sh" ] || [ "$s" = lint ] || bad "real suite $s has a test file"
done <"$R/tests/suites.tsv"
check 5 "$(wc -l <"$R/tests/suites.tsv")" "the real table lists the five B0 suites"
finish
