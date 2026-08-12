#!/usr/bin/env bash
#
# The skeleton contract - this is the case the whole skill exists to justify.
#
# A cartography ticket is minted during planning, before anyone has written the
# work. The claim is that such a ticket is safe to leave lying in the tree
# because work-order's own gates hold it shut. Every assertion below is a test of
# that claim, and none of them is about HTML.

CASE_NAME=030-island-skeleton
source "${SKILL:-/skills/cartography}/testing/assert.sh"

read -r DIR SYS <<<"$(planned_project)"
island_spec "$DIR/ingestion.json" >/dev/null

capture OUT carto island --project "$DIR" --spec "$DIR/ingestion.json" --json
capture SCRAPER jq -r '.tickets[0]' <<<"$OUT"
capture ORCH jq -r '.tickets[1]' <<<"$OUT"

assert_match "$SCRAPER" "WO-" "the fully-specified ticket was minted"
assert_match "$ORCH" "WO-" "the skeleton ticket was minted too"
assert_file "$DIR/cartography/003-product-ingestion.html" "the island document is numbered and slugged from the map"

# Both tickets are filed under the island epic, so `tree` shows the shape the
# map drew rather than a flat pile.
capture ING jq -r '.islands.ingestion.id' "$DIR/cartography/.map.json"
capture FM wo show --project "$DIR" --id "$ORCH" --json
assert_match "$FM" "\"parent\": \"$ING\"" "the ticket is filed under its island epic"

# --- the gate ---------------------------------------------------------------
# The skeleton carries an open question, so approve must refuse it. If this ever
# passes, cartography is minting tickets that an agent can pick up as real work
# when nobody has written the work yet.
run 3 "approve refuses the skeleton while its question is open" \
  wo approve --project "$DIR" --id "$ORCH" --no-lavish --reason "test"

# The sibling with no open question is not caught by that gate - which proves the
# refusal above is about the question, not about cartography-minted tickets in
# general.
run 0 "approve accepts the ticket that has no open question" \
  wo approve --project "$DIR" --id "$SCRAPER" --no-lavish --reason "test"

# --- next never offers a skeleton -------------------------------------------
# `next` returns only `ready`, and a skeleton cannot reach `ready`. This is what
# makes it safe for a skeleton to sit in the tree indefinitely.
capture NEXT wo next --project "$DIR" --json
if [[ $NEXT == *"$ORCH"* ]]; then
  _fail "next does not offer the skeleton" "the skeleton appeared in next: $NEXT"
else
  _pass "next does not offer the skeleton"
fi

# --- resolve is the graduation verb -----------------------------------------
run 0 "resolve records an answer to the skeleton's question" \
  wo resolve --project "$DIR" --id "$ORCH" --index 1 --answer "a pod on the cluster"
run 0 "approve now accepts the graduated skeleton" \
  wo approve --project "$DIR" --id "$ORCH" --no-lavish --reason "test"

# --- the document reflects the distinction ----------------------------------
carto render --project "$DIR" --island ingestion >/dev/null 2>&1
HTML="$DIR/cartography/003-product-ingestion.html"
assert_contains "$HTML" "$ORCH" "the document carries the real ticket id"
assert_contains "$HTML" "a POST with supplier_id reaches the matching adapter" "the acceptance criterion is rendered"
assert_not_contains "$HTML" "%%" "no template placeholder survived rendering"

# Intra-island dependency: orchestrator depends_on scrapers, declared by key.
assert_contains "$HTML" "Waiting on" "the intra-island dependency is shown"
capture OFM wo show --project "$DIR" --id "$ORCH" --json
assert_match "$OFM" "$SCRAPER" "the key-declared dependency resolved to a real id"

# A blocker is shown by title and linked, not as a bare id. An id alone forces a
# reader to open another file to find out whether the blocker matters, which is
# the question a map is supposed to answer.
assert_contains "$HTML" "Waiting on: <a" "the blocking ticket is a link"
assert_contains "$HTML" "Scraper adapters</a>" "and is named, not just addressed"

# The criterion label is kept but set apart. It reads as prose if left inline,
# and it is how someone addresses the criterion with `evidence --match`.
assert_contains "$HTML" '<span class="wo-id">AC-H1</span>' "the criterion label is rendered as a label"
assert_not_contains "$HTML" "AC-H1  " "the stripped marker leaves no double space"

# --- minting the same island twice ------------------------------------------
# A second run would issue new ids for the same work and orphan the first set,
# with nothing pointing at them.
run 3 "cutting the same island twice is refused" \
  carto island --project "$DIR" --spec "$DIR/ingestion.json"
capture COUNT bash -c "find '$DIR/work-orders' -name 'WO-*.md' | wc -l"
assert_eq "5" "$COUNT" "the refusal minted nothing: one system, two islands, two tickets"

# --- an island the map has never heard of -----------------------------------
cat >"$DIR/ghost.json" <<'JSON'
{"island": "ghost", "tickets": [{"key": "t", "title": "T", "problem": "p", "out": ["o"], "ac": ["x"]}]}
JSON
run 6 "an unknown island key is refused" carto island --project "$DIR" --spec "$DIR/ghost.json"

# --- a ticket with no acceptance criteria -----------------------------------
read -r D2 _ <<<"$(planned_project)"
cat >"$D2/bad.json" <<'JSON'
{"island": "ingestion", "tickets": [{"key": "t", "title": "T", "problem": "p", "out": ["o"]}]}
JSON
run 3 "a ticket with no ac is refused before anything is minted" \
  carto island --project "$D2" --spec "$D2/bad.json"
capture C2 bash -c "find '$D2/work-orders' -name 'WO-*.md' | wc -l"
assert_eq "3" "$C2" "and the island still has no tickets under it"

finish
