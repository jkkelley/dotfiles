#!/usr/bin/env bash
# rolodex: header drafted by scripts/rolodex.py headers - correct any line that is wrong
# name: 420-code-dir-checks.sh
# purpose: Assert check and done run a cross-repo ticket's checks in --code-dir and refuse code_dir_required or code_dir_mismatch (WO-20261016-1099).
# inputs: env SKILL (skill root, default /skill); sourced assert.sh helpers
# outputs: exit code 0 when every assertion passes, assertion lines on stdout
# writes-to: scratch project and code-repo dirs under $WORK (mktemp), removed with the test sandbox
# cleanup: the sandbox container is discarded; nothing outside $WORK is touched
# The reason this case exists.
#
# WO-20261016-2d63 repro: a business ticket whose code lives in another repo ran
# its checks in the business tree, where the marker file is absent, so done failed
# although the work passed in the code worktree. With a ticket repo set, check and
# done need --code-dir, a checkout whose origin is that repo, and run there.
source "${SKILL:-/skill}/testing/assert.sh"

d=$(git_project)
code=$(git_project)
other=$(git_project)
printf 'x\n' >"$code/marker"
git -C "$code" add -A && git -C "$code" commit -qm "marker" && git -C "$code" push -q origin main
git -C "$code" remote set-url origin git@github.com:acme/code.git
git -C "$other" remote set-url origin https://github.com/acme/else.git

err() { wo "$@" --json 2>&1 | jq -r '.error // .status'; }
has() { if [[ $1 == "$2" ]]; then _pass "$3"; else _fail "$3" "wanted $2" "got: ${1:0:200}"; fi; }
mk() { # mk <title> [extra new args...]
  local t="$1"; shift
  wo new --project "$d" --title "$t" --type feature --problem P --top-level --out X --ac "marker" --ac-check "test -f marker" --ac-exit 0 "$@" >/dev/null
  wo list --project "$d" --json | jq -r --arg t "$t" '.[] | select(.title == $t) | .id'
}

id=$(mk "Cross repo" --repo acme/code)
wo approve --project "$d" --id "$id" --no-lavish --reason r --code-dir "$code" >/dev/null
wo start --project "$d" --id "$id" >/dev/null

run 2 "check on a repo ticket without --code-dir exits 2" wo check --project "$d" --id "$id"
has "$(err check --project "$d" --id "$id")" code_dir_required "the refusal is code_dir_required"
run 3 "check with a checkout of another repo exits 3" wo check --project "$d" --id "$id" --code-dir "$other"
has "$(err check --project "$d" --id "$id" --code-dir "$other")" code_dir_mismatch "the refusal is code_dir_mismatch"
run 0 "check with the right dir passes the marker check" wo check --project "$d" --id "$id" --code-dir "$code"
run 0 "check prints AC-PASS 1" bash -c \
  "bash '$SKILL/scripts/work-order.sh' check --project '$d' --id '$id' --code-dir '$code' | grep -qx 'AC-PASS 1'"
run 2 "done on a repo ticket without --code-dir exits 2" wo done --project "$d" --id "$id"

id2=$(mk "No repo")
wo approve --project "$d" --id "$id2" --no-lavish --reason r >/dev/null
wo start --project "$d" --id "$id2" >/dev/null
printf 'x\n' >"$d/marker"
run 0 "a ticket without a repo checks in the project as before" wo check --project "$d" --id "$id2"
finish
