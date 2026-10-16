#!/usr/bin/env bash
# The reason this case exists.
#
# ORD-0555: a ready ticket that names a command or Make target which is not on
# main sends a build seat off to invent it. approve resolves every backticked
# command in the In step: lines and every ac_check command, and refuses
# (exit 3, tool_missing) while one does not resolve. A tool the ticket itself
# creates is listed under --provides.
source "${SKILL:-/skill}/testing/assert.sh"

d=$(git_project)
mkdir -p "$d/sub"
printf 'alpha:\n\t@true\n' >"$d/sub/Makefile"
printf 'beta: alpha\n\t@true\n' >"$d/sub/more.mk"
printf 'include more.mk\n' >>"$d/sub/Makefile"
printf '#!/bin/sh\n' >"$d/tool.sh"
git -C "$d" add -A && git -C "$d" commit -qm "tools" && git -C "$d" push -q origin main

mk() { # mk <title> [extra new args...]
  local t="$1"; shift
  wo new --project "$d" --title "$t" --type feature --problem P --top-level --out X --ac ok "$@" >/dev/null
  wo list --project "$d" --json | jq -r --arg t "$t" '.[] | select(.title == $t) | .id'
}
appr() { wo approve --project "$d" --id "$1" --no-lavish --reason "no lavish in CI"; }

id=$(mk "Resolves" --in 'step: run `make -C sub alpha` then `make -C sub beta` then `bash tool.sh` then `git status`')
run 0 "approve passes when make targets (one via include), a script and a command all resolve" appr "$id"

id=$(mk "Missing target" --in 'step: run `make -C sub gamma`')
run 3 "approve refuses a make target that is not on main" appr "$id"
run 0 "the refusal is tool_missing and names the target" bash -c \
  "bash '$SKILL/scripts/work-order.sh' approve --project '$d' --id '$id' --no-lavish --reason r --json 2>&1 | jq -e '.error == \"tool_missing\" and (.message | contains(\"gamma\"))' >/dev/null"
run 0 "the ticket stays draft" bash -c \
  "bash '$SKILL/scripts/work-order.sh' show --project '$d' --id '$id' --json | jq -e '.status == \"draft\"' >/dev/null"

id=$(mk "Provided target" --in 'step: run `make -C sub gamma`' --provides gamma)
run 0 "approve passes a target listed under provides" appr "$id"

id=$(mk "Missing script" --in 'step: run `bash nope.sh`')
run 3 "approve refuses a script that is not on main" appr "$id"

id=$(mk "Missing command" --in 'step: run `no-such-binary-xyz --flag`')
run 3 "approve refuses a command that does not resolve" appr "$id"

id=$(mk "Bad check" --ac "x" --ac-check "make -C sub zeta" --ac-exit 0)
run 3 "approve refuses an ac_check that calls a missing target" appr "$id"

id=$(mk "Untracked is not main" --in 'step: run `bash local-only.sh`')
printf '#!/bin/sh\n' >"$d/local-only.sh"
run 3 "a file only in the working tree does not count as on main" appr "$id"
finish
