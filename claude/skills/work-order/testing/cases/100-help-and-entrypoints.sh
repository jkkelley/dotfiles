#!/usr/bin/env bash
# Every entry point at least loads. --help catches a syntax error in a path the
# happy path never touches.
source "${SKILL:-/skill}/testing/assert.sh"

run 0 "--help exits 0" wo --help
run 2 "no arguments is a usage error" wo
run 2 "an unknown command is a usage error" wo nonsense

for c in new approve start submit done close reopen verify resync show list; do
  run 0 "$c --help loads" wo "$c" --help
done

run 0 "the scripts are syntactically valid" bash -n "$SKILL/scripts/work-order.sh"
run 0 "lib/wo.sh is syntactically valid" bash -n "$SKILL/scripts/lib/wo.sh"
run 0 "lib/common.sh is syntactically valid" bash -n "$SKILL/scripts/lib/common.sh"
finish
