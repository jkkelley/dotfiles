#!/usr/bin/env bash
# Every scaffolded project gets the Execution Rail (O-07). 200-rail proves the
# template's engine; this case proves what scaffold.sh puts into a project, run
# the way a seat runs it: ./report/rail.sh from the project root.
#
# Each check names the failure it rules out: a wrapper still naming a
# placeholder, a surface guessed rather than read from RAIL_SURFACE, a log that
# never reaches a page, and a re-run that overwrites the owner's plan.
CASE_NAME=230-rail-install
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)
rail="$p/report/rail.sh"

# --- the files land, and the wrapper is runnable as ./report/rail.sh
assert_file "$rail" "report/rail.sh is installed"
if [[ -x $rail ]]; then _pass "report/rail.sh is executable"; else _fail "report/rail.sh is executable" "mode $(stat -c %a "$rail")"; fi
for f in bin/ledger.sh bin/rail-build.sh assets/template.html; do
  assert_file "$p/report/rail/$f" "engine file report/rail/$f is installed"
done
assert_eq "[]" "$(cat "$p/report/plan.json")" "plan.json starts as an empty array"

# --- no placeholder survives the render. A surviving __PROJECT_NAME__ puts the
# state of every such project into one shared ~/.local/state/__PROJECT_NAME__/.
assert_count 0 "$(grep -cE '__[A-Z][A-Z_]*__' "$rail")" "no __PLACEHOLDER__ survives in rail.sh"
assert_contains "$rail" "PROJECT=\"$(basename "$p")\"" "PROJECT is the project directory's name"
run 0 "rendered rail.sh parses as bash" bash -n "$rail"

# --- the surface is read from RAIL_SURFACE, never inferred.
assert_eq lavish "$(cd "$p" && env -u RAIL_SURFACE ./report/rail.sh surface)" "surface is lavish with RAIL_SURFACE unset"
assert_eq artifact "$(cd "$p" && RAIL_SURFACE=artifact ./report/rail.sh surface)" "surface is artifact with RAIL_SURFACE=artifact"

# --- a log row reaches a built page in the state dir, and nowhere in the repo.
state="$WORK/rail-state"
(cd "$p" && RAIL_STATE_DIR="$state" RAIL_SEAT=test-seat ./report/rail.sh log E-01 started "x" >/dev/null 2>&1)
assert_eq 0 "$?" "rail.sh log E-01 started x exits 0"
assert_contains "$state/ledger.tsv" $'E-01\tstarted\tx\ttest-seat' "the row is in the state dir's ledger"
assert_file "$state/page.html" "log builds the page in the state dir"
assert_contains "$state/page.html" "$(basename "$p") · execution rail" "the eyebrow reaches the page"
assert_count 0 "$(grep -cE '__[A-Z][A-Z_]*__' "$state/page.html")" "no __PLACEHOLDER__ survives in the built page"
assert_eq "" "$(find "$p/report" -name 'ledger.tsv' -o -name 'page.html')" "neither ledger nor page is written into the repo"

# --- a re-run is not allowed to touch what the project now owns.
printf '[{"id":"E-01","t":"Edited by the owner","who":"builder","gate":false,"owner":false}]\n' >"$p/report/plan.json"
printf '# owner edit\n' >>"$rail"
sha256sum "$p/report/plan.json" "$rail" >"$WORK/rail-before"
run 0 "re-run exits 0" scaffold --project "$p" --apply --yes
sha256sum "$p/report/plan.json" "$rail" >"$WORK/rail-after"
assert_same "$WORK/rail-before" "$WORK/rail-after" "re-run leaves an edited plan.json and rail.sh byte-identical"

# --- a directory name that is bash syntax stays data in the wrapper.
q="$WORK/it's \"\$HOME\" & \`x\`"
mkdir -p "$q"
run 0 "scaffold a project whose name carries quotes, dollar, ampersand, backtick" scaffold --project "$q" --apply --yes
run 0 "that wrapper parses as bash" bash -n "$q/report/rail.sh"
got=$(cd "$q" && bash -c 'source <(sed -n "/^PROJECT=/p" report/rail.sh); printf "%s" "$PROJECT"')
assert_eq "$(basename "$q")" "$got" "PROJECT holds the name verbatim, not its expansion"

finish
