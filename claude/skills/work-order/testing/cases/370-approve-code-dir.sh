#!/usr/bin/env bash
# rolodex: header drafted by scripts/rolodex.py headers - correct any line that is wrong
# name: 370-approve-code-dir.sh
# purpose: Assert approve --code-dir resolves step and AC tools in the checkout of the ticket repo (WO-20261016-e297).
# inputs: env SKILL (skill root, default /skill); sourced assert.sh helpers
# outputs: exit code 0 when every assertion passes, assertion lines on stdout
# writes-to: scratch project and code-repo dirs under $WORK (mktemp), removed with the test sandbox
# cleanup: the sandbox container is discarded; nothing outside $WORK is touched
# The reason this case exists.
#
# yp-design6 repro: a business ticket whose code lives in another repo names a
# target of that repo's Makefile, and approve refused it with tool_missing lint
# because it looked in the ticket project. With a ticket repo set, approve needs
# --code-dir, a checkout whose origin is that repo, and resolves tools there.
source "${SKILL:-/skill}/testing/assert.sh"

d=$(git_project)
code=$(git_project)
printf 'lint:\n\t@true\n' >"$code/Makefile"
git -C "$code" add -A && git -C "$code" commit -qm "makefile" && git -C "$code" push -q origin main
other=$(git_project)
printf 'lint:\n\t@true\n' >"$other/Makefile"
git -C "$other" add -A && git -C "$other" commit -qm "makefile" && git -C "$other" push -q origin main
git -C "$code" remote set-url origin git@github.com:acme/code.git
git -C "$other" remote set-url origin https://github.com/acme/else.git

mk() { # mk <title> [extra new args...]
  local t="$1"; shift
  wo new --project "$d" --title "$t" --type feature --problem P --top-level --out X --ac ok "$@" >/dev/null
  wo list --project "$d" --json | jq -r --arg t "$t" '.[] | select(.title == $t) | .id'
}
appr() { local i="$1"; shift; wo approve --project "$d" --id "$i" --no-lavish --reason "no lavish in CI" "$@"; }
err() { local i="$1"; shift; wo approve --project "$d" --id "$i" --no-lavish --reason r --json "$@" 2>&1 | jq -r '.error // .status'; }
has() { if [[ $1 == "$2" ]]; then _pass "$3"; else _fail "$3" "wanted $2" "got: ${1:0:200}"; fi; }

id=$(mk "Cross repo" --repo acme/code --ac "lint" --ac-check "make lint" --ac-exit 0)
run 2 "a ticket with a repo and no --code-dir exits 2" appr "$id"
has "$(err "$id")" code_dir_required "the refusal is code_dir_required, not tool_missing"
run 3 "a checkout whose origin differs exits 3" appr "$id" --code-dir "$other"
has "$(err "$id" --code-dir "$other")" code_dir_mismatch "the refusal is code_dir_mismatch"
run 0 "the mismatch message prints both repos" bash -c \
  "bash '$SKILL/scripts/work-order.sh' approve --project '$d' --id '$id' --no-lavish --reason r --code-dir '$other' --json 2>&1 | jq -e '.message | contains(\"acme/code\") and contains(\"acme/else\")' >/dev/null"
run 0 "the ticket stays draft after the refusals" bash -c \
  "bash '$SKILL/scripts/work-order.sh' show --project '$d' --id '$id' --json | jq -e '.status == \"draft\"' >/dev/null"
run 0 "an ssh origin matches and the tool resolves in the code checkout" appr "$id" --code-dir "$code"
run 0 "the ticket is ready" bash -c \
  "bash '$SKILL/scripts/work-order.sh' show --project '$d' --id '$id' --json | jq -e '.status == \"ready\"' >/dev/null"

git -C "$code" remote set-url origin https://github.com/acme/code.git
id=$(mk "Cross repo https" --repo acme/code --ac "lint" --ac-check "make lint" --ac-exit 0)
run 0 "an https origin matches" appr "$id" --code-dir "$code"

git -C "$code" remote set-url origin https://github.com/acme/code
id=$(mk "Cross repo bare" --repo acme/code --ac "lint" --ac-check "make lint" --ac-exit 0)
run 0 "an https origin without .git matches" appr "$id" --code-dir "$code"

id=$(mk "Cross repo missing target" --repo acme/code --ac "zeta" --ac-check "make zeta" --ac-exit 0)
run 3 "a target absent from the code checkout is still tool_missing" appr "$id" --code-dir "$code"

id=$(mk "No repo" --ac "lint" --ac-check "make lint" --ac-exit 0)
run 2 "--code-dir on a ticket with no repo exits 2" appr "$id" --code-dir "$code"
has "$(err "$id" --code-dir "$code")" code_dir_without_repo "the refusal is code_dir_without_repo"
run 3 "without --code-dir resolution stays in the project (case 280)" appr "$id"
finish
