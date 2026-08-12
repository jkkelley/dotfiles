#!/usr/bin/env bash
#
# plan mints the epics and renders the macro map.
#
# The assertion that earns its keep here is not "a file appeared" - it is that
# every id in the HTML is one work-order actually issued. A map full of ids the
# model invented would look identical and be entirely useless.

CASE_NAME=010-plan-happy
source "${SKILL:-/skills/cartography}/testing/assert.sh"

read -r DIR SYS <<<"$(planned_project)"

assert_match "$SYS" "WO-" "plan returns a real work-order id for the system"
assert_file "$DIR/cartography/000-macro-map.html" "macro map is rendered"
assert_file "$DIR/cartography/.map.json" "the key-to-id map is written"
assert_file "$DIR/cartography/specs/macro.json" "the spec is stored, so render needs no re-supply"

MAP="$DIR/cartography/.map.json"
capture ING jq -r '.islands.ingestion.id' "$MAP"
capture STO jq -r '.islands.storefront.id' "$MAP"
assert_match "$ING" "WO-" "the ingestion island has an id"
assert_ne "$ING" "$STO" "the two islands are distinct tickets"

# The ids in the map exist as files work-order wrote. This is the check that
# separates a real mint from a plausible-looking string.
capture N find "$DIR/work-orders" -name "$ING-*.md"
assert_match "$N" "$ING" "the ingestion island exists on disk as a work-order"

# Hierarchy: each island is filed under the system epic, which is what makes the
# island document a view of a subtree rather than a loose list.
capture PARENT wo show --project "$DIR" --id "$ING" --json
assert_match "$PARENT" "\"parent\": \"$SYS\"" "the island's parent is the system epic"

# The cross-island edge from the spec reached the graph in both directions.
capture STOFM wo show --project "$DIR" --id "$STO" --json
assert_match "$STOFM" "$ING" "storefront depends_on ingestion, as the spec declared"

HTML="$DIR/cartography/000-macro-map.html"
assert_contains "$HTML" "$SYS" "the macro map carries the system id"
assert_contains "$HTML" "$ING" "the macro map carries the island id"
assert_contains "$HTML" "Product Ingestion" "the island title is rendered"
assert_contains "$HTML" "File Tracking Ledger" "the ledger is generated into the map"
assert_contains "$HTML" "mermaid" "the model's diagram is embedded"
assert_contains "$HTML" "A[Ingestion] --> B[Storefront]" "mermaid arrows survive un-escaped"

# The placeholder guard, for the same reason work-order has one: a stray token
# renders as literal text, breaks nothing, and is invisible for months.
assert_not_contains "$HTML" "%%" "no template placeholder survived rendering"

# Islands are ordered by their declared number, not by spec order or by hash.
# storefront is number 1 and appears second in the spec, so this fails loudly if
# the sort is dropped.
capture ORDER bash -c "grep -o 'Storefront Generator\|Product Ingestion' '$HTML' | head -1"
assert_eq "Storefront Generator" "$ORDER" "islands render in number order, not spec order"

finish
