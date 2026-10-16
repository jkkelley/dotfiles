#!/usr/bin/env bash
# B20a: node declarations, nodes-check and bottleneck-check.
#   AC-H1 every shipped declaration validates, and a malformed one is refused
#   AC-H2 a script naming an undeclared node fails nodes-check
#   AC-H3 a serial node with no reason fails bottleneck-check
#   AC-H4 the design table and a declaration that disagree fail nodes-check
# B20b: L1 to L12 (with L6b) and S1 to S7 declared; L6b is the single intended wait; script_pending is honoured.
# Each negative case mutates a copy in a temp dir, so the failure is the planted one and the tree is never written.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$(dirname "${BASH_SOURCE[0]}")/_t.sh"
# shellcheck source=../../bin/node-lib.sh
. "$R/bin/node-lib.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
DESIGN="$R/../../../docs/design/inbox-sweep.md"

fresh() { rm -rf "$T/n" "$T/s"; mkdir -p "$T/n" "$T/s"; cp "$R"/nodes/*.node.json "$T/n/"; cp "$DESIGN" "$T/design.md"; }
run() { NODE_DIR="$T/n" NODE_DESIGN="$T/design.md" NODE_SCRIPTS="$T/s" "$@" 2>&1; }

# shipped state
fresh
out="$(run node_check)"; rc=$?
check 0 "$rc" "AC-H1 the shipped declarations pass nodes-check"
check 7 "$(find "$R/nodes" -name "R?.node.json" | wc -l)" "AC-H1 R1 to R7 each have a declaration"
out="$(run node_bottleneck)"; rc=$?
check 0 "$rc" "the shipped declarations pass bottleneck-check"

# AC-H1 negatives
fresh; jq 'del(.checklist)' "$T/n/R1.node.json" >"$T/x" && mv "$T/x" "$T/n/R1.node.json"
out="$(run node_check)"; check 1 "$?" "AC-H1 a declaration with no checklist is refused"
check yes "$(grep -q 'R1.node.json fails node.schema.json' <<<"$out" && echo yes)" "AC-H1 the refusal names the file"
fresh; jq '.version="1.0"' "$T/n/R2.node.json" >"$T/x" && mv "$T/x" "$T/n/R2.node.json"
run node_check >/dev/null; check 1 "$?" "AC-H1 a version that is not semver is refused"
fresh; mv "$T/n/R3.node.json" "$T/n/R9.node.json"
out="$(run node_check)"; check 1 "$?" "a file name that disagrees with its id is refused"

# AC-H2
fresh; printf '#!/usr/bin/env bash\n# node: R8\n' >"$T/s/rogue.sh"
out="$(run node_check)"; check 1 "$?" "AC-H2 a script naming undeclared node R8 fails nodes-check"
check yes "$(grep -q 'rogue.sh names node R8' <<<"$out" && echo yes)" "AC-H2 the failure names the script and the node"
fresh; printf '#!/usr/bin/env bash\n# node: R4\n' >"$T/s/fine.sh"
run node_check >/dev/null; check 0 "$?" "AC-H2 a script naming a declared node passes"

# AC-H3
fresh; jq '.serial=""' "$T/n/R5.node.json" >"$T/x" && mv "$T/x" "$T/n/R5.node.json"
out="$(run node_bottleneck)"; check 1 "$?" "AC-H3 a serial node with an empty reason fails bottleneck-check"
check yes "$(grep -q 'R5 is serial and gives no reason' <<<"$out" && echo yes)" "AC-H3 the failure names the node"
fresh; jq '.serial=null | .parallel="none"' "$T/n/R6.node.json" >"$T/x" && mv "$T/x" "$T/n/R6.node.json"
run node_bottleneck >/dev/null; check 1 "$?" "AC-H3 parallel none with serial null (no reason anywhere) fails"
fresh; jq '.serial=null | .parallel="per account"' "$T/n/R6.node.json" >"$T/x" && mv "$T/x" "$T/n/R6.node.json"
run node_bottleneck >/dev/null; check 0 "$?" "AC-H3 a parallel node needs no reason"

# AC-H4
fresh; sed -i '0,/- \[ \] Owner words present and non-empty/s//- [ ] Owner words present/' "$T/design.md"
out="$(run node_check)"; check 1 "$?" "AC-H4 a design table edited away from its declaration fails nodes-check"
check yes "$(grep -q 'R1 declaration and design table disagree' <<<"$out" && echo yes)" "AC-H4 the failure names the node"
fresh; jq '.checklist[0].proof="something else"' "$T/n/R7.node.json" >"$T/x" && mv "$T/x" "$T/n/R7.node.json"
run node_check >/dev/null; check 1 "$?" "AC-H4 a declaration edited away from the table fails nodes-check"

# B20b AC-H1: the reply and lead declarations
fresh
check 13 "$(find "$R/nodes" -name 'L*.node.json' | wc -l)" "B20b AC-H1 L1 to L12 and L6b each have a declaration"
check 7 "$(find "$R/nodes" -name 'S?.node.json' | wc -l)" "B20b AC-H1 S1 to S7 each have a declaration"
out="$(run node_check)"; rc=$?
check 0 "$rc" "B20b AC-H1 every L and S declaration validates and names an existing or pending script"
out="$(run node_bottleneck)"; rc=$?
check 0 "$rc" "B20b AC-H1 bottleneck-check passes with the L and S nodes"
check "intended wait: L6b" "$(grep '^intended wait:' <<<"$out")" "B20b AC-H1 bottleneck-check lists L6b as the single intended wait"
check yes "$(grep -q '^L6b ' <<<"$out" && echo yes)" "B20b AC-H1 L6b has a row with its reason"
fresh; jq '.serial |= "Intended wait: also this one"' "$T/n/L9.node.json" >"$T/x" && mv "$T/x" "$T/n/L9.node.json"
out="$(run node_bottleneck)"; check 1 "$?" "B20b AC-H1 a second intended wait fails bottleneck-check"
check yes "$(grep -q 'more than one node is marked' <<<"$out" && echo yes)" "B20b AC-H1 the failure names the nodes"
fresh; jq 'del(.script_pending)' "$T/n/L3.node.json" >"$T/x" && mv "$T/x" "$T/n/L3.node.json"
jq '.script="claude/workflow/inbox-sweep/bin/not-written-yet.sh"' "$T/n/L3.node.json" >"$T/x" && mv "$T/x" "$T/n/L3.node.json"
out="$(run node_check)"; check 1 "$?" "B20b a missing script that is not marked pending fails nodes-check"
fresh; jq '.id="L13"' "$T/n/L3.node.json" >"$T/x" && mv "$T/x" "$T/n/L3.node.json"
run node_check >/dev/null; check 1 "$?" "B20b AC-H1 an id outside R1-R7, L1-L12, L6b, S1-S7 is refused"
fresh; jq '.script_pending=true | .script="claude/workflow/inbox-sweep/bin/sweep-clean.sh"' "$T/n/R7.node.json" >"$T/x" && mv "$T/x" "$T/n/R7.node.json"
out="$(run node_check)"; check 0 "$?" "B20b a pending flag on a script that exists passes"
check yes "$(grep -q 'R7.node.json is script_pending but' <<<"$out" && echo yes)" "B20b and prints a note to drop the flag"
finish
