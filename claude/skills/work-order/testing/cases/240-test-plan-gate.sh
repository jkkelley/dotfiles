#!/usr/bin/env bash
# The tester runs exactly the plan the architect wrote, so a test ticket may not
# start without one it can run as written (O-10).
#
# Before this gate, ## Test plan held a single free-text line and a tester handed
# a `test` ticket invented its own cases - so the plan that ran was never the
# plan anybody approved. The refusal is at `start` because that is when the
# tester picks the plan up; a draft may still be missing it while it is argued.
source "${SKILL:-/skill}/testing/assert.sh"

d=$(git_project)
plan="$WORK/plan240.md"
cat >"$plan" <<'PLAN'
**Scope under test**

work-order.sh start on a test ticket

**Cases**

- `TP-1`
  - intent: a tester handed no plan would invent one
  - command: `bash testing/run-tests.sh | tail -1`
  - expected: exit 0, the last line reads all cases passed

**Isolation**

- runtime: podman
- image: `docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd` (debian:stable-slim)

**Out of scope - CI covers**

- the full skill suite on every image
PLAN

# mint <title> [new-flags...] -> a ready, committed test ticket's id
mint() {
  local t="$1" id; shift
  id=$(wo new --project "$d" --title "$t" --type test --top-level --problem P \
         --out "integration" --ac "the plan passes" "$@" 2>/dev/null | tail -1)
  wo approve --project "$d" --id "$id" --no-lavish --reason "suite" >/dev/null 2>&1
  git -C "$d" add -A && git -C "$d" commit -qm "ticket $t"
  printf '%s' "$id"
}
status_of() { wo show --project "$d" --id "$1" --json | jq -r .status; }

# --- the refusals --------------------------------------------------------------
none=$(mint "No plan")
run 3 "start refuses a test ticket with no test plan block" wo start --project "$d" --id "$none"
out=$(wo start --project "$d" --id "$none" --json 2>/dev/null)
assert_eq test_plan_missing "$(jq -r .error <<<"$out")" "and names the missing block, not some other refusal"
assert_eq ready "$(status_of "$none")" "the refused ticket is still ready"
assert_eq main "$(git -C "$d" rev-parse --abbrev-ref HEAD)" "and no branch was cut for it"

grep -v -e '^- `TP-1`' -e '^  - ' "$plan" >"$WORK/nocase240.md"
nocase=$(mint "No case" --test-plan-file "$WORK/nocase240.md")
run 3 "start refuses a test plan that has no case" wo start --project "$d" --id "$nocase"
out=$(wo start --project "$d" --id "$nocase" --json 2>/dev/null)
assert_eq test_plan_no_case "$(jq -r .error <<<"$out")" "and names that as the reason"

# --- the pass ------------------------------------------------------------------
good=$(mint "Planned" --test-plan-file "$plan")
f=$(find "$d/work-orders" -name "${good}-*.md")
assert_contains "$f" '  - command: `bash testing/run-tests.sh | tail -1`' "the plan is written into the ticket verbatim"
run 0 "start moves a test ticket with a runnable plan to in-progress" wo start --project "$d" --id "$good"
assert_eq in-progress "$(status_of "$good")" "it reached in-progress"
finish
