#!/usr/bin/env bash
# rail: the vendored Execution Rail template. Each check below exists because of
# a specific way a status page lies to its owner - a row in the wrong project's
# ledger, a page that silently fails to build, a seat publishing to a surface it
# cannot produce. The assertion names the lie it rules out.
CASE_NAME=200-rail
source "${SKILL:-/skill}/testing/assert.sh"

R="$SKILL/references/templates/rail"
ledger_sh() { bash "$R/bin/ledger.sh" "$@"; }
build_sh() { bash "$R/bin/rail-build.sh" "$@"; }

# --- the ledger refuses to guess where it writes.
# The upstream copy defaulted to another project's ledger. A missing export must
# be a loud failure at the first call, with nothing written anywhere.
d="$WORK/rail-noenv"; mkdir -p "$d"
(cd "$d" && env -u RAIL_LEDGER bash "$R/bin/ledger.sh" E-01 started "no ledger set" >/dev/null 2>&1)
assert_eq 1 "$?" "ledger.sh with RAIL_LEDGER unset exits non-zero"
assert_eq "" "$(find "$d" -type f)" "ledger.sh with RAIL_LEDGER unset writes no file"

# --- the ledger's input contract, which is what keeps the page honest.
export RAIL_LEDGER="$WORK/rail-ledger.tsv" RAIL_SEAT=test-seat
run 0 "a well-formed row is appended" ledger_sh E-01 complete "storage refactor green"
assert_contains "$RAIL_LEDGER" $'E-01\tcomplete\tstorage refactor green\ttest-seat' "row carries step, status, text and seat"
run 2 "status outside the six is refused" ledger_sh E-01 finished "x"
run 2 "a step id that is not E-01 shaped is refused" ledger_sh step1 started "x"
run 2 "text over fifteen words is refused" ledger_sh E-02 started "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen"
assert_count 2 "$(wc -l <"$RAIL_LEDGER")" "refused rows never reach the ledger (header + one row)"

# --- the build runs with no jq, because the scaffolded project may have none.
# The precondition is asserted so this check cannot pass in an image that
# happens to carry jq and would hide a regression.
if command -v jq >/dev/null 2>&1; then _fail "precondition: this image must not carry jq" "jq found at $(command -v jq)"; else _pass "precondition: no jq in this image"; fi

plan="$WORK/rail-plan.json"
printf '[{"id":"E-01","t":"Storage refactor","who":"builder","gate":false,"owner":false},{"id":"E-02","t":"Owner signs off","who":"owner","gate":true,"owner":true}]\n' >"$plan"
out="$WORK/rail-out/page.html"; mkdir -p "$(dirname "$out")"
run 0 "page builds from plan and ledger" build_sh --plan "$plan" --ledger "$RAIL_LEDGER" --out "$out" --title "Rail Under Test" --eyebrow "test eyebrow" --source "plan.md"
assert_file "$out" "page file is written"
assert_contains "$out" "Rail Under Test" "title reaches the page"
assert_contains "$out" "Owner signs off" "every plan step reaches the page"
assert_contains "$out" "storage refactor green" "the ledger row reaches the page"
if grep -qE '__[A-Z_]+__' "$out"; then _fail "no template placeholder survives the build" "$(grep -oE '__[A-Z_]+__' "$out" | sort -u | tr '\n' ' ')"; else _pass "no template placeholder survives the build"; fi

# --- a broken plan is a refusal, never a half page.
printf '{"not":"an array"}\n' >"$WORK/rail-bad.json"
run 1 "a plan that is not an array is refused" build_sh --plan "$WORK/rail-bad.json" --ledger "$RAIL_LEDGER" --out "$WORK/rail-out/bad.html"
printf 'not json\n' >"$WORK/rail-bad2.json"
run 1 "a plan that does not parse is refused" build_sh --plan "$WORK/rail-bad2.json" --ledger "$RAIL_LEDGER" --out "$WORK/rail-out/bad2.html"
assert_no_file "$WORK/rail-out/bad.html" "a refused build leaves no page behind"

# --- the wrapper, installed the way a scaffolded project gets it.
proj="$WORK/rail-proj/report"; mkdir -p "$proj"
cp -r "$R/bin" "$R/assets" "$proj/" 2>/dev/null
mkdir -p "$proj/rail" && mv "$proj/bin" "$proj/assets" "$proj/rail/"
sed -e 's/__PROJECT_NAME__/railproj/' -e 's/__RAIL_TITLE__/Rail Proj/' \
    -e 's/__RAIL_EYEBROW__/railproj eyebrow/' -e 's#__RAIL_SOURCE__#docs/plan.md#' \
    "$R/rail.sh.tmpl" >"$proj/rail.sh"
cp "$plan" "$proj/plan.json"
state="$WORK/rail-state"
wrap() { env -u RAIL_LEDGER RAIL_STATE_DIR="$state" bash "$proj/rail.sh" "$@"; }

# Surface routing is data, never a model's judgement. Unset and garbage both
# land on lavish because every runtime can open it; only an explicit artifact
# routes to the Claude-only surface.
assert_eq lavish "$(env -u RAIL_SURFACE RAIL_STATE_DIR="$state" bash "$proj/rail.sh" surface)" "surface defaults to lavish when unset"
assert_eq artifact "$(RAIL_SURFACE=artifact RAIL_STATE_DIR="$state" bash "$proj/rail.sh" surface)" "RAIL_SURFACE=artifact routes to the artifact surface"
assert_eq lavish "$(RAIL_SURFACE=claude-ai RAIL_STATE_DIR="$state" bash "$proj/rail.sh" surface)" "an unknown surface falls back to lavish, never to artifact"

# The wrapper pins the ledger to this project's state directory, so a row
# cannot land in someone else's file even with no export in the shell.
run 0 "wrapper log appends and rebuilds" wrap log E-01 started "wrapper row"
assert_file "$state/ledger.tsv" "wrapper ledger lands in the project's state dir"
assert_contains "$state/ledger.tsv" "wrapper row" "wrapper row is in that ledger"
assert_not_contains "$RAIL_LEDGER" "wrapper row" "wrapper row did not leak into the ledger exported in the shell"
assert_file "$state/page.html" "wrapper rebuilt the page into the state dir"
assert_no_file "$proj/page.html" "the render never lands beside the committed inputs"

finish
