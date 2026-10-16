#!/usr/bin/env bash
# AC-H1, AC-H3 for reply-ledger.sh (B21c). Rules out: a second writer of ledger.jsonl creeping back into a caller, a row
# without a code, an id or an integer schema_version (a string "1", a float, null) reaching the file, and a half-valid batch
# writing its good rows before the bad one is found.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
S="$R/bin/reply-ledger.sh"
L="$T/d/ledger.jsonl"
app() { printf '%s\n' "$1" | bash "$S" append --file "$L" 2>"$T/err"; }

# AC-H3: a valid row lands, one line, parent folder made
app '{"schema_version":1,"code":"RP-READY","id":"m1"}'; rc=$?
check 0 "$rc" "AC-H3: a valid row is accepted"
check 1 "$(wc -l <"$L")" "AC-H3: one line was appended"
app '{"schema_version":1,"code":"RP-SENT","id":"m1"}'
check 2 "$(wc -l <"$L")" "append adds to the end, never replaces"

# AC-H3: each missing or wrong field is refused with exit 2 and the file is unchanged
n="$(wc -l <"$L")"
for row in '{"schema_version":1,"id":"m1"}' '{"schema_version":1,"code":"RP-X"}' '{"code":"RP-X","id":"m1"}' \
           '{"schema_version":"1","code":"RP-X","id":"m1"}' '{"schema_version":1.5,"code":"RP-X","id":"m1"}' \
           '{"schema_version":null,"code":"RP-X","id":"m1"}' '{"schema_version":1,"code":"","id":"m1"}' \
           '{"schema_version":1,"code":"RP-X","id":7}' '[1]' '"x"'; do
  app "$row"; rc=$?
  check 2 "$rc" "AC-H3: refused: $row"
  check "$n" "$(wc -l <"$L")" "AC-H3: nothing written for: $row"
done
printf 'not json\n' | bash "$S" append --file "$L" 2>/dev/null; check 2 "$?" "AC-H3: non-JSON stdin is refused"

# a batch with one bad row writes none of its rows
printf '%s\n%s\n' '{"schema_version":1,"code":"RP-A","id":"a"}' '{"code":"RP-B","id":"b"}' | bash "$S" append --file "$L" 2>/dev/null
check 2 "$?" "a half-valid batch is refused"
check "$n" "$(wc -l <"$L")" "a half-valid batch writes none of its rows"

# usage
bash "$S" 2>/dev/null; check 2 "$?" "no verb is a usage error"
bash "$S" append 2>/dev/null </dev/null; check 2 "$?" "append without --file is a usage error"

# AC-H1: ledger.jsonl is written only by reply-ledger.sh: no other script redirects into a ledger variable or path
w="$(grep -nE '>>?[[:space:]]*"?\$\{?(LEDGER|A_LEDGER|SWEEP_LEDGER_FILE)|>>?[[:space:]]*"?[^ ]*ledger\.jsonl' "$R"/bin/*.sh | grep -v 'bin/reply-ledger.sh' | grep -v '^[^:]*:[0-9]*:[[:space:]]*#' || true)"
check "" "$w" "AC-H1: no script but reply-ledger.sh redirects into ledger.jsonl"
# AC-H1: and the four callers go through it
for c in reply-cards reply-approve reply-send lead-followup; do
  check 1 "$(grep -c 'reply-ledger.sh" append' "$R/bin/$c.sh" | awk '{print ($1>=1)}')" "AC-H1: $c.sh appends through reply-ledger.sh"
done
finish
