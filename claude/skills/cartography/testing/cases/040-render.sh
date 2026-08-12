#!/usr/bin/env bash
#
# render mints nothing and tells the truth about status.
#
# The point of separating render from island is that a map can be rebuilt at any
# time without touching the ticket tree. Both halves of that are checked: that a
# re-render is byte-identical when nothing moved, and that it is *not* identical
# when a ticket did move - a renderer that cached would pass the first check and
# be useless.

CASE_NAME=040-render
source "${SKILL:-/skills/cartography}/testing/assert.sh"

read -r DIR SYS <<<"$(planned_project)"
island_spec "$DIR/ingestion.json" >/dev/null
carto island --project "$DIR" --spec "$DIR/ingestion.json" >/dev/null 2>&1

HTML="$DIR/cartography/003-product-ingestion.html"
MACRO="$DIR/cartography/000-macro-map.html"
cp "$HTML" "$WORK/before.html"
cp "$MACRO" "$WORK/before-macro.html"
capture BEFORE bash -c "find '$DIR/work-orders' -name 'WO-*.md' | wc -l"

# --- idempotence ------------------------------------------------------------
run 0 "render succeeds with no arguments" carto render --project "$DIR"
assert_same "$WORK/before.html" "$HTML" "a re-render with nothing changed is byte-identical"
assert_same "$WORK/before-macro.html" "$MACRO" "and so is the macro map"

capture AFTER bash -c "find '$DIR/work-orders' -name 'WO-*.md' | wc -l"
assert_eq "$BEFORE" "$AFTER" "render mints nothing"

# --- status is read at render time, not frozen at mint time -----------------
capture ORCH jq -r '.tickets["ingestion/orchestrator"].id' "$DIR/cartography/.map.json"
assert_contains "$HTML" '<span class="badge draft">draft</span>' "the ticket renders as draft before it moves"

wo resolve --project "$DIR" --id "$ORCH" --index 1 --answer "a pod" >/dev/null 2>&1
wo approve --project "$DIR" --id "$ORCH" --no-lavish --reason "test" >/dev/null 2>&1
run 0 "render after a status change succeeds" carto render --project "$DIR" --island ingestion
assert_contains "$HTML" '<span class="badge ready">ready</span>' "the document now shows the ticket as ready"

# The resolved question is ticked in the ticket, so the document must stop
# calling it a skeleton. A map that kept the orange flag after the question was
# answered would be lying in the direction that matters most.
capture SKEL bash -c "grep -c 'ticket skeleton' '$HTML' || true"
assert_eq "0" "$SKEL" "the graduated ticket is no longer marked a skeleton"

# --- render before any island is cut ----------------------------------------
# The macro map must render from plan alone, with every island still pending.
read -r D2 _ <<<"$(planned_project)"
run 0 "render works on a plan with no islands cut yet" carto render --project "$D2"
assert_contains "$D2/cartography/000-macro-map.html" "Not yet blueprinted" "an un-cut island says so"

# --- render outside a planned project ---------------------------------------
D3=$(new_project)
run 6 "render with no map is refused" carto render --project "$D3"
run 6 "ledger with no map is refused" carto ledger --project "$D3"

# --- an unknown island ------------------------------------------------------
run 6 "render of an unknown island is refused" carto render --project "$DIR" --island ghost

finish
