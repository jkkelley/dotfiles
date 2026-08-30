#!/usr/bin/env bash
# The inside of live-check.sh. Never run this on a host: it leases real slots,
# and it is only safe because live-check.sh has already redirected
# TREEHOUSE_ROOT into a container scratch directory. The last case asserts that
# redirection actually held.
set -uo pipefail

SLOT=/skill/scripts/slot.sh
PASS=0; FAIL=0
ok()  { printf '  PASS  %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL+1)); }
hd()  { printf '\n=== %s\n' "$1"; }

export HOME=/work/home; mkdir -p "$HOME"
git config --global --add safe.directory '*'
git config --global user.email live-check@example.com
git config --global user.name live-check

export TREEHOUSE_ROOT=/work/pool; mkdir -p "$TREEHOUSE_ROOT"

R=/work/repo
git init -q --bare /work/origin.git
git init -q "$R"
git -C "$R" remote add origin /work/origin.git
printf 'seed\n' > "$R/a.txt"
git -C "$R" add a.txt
git -C "$R" commit -qm seed
git -C "$R" branch -M main
git -C "$R" push -q -u origin main

HOLDER=WO-LIVE-a6cb
OTHER=WO-LIVE-other

hd "acquire against the real binary"
WT=$(bash "$SLOT" acquire --holder "$HOLDER" --repo "$R" 2>/dev/null); RC=$?
[ $RC -eq 0 ] && [ -d "$WT" ] && ok "acquire returns a real directory: $WT" \
  || bad "acquire exited $RC and gave '$WT'"
MAP=$(bash "$SLOT" status --repo "$R" 2>/dev/null)
grep -qF "$HOLDER" <<<"$MAP" \
  && ok "treehouse status is the live map, keyed by ticket ID" \
  || bad "the holder does not appear in status"
[ "$(bash "$SLOT" holder --holder "$HOLDER" --repo "$R" 2>/dev/null)" = "$WT" ] \
  && ok "holder resolves the ticket ID back to the same path" || bad "holder disagrees with acquire"

hd "RUNG 3 - the acquire under contention"
# First, the behaviour the guard exists for, straight from the binary: asking
# twice with one --lease-holder hands out a SECOND slot and records the same
# holder against both. If this case ever fails, treehouse has grown the guard
# itself and slot.sh's can be reconsidered - but not before.
RAW=$(cd "$R" && treehouse get --lease --lease-holder "$HOLDER" --no-fetch 2>/dev/null)
HELD=$(cd "$R" && treehouse status --json 2>/dev/null | grep -o "\"lease_holder\":\"$HOLDER\"" | wc -l)
[ "$HELD" -eq 2 ] \
  && ok "raw treehouse double-leases one holder - the guard is load-bearing" \
  || bad "raw treehouse recorded $HELD leases for one holder, expected 2"
cd "$R" && treehouse return "$RAW" --if-lease-holder "$HOLDER" >/dev/null 2>&1

OUT=$(bash "$SLOT" acquire --holder "$HOLDER" --repo "$R" 2>&1); RC=$?
[ $RC -eq 3 ] && ok "slot.sh refuses a second acquire for a holder that has one" \
  || bad "a second acquire exited $RC instead of 3"
grep -qF "$WT" <<<"$OUT" && ok "and names the slot already held" || bad "the refusal does not name the slot"
HELD=$(cd "$R" && treehouse status --json 2>/dev/null | grep -o "\"lease_holder\":\"$HOLDER\"" | wc -l)
[ "$HELD" -eq 1 ] && ok "and the pool still records exactly one lease for it" \
  || bad "the pool records $HELD leases after the refusal"

# A different holder is not blocked by the first one.
WT2=$(bash "$SLOT" acquire --holder "$OTHER" --repo "$R" 2>/dev/null); RC=$?
[ $RC -eq 0 ] && [ "$WT2" != "$WT" ] && ok "a different ticket gets a different slot" \
  || bad "a second ticket exited $RC and got '$WT2'"

hd "RUNG 2 - the release, asserted as a state"
# THE CASE THIS TICKET EXISTS FOR, against the real binary. A dirty tree makes
# treehouse prompt; with no TTY the prompt takes its default, the return is
# abandoned, the slot stays leased, and the process exits 0.
printf 'uncommitted\n' > "$WT/dirty.txt"

RAWOUT=$(cd "$R" && treehouse return "$WT" --if-lease-holder "$HOLDER" 2>&1); RAWRC=$?
printf '  observed: raw return rc=%s, output: %s\n' "$RAWRC" "$(printf '%s' "$RAWOUT" | tr '\n' ' ')"
[ $RAWRC -eq 0 ] \
  && ok "the trap is still real: treehouse return exits 0 on a dirty tree" \
  || bad "treehouse return exited $RAWRC - the no-TTY abort may be fixed, re-read the design"
STILL=$(cd "$R" && treehouse status --json 2>/dev/null | grep -c "\"lease_holder\":\"$HOLDER\"")
[ "$STILL" -eq 1 ] && ok "and the slot really is still leased after that exit 0" \
  || bad "the slot was freed, so the exit code was honest this time"

# Now the thing under test: slot.sh must disbelieve that exit 0.
OUT=$(bash "$SLOT" release --holder "$HOLDER" --repo "$R" 2>&1); RC=$?
[ $RC -eq 5 ] && ok "slot.sh release reports failure where treehouse reported success" \
  || bad "release exited $RC - a close-out here would report success and leak the slot"
grep -q 'still leased' <<<"$OUT" && ok "and says which slot is still held" || bad "the message does not say what leaked"

hd "RUNG 2 - and the clean release actually frees it"
rm -f "$WT/dirty.txt"
bash "$SLOT" release --holder "$HOLDER" --repo "$R" >/dev/null 2>&1
[ $? -eq 0 ] && ok "a clean release exits 0" || bad "a clean release did not exit 0"
bash "$SLOT" holder --holder "$HOLDER" --repo "$R" >/dev/null 2>&1
[ $? -eq 3 ] && ok "and the pool records no lease for the ticket afterwards" \
  || bad "the ticket still holds a slot after a clean release"

# Re-running a finished close-out is not an error.
bash "$SLOT" release --holder "$HOLDER" --repo "$R" >/dev/null 2>&1
[ $? -eq 0 ] && ok "releasing again is still success" || bad "the second release failed"

hd "the close-out standing inside its own slot"
# The slot the close-out is working in is the normal case, and treehouse reports
# a freed slot inspected from inside itself as "you're here" rather than
# "available". Keying on the holder rather than the status is what survives it.
WT3=$(bash "$SLOT" acquire --holder WO-LIVE-inside --repo "$R" 2>/dev/null)
( cd "$WT3" && bash "$SLOT" release --holder WO-LIVE-inside --repo "$WT3" >/dev/null 2>&1 )
RC=$?
[ $RC -eq 0 ] && ok "a release run from inside the slot exits 0" \
  || bad "a release from inside its own slot exited $RC"
bash "$SLOT" holder --holder WO-LIVE-inside --repo "$R" >/dev/null 2>&1
[ $? -eq 3 ] && ok "and the slot is genuinely free afterwards" || bad "the slot is still held"

hd "the live pool was never touched"
# The whole probe is only safe because TREEHOUSE_ROOT points inside the
# container. Assert it rather than trust it.
bash "$SLOT" release --holder "$OTHER" --repo "$R" >/dev/null 2>&1
COUNT=$(find /work/pool -maxdepth 3 -name '*.json' 2>/dev/null | wc -l)
[ "$COUNT" -ge 1 ] && ok "the pool used was the one under /work" || bad "no pool state under /work - where did it go?"
[ ! -e "$HOME/.treehouse" ] && ok "nothing was written to \$HOME/.treehouse" \
  || bad "a pool appeared in \$HOME - the redirect did not hold"

hd "Result"
printf '  %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
