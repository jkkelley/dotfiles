#!/usr/bin/env bash
# A test plan on a locally built image is named by tag, build command and a digest-pinned Containerfile
# FROM, never by a localhost digest (RR-orch-18, log 20261016-080957-t21e-cards-uat-digest.txt).
#
# A localhost digest names one build on one machine, so every rebuild broke the plans pinned to it.
# What Rule 15 protects is the base image, which the Containerfile FROM pins. start refuses each way
# the local form can be wrong, by its own error name, and passes the right form.
source "${SKILL:-/skill}/testing/assert.sh"

d=$(git_project)
PIN='docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd'
mkdir -p "$d/img"
printf 'FROM %s\n' "$PIN" >"$d/img/Containerfile.pinned"
printf 'FROM debian:bookworm-slim\n' >"$d/img/Containerfile.floating"
git -C "$d" add -A && git -C "$d" commit -qm "fixture containerfiles"

# plan <image> <build> <containerfile> <command> -> a plan file path
plan() {
  local f="$WORK/plan310-$RANDOM.md"
  {
    printf '**Scope under test**\n\nwork-order.sh start on a local image plan\n\n**Cases**\n\n'
    printf -- '- `TP-1`\n  - intent: a plan pinned to a localhost digest stops resolving on rebuild\n'
    printf '  - command: `%s`\n  - expected: exit 0\n\n**Isolation**\n\n- runtime: podman\n- image: `%s`\n' "$4" "$1"
    [ -n "$2" ] && printf -- '- build: `%s`\n' "$2"
    [ -n "$3" ] && printf -- '- containerfile: `%s`\n' "$3"
    printf '\n**Out of scope - CI covers**\n\n- the full suite\n'
  } >"$f"
  printf '%s' "$f"
}
mint() {
  local t="$1" id; shift
  id=$(wo new --project "$d" --title "$t" --type test --top-level --problem P \
         --out "integration" --ac "the plan passes" "$@" 2>/dev/null | tail -1)
  wo approve --project "$d" --id "$id" --no-lavish --reason "suite" >/dev/null 2>&1
  git -C "$d" add -A && git -C "$d" commit -qm "ticket $t"
  printf '%s' "$id"
}
refused() { # <title> <error> <plan>
  local id out
  id=$(mint "$1" --test-plan-file "$3")
  run 3 "start refuses: $1" wo start --project "$d" --id "$id"
  out=$(wo start --project "$d" --id "$id" --json 2>/dev/null)
  assert_eq "$2" "$(jq -r .error <<<"$out")" "and names $2"
}

L=localhost/work-order-test:1
B='make image'
refused "local digest" test_plan_local_digest \
  "$(plan "localhost/work-order-test@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" "$B" img/Containerfile.pinned 'make test')"
refused "local no build" test_plan_local_no_build "$(plan "$L" "" "" 'make test')"
refused "local from unpinned" test_plan_local_from_unpinned "$(plan "$L" "$B" img/Containerfile.floating 'make test')"
refused "local missing containerfile" test_plan_local_from_unpinned "$(plan "$L" "$B" img/nope 'make test')"
refused "local podman run without pull never" test_plan_local_pull "$(plan "$L" "$B" img/Containerfile.pinned "podman run --rm $L true")"

good=$(mint "Local ok" --test-plan-file "$(plan "$L" "$B" img/Containerfile.pinned "podman run --pull=never --rm $L true")")
run 0 "start accepts the local image form" wo start --project "$d" --id "$good"
assert_eq in-progress "$(wo show --project "$d" --id "$good" --json | jq -r .status)" "it reached in-progress"
finish
