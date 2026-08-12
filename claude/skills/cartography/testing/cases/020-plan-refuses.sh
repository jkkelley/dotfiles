#!/usr/bin/env bash
#
# What plan refuses, and - just as important - that a refusal writes nothing.
#
# A half-planned system is the worst outcome this script can produce: a system
# epic exists, some islands are under it, and re-running is blocked by the very
# map file the failed run left behind. So every refusal is checked for its
# side effects, not only its exit code.

CASE_NAME=020-plan-refuses
source "${SKILL:-/skills/cartography}/testing/assert.sh"

# --- an island with no acceptance criteria ----------------------------------
# This is the refusal the whole skeleton design rests on. work-order takes --ac
# at mint time only, so a ticket minted without one can never be approved and no
# later command can repair it. Catching it here is the difference between a
# skeleton and a dead ticket.
D=$(new_project)
cat >"$D/spec.json" <<'JSON'
{"system": {"title": "S", "problem": "p", "out": ["o"], "ac": ["done"]},
 "islands": [{"key": "a", "number": 1, "title": "A", "problem": "p", "out": ["o"]}]}
JSON
run 3 "an island with no ac is refused" carto plan --project "$D" --spec "$D/spec.json"
capture_err MSG carto plan --project "$D" --spec "$D/spec.json"
assert_match "$MSG" "can never be approved" "the refusal explains why, not just that"
assert_match "$MSG" "questions" "the refusal names the field that takes the unknown part"
assert_no_file "$D/work-orders" "a refused plan mints no tickets at all"
assert_no_file "$D/cartography" "a refused plan leaves no cartography directory"

# --- the system epic itself needs one ---------------------------------------
D2=$(new_project)
cat >"$D2/spec.json" <<'JSON'
{"system": {"title": "S", "problem": "p", "out": ["o"]},
 "islands": [{"key": "a", "number": 1, "title": "A", "problem": "p", "out": ["o"], "ac": ["x"]}]}
JSON
run 3 "a system epic with no ac is refused" carto plan --project "$D2" --spec "$D2/spec.json"
assert_no_file "$D2/work-orders" "and mints nothing"

# --- no islands -------------------------------------------------------------
D3=$(new_project)
cat >"$D3/spec.json" <<'JSON'
{"system": {"title": "S", "problem": "p", "out": ["o"], "ac": ["x"]}, "islands": []}
JSON
run 3 "a map with no islands is refused" carto plan --project "$D3" --spec "$D3/spec.json"

# --- duplicate island keys --------------------------------------------------
# Keys are how every later command addresses an island. Two islands sharing one
# would make the second silently unreachable.
D4=$(new_project)
cat >"$D4/spec.json" <<'JSON'
{"system": {"title": "S", "problem": "p", "out": ["o"], "ac": ["x"]},
 "islands": [{"key": "a", "number": 1, "title": "A", "problem": "p", "out": ["o"], "ac": ["x"]},
             {"key": "a", "number": 2, "title": "B", "problem": "p", "out": ["o"], "ac": ["x"]}]}
JSON
run 3 "a duplicate island key is refused" carto plan --project "$D4" --spec "$D4/spec.json"

# --- a dependency on an island that is not in the spec ----------------------
D5=$(new_project)
cat >"$D5/spec.json" <<'JSON'
{"system": {"title": "S", "problem": "p", "out": ["o"], "ac": ["x"]},
 "islands": [{"key": "a", "number": 1, "title": "A", "problem": "p", "out": ["o"],
              "ac": ["x"], "depends_on": ["ghost"]}]}
JSON
run 6 "a dependency on an unknown island is refused" carto plan --project "$D5" --spec "$D5/spec.json"

# --- malformed and missing input --------------------------------------------
D6=$(new_project)
printf 'not json at all\n' >"$D6/spec.json"
run 3 "a spec that is not JSON is refused" carto plan --project "$D6" --spec "$D6/spec.json"
run 4 "a spec that does not exist is refused" carto plan --project "$D6" --spec "$D6/absent.json"
run 2 "plan with no --spec is a usage error" carto plan --project "$D6"

# --- planning twice ---------------------------------------------------------
# The one mistake `link` cannot undo: a second system epic over the same map.
read -r DIR SYS <<<"$(planned_project)"
run 3 "planning a second time is refused" carto plan --project "$DIR" --spec "$DIR/macro.json"
capture COUNT bash -c "find '$DIR/work-orders' -name 'WO-*.md' | wc -l"
assert_eq "3" "$COUNT" "the refused re-plan minted nothing: still one system and two islands"

finish
