# shellcheck shell=bash
#
# assert.sh - the assertion vocabulary every case uses.
#
# Assertions are on exit codes and file contents, never on whether some text
# appeared somewhere. A check that passes for the wrong reason is worse than no
# check, so every helper here names what it expected.

set -uo pipefail

: "${SKILL:=/skills/cartography}"
: "${WO_SKILL:=/skills/work-order}"
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
    _fail "$label" "wanted exit $want, got $got" "output: ${out:0:400}"
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

# capture_err <varname> <command...> - stash stderr, for asserting on refusals
capture_err() {
  local __var="$1"
  shift
  local v
  v=$("$@" 2>&1 >/dev/null) || true
  printf -v "$__var" '%s' "$v"
}

assert_eq() {
  local want="$1" got="$2" label="$3"
  if [[ $want == "$got" ]]; then _pass "$label"; else _fail "$label" "wanted: $want" "got:    $got"; fi
}

assert_ne() {
  local a="$1" b="$2" label="$3"
  if [[ $a != "$b" ]]; then _pass "$label"; else _fail "$label" "both were: $a"; fi
}

assert_match() {
  local haystack="$1" needle="$2" label="$3"
  if [[ $haystack == *"$needle"* ]]; then
    _pass "$label"
  else
    _fail "$label" "not found: $needle" "in: ${haystack:0:400}"
  fi
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

carto() { bash "$SKILL/scripts/cartograph.sh" "$@"; }
wo()    { bash "$WO_SKILL/scripts/work-order.sh" "$@"; }

# --- specs ------------------------------------------------------------------
# The macro spec every case starts from: two islands, one depending on the
# other, so the cross-island edge is exercised rather than assumed.
macro_spec() {
  local f="$1"
  cat >"$f" <<'JSON'
{
  "system": {
    "title": "Dropshipping platform",
    "problem": "No system exists yet; the parts have never been drawn together.",
    "out": ["anything requiring a supplier contract"],
    "ac": ["every island has a document and at least one ticket"]
  },
  "overview": "<p>Six islands, one pipeline.</p>",
  "mermaid": "graph TD\n  A[Ingestion] --> B[Storefront]",
  "islands": [
    {"key": "ingestion", "number": 3, "title": "Product Ingestion",
     "summary": "Turns a supplier URL into a normalised product record.",
     "problem": "Supplier data arrives in incompatible shapes.",
     "out": ["storefront rendering"],
     "ac": ["a supplier URL yields a valid product record"]},
    {"key": "storefront", "number": 1, "title": "Storefront Generator",
     "summary": "Builds the shop from committed product records.",
     "problem": "Nothing renders the product records.",
     "out": ["scraping"],
     "ac": ["a committed record produces a page"],
     "depends_on": ["ingestion"]}
  ]
}
JSON
  printf '%s' "$f"
}

# An island spec with one fully-specified ticket and one skeleton - a ticket
# carrying an open question. The pair is the point: the suite has to show the
# two are treated differently.
island_spec() {
  local f="$1"
  cat >"$f" <<'JSON'
{
  "island": "ingestion",
  "overview": "<p>Delegates extraction, normalises, publishes.</p>",
  "diagrams": [{"caption": "The pipeline", "mermaid": "graph TD\n  T[URL] --> O[Orchestrator]"}],
  "tickets": [
    {"key": "scrapers", "title": "Scraper adapters", "type": "feature", "priority": "p1",
     "problem": "Each supplier exposes a different DOM.",
     "in": ["headless browser scripts"], "out": ["bot-protection bypass"],
     "ac": ["a known supplier URL yields title, cost and image URIs"],
     "test_plan": "podman run --rm node:22 npm test -- scrapers"},
    {"key": "orchestrator", "title": "Ingestion orchestrator", "type": "feature",
     "problem": "Nothing routes a URL to the right scraper.",
     "out": ["scraping itself"],
     "ac": ["a POST with supplier_id reaches the matching adapter"],
     "questions": ["is this an n8n webhook or a pod on the cluster?"],
     "depends_on": ["scrapers"]}
  ]
}
JSON
  printf '%s' "$f"
}

# A project with a rendered macro map, returned as "<dir> <system-id>".
planned_project() {
  local d; d=$(new_project)
  macro_spec "$d/macro.json" >/dev/null
  local id
  id=$(carto plan --project "$d" --spec "$d/macro.json" --json 2>/dev/null | jq -r '.system')
  printf '%s %s' "$d" "$id"
}

finish() {
  printf '  %s: %d checks, %d failed\n' "$CASE_NAME" "$TESTS_RUN" "$TESTS_FAILED"
  exit $((TESTS_FAILED > 0 ? 1 : 0))
}
