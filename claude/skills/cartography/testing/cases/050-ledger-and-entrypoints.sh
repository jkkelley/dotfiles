#!/usr/bin/env bash
#
# The ledger is generated, and the script is reachable.
#
# The original framing kept a "File Tracking Ledger" in prose, maintained by hand
# at the top of each response. A hand-maintained count is wrong the moment
# anything moves and nothing ever catches it, so the ledger here is computed from
# the tickets. These checks are what make that claim real.

CASE_NAME=050-ledger-and-entrypoints
source "${SKILL:-/skills/cartography}/testing/assert.sh"

read -r DIR SYS <<<"$(planned_project)"

# --- before any island is cut -----------------------------------------------
capture L carto ledger --project "$DIR" --json
capture N jq -r 'length' <<<"$L"
assert_eq "2" "$N" "the ledger lists every island from plan alone"
capture PENDING jq -r '[.[] | select(.tickets == 0)] | length' <<<"$L"
assert_eq "2" "$PENDING" "both islands start with no tickets"
capture FIRST jq -r '.[0].number' <<<"$L"
assert_eq "1" "$FIRST" "the ledger is ordered by island number"

# --- after cutting one island -----------------------------------------------
island_spec "$DIR/ingestion.json" >/dev/null
carto island --project "$DIR" --spec "$DIR/ingestion.json" >/dev/null 2>&1

capture L2 carto ledger --project "$DIR" --json
capture T jq -r '.[] | select(.file == "003-product-ingestion.html") | .tickets' <<<"$L2"
assert_eq "2" "$T" "the ledger counts the tickets that were actually minted"

# One of the two tickets carries an open question. The unresolved count is the
# number that tells a reader how much of this island is still undecided, so it
# has to come from the tickets rather than from the spec that requested them.
capture U jq -r '.[] | select(.file == "003-product-ingestion.html") | .unresolved' <<<"$L2"
assert_eq "1" "$U" "the ledger counts unresolved skeletons, not spec entries"

capture STILL jq -r '.[] | select(.number == 1) | .file' <<<"$L2"
assert_eq "" "$STILL" "an island that has not been cut has no document"

# The count follows the ticket, not the spec: resolving the question must drop it.
capture ORCH jq -r '.tickets["ingestion/orchestrator"].id' "$DIR/cartography/.map.json"
wo resolve --project "$DIR" --id "$ORCH" --index 1 --answer "a pod" >/dev/null 2>&1
capture L3 carto ledger --project "$DIR" --json
capture U2 jq -r '.[] | select(.file == "003-product-ingestion.html") | .unresolved' <<<"$L3"
assert_eq "0" "$U2" "resolving the question drops the unresolved count"

# --- the ledger in the macro map matches the ledger on stdout ---------------
carto render --project "$DIR" >/dev/null 2>&1
assert_contains "$DIR/cartography/000-macro-map.html" "003-product-ingestion.html" \
  "the macro map's ledger links the island document"

# --- entrypoints ------------------------------------------------------------
run 0 "help exits clean" carto help
run 0 "--help exits clean" carto --help
run 2 "no subcommand is a usage error" carto
run 2 "an unknown subcommand is a usage error" carto nonsense
run 2 "an unknown flag is a usage error" carto ledger --project "$DIR" --nonsense
run 4 "a project directory that does not exist is refused" carto ledger --project /nope

# --- work-order is not optional ---------------------------------------------
# There is no degraded mode. A map whose tickets were written by anything else is
# a map of tickets that do not exist, so the absence has to be loud.
#
# Tested by copying the skill somewhere with no work-order sibling, rather than
# by pointing --work-order at a bad path: the resolver falls back to the sibling,
# so a bad flag alone would resolve happily and prove nothing.
ISOLATED="$WORK/isolated"
rm -rf "$ISOLATED"; mkdir -p "$ISOLATED"
cp -r "$SKILL" "$ISOLATED/cartography"
run 4 "cartography with no work-order anywhere refuses" \
  bash "$ISOLATED/cartography/scripts/cartograph.sh" ledger --project "$DIR"
capture_err MSG bash "$ISOLATED/cartography/scripts/cartograph.sh" ledger --project "$DIR"
assert_match "$MSG" "work-order" "the missing dependency is named in the refusal"
assert_match "$MSG" "no fallback" "and the refusal says there is no degraded mode"

finish
