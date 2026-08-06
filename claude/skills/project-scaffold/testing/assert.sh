# shellcheck shell=bash
#
# assert.sh - the assertion vocabulary every case uses.
#
# Assertions are on exit codes and file contents, never on whether some text
# appeared somewhere. A check that passes for the wrong reason is worse than no
# check, so every helper here names what it expected.

set -uo pipefail

: "${SKILL:=/skill}"
: "${WORK:=/work}"

TESTS_RUN=0
TESTS_FAILED=0
CASE_NAME="${CASE_NAME:-$(basename -- "${BASH_SOURCE[1]:-case}" .sh)}"

_pass() { TESTS_RUN=$((TESTS_RUN + 1)); printf '    ok   %s\n' "$1"; }
_fail() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '    FAIL %s\n' "$1"
  shift
  local l
  for l in "$@"; do printf '         %s\n' "$l"; done
}

# run <expected-exit> <label> <command...>
run() {
  local want="$1" label="$2"
  shift 2
  local out
  out=$("$@" 2>&1)
  local got=$?
  if [[ $got == "$want" ]]; then
    _pass "$label (exit $got)"
  else
    _fail "$label" "wanted exit $want, got $got" "output: ${out:0:300}"
  fi
}

# capture <varname> <command...> - run and stash stdout, ignoring exit code
capture() {
  local __var="$1"
  shift
  local v
  v=$("$@" 2>/dev/null) || true
  printf -v "$__var" '%s' "$v"
}

assert_eq() {
  local want="$1" got="$2" label="$3"
  if [[ $want == "$got" ]]; then _pass "$label"; else _fail "$label" "wanted: $want" "got:    $got"; fi
}

assert_contains() {
  local file="$1" needle="$2" label="$3"
  if grep -qF -- "$needle" "$file" 2>/dev/null; then
    _pass "$label"
  else
    _fail "$label" "not found in $file: $needle"
  fi
}

assert_not_contains() {
  local file="$1" needle="$2" label="$3"
  if grep -qF -- "$needle" "$file" 2>/dev/null; then
    _fail "$label" "unexpectedly found in $file: $needle"
  else
    _pass "$label"
  fi
}

assert_file() {
  local file="$1" label="$2"
  if [[ -f $file ]]; then _pass "$label"; else _fail "$label" "no such file: $file"; fi
}

assert_no_file() {
  local file="$1" label="$2"
  if [[ -e $file ]]; then _fail "$label" "file exists but should not: $file"; else _pass "$label"; fi
}

assert_same() {
  local a="$1" b="$2" label="$3"
  if cmp -s "$a" "$b"; then _pass "$label"; else _fail "$label" "$a and $b differ"; fi
}

assert_count() {
  local want="$1" got="$2" label="$3"
  if [[ $want == "$got" ]]; then _pass "$label"; else _fail "$label" "wanted $want, got $got"; fi
}

# A fresh project directory per test, so no case can depend on another's state.
new_project() {
  local d; d=$(mktemp -d "$WORK/proj.XXXXXX")
  printf '%s' "$d"
}

scaffolded_project() {
  local d; d=$(new_project)
  bash "$SKILL/scripts/scaffold.sh" --project "$d" --apply --yes >/dev/null 2>&1
  printf '%s' "$d"
}

log_issue() { bash "$SKILL/scripts/log-issue.sh" "$@"; }
backlog() { bash "$SKILL/scripts/backlog.sh" "$@"; }
scaffold() { bash "$SKILL/scripts/scaffold.sh" "$@"; }
cache() { bash "$SKILL/scripts/cache.sh" "$@"; }

finish() {
  printf '  %s: %d checks, %d failed\n' "$CASE_NAME" "$TESTS_RUN" "$TESTS_FAILED"
  exit $((TESTS_FAILED > 0 ? 1 : 0))
}
