#!/usr/bin/env bash
# Drives hydration.sh and slot.sh through the cases that matter, offline. Run
# in a container:
#
#   podman run --rm --user 0 -v "$PWD:/work:ro,Z" -w /tmp \
#     docker.io/library/bash:5 bash /work/testing/run-tests.sh
#
# The failure cases are the point. A green happy path cannot tell a working
# guard from a decorative one.
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
HP="$HERE/../scripts/hydration.sh"
SLOT="$HERE/../scripts/slot.sh"
PASS=0; FAIL=0

ok()  { printf '  PASS  %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL+1)); }
hd()  { printf '\n=== %s\n' "$1"; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# A body that passes check, parameterised so entries are distinguishable.
good_body() {
  local tag=$1 out=$2
  cat > "$out" <<EOF
### Ticket
WO-TEST-$tag - Test ticket $tag.

### What just landed
Landed $tag.

### What is NOT done
Nothing was applied for $tag.

### Stale or false in the docs
Nothing stale for $tag.

### Your scope
Scope $tag.

### Before you start
None.

### Read in this order
CLAUDE.md, then the ticket.

### Reuse, it is proven
The thing from $tag.

### The verification ladder
Container, then stub, then real.

### Traps, already paid for
Do not mount over /lib.

### Workflow
bash \$WO start --id WO-TEST-$tag

### Conventions
Plain language, no em dashes.
EOF
}

# ---------------------------------------------------------------- init
hd "init"
P="$WORK/proj"; mkdir -p "$P"
bash "$HP" init --project "$P" >/dev/null 2>&1 \
  && [ -f "$P/HYDRATION.md" ] && ok "creates HYDRATION.md" || bad "did not create HYDRATION.md"
BEFORE=$(md5sum "$P/HYDRATION.md" | cut -d' ' -f1)
bash "$HP" init --project "$P" >/dev/null 2>&1
AFTER=$(md5sum "$P/HYDRATION.md" | cut -d' ' -f1)
[ "$BEFORE" = "$AFTER" ] && ok "re-running init changes nothing" || bad "init is not idempotent"

bash "$HP" count --project "$WORK/nope" >/dev/null 2>&1
[ $? -eq 4 ] && ok "missing HYDRATION.md exits 4 (io)" || bad "wrong exit code for missing file"

# ---------------------------------------------------------------- add + order
hd "add and ordering"
good_body one "$WORK/b1.md"
bash "$HP" add --project "$P" --id WO-TEST-one --title "First ticket" --body-file "$WORK/b1.md" >/dev/null 2>&1 \
  && ok "adds an entry" || bad "add failed"
[ "$(bash "$HP" count --project "$P")" = "1" ] && ok "count is 1" || bad "count wrong after first add"

good_body two "$WORK/b2.md"
bash "$HP" add --project "$P" --id WO-TEST-two --title "Second ticket" --body-file "$WORK/b2.md" >/dev/null 2>&1
NEWEST=$(bash "$HP" latest --project "$P" --id-only)
[ "$NEWEST" = "WO-TEST-two" ] && ok "newest entry is on top" || bad "top entry was '$NEWEST', expected WO-TEST-two"

TITLE=$(bash "$HP" latest --project "$P" --title-only)
[ "$TITLE" = "Second ticket" ] && ok "title parses back out" || bad "title was '$TITLE'"

# latest must return ONE entry, not the file
LATEST_MARKS=$(bash "$HP" latest --project "$P" | grep -c 'hydration-entry:')
[ "$LATEST_MARKS" = "1" ] && ok "latest returns exactly one entry" || bad "latest returned $LATEST_MARKS entries"

# ---------------------------------------------------------------- the window
hd "the 10-entry window"
for n in $(seq 3 12); do
  good_body "n$n" "$WORK/bn.md"
  bash "$HP" add --project "$P" --id "WO-TEST-$n" --title "Ticket $n" --body-file "$WORK/bn.md" >/dev/null 2>&1
done
COUNT=$(bash "$HP" count --project "$P")
[ "$COUNT" = "10" ] && ok "holds exactly 10 after 12 adds" || bad "holds $COUNT, expected 10"

grep -q 'WO-TEST-one' "$P/HYDRATION.md" \
  && bad "the oldest entry was not dropped" || ok "oldest entry fell off the bottom"
[ "$(bash "$HP" latest --project "$P" --id-only)" = "WO-TEST-12" ] \
  && ok "newest is still on top after rotation" || bad "rotation disturbed the top entry"

grep -q '^# HYDRATION.md' "$P/HYDRATION.md" \
  && ok "the file preamble survives rotation" || bad "rotation ate the preamble"

# ---------------------------------------------------------------- check refuses
hd "check refuses malformed bodies"

good_body dup "$WORK/dup.md"
printf '\n### Traps, already paid for\nPasted in twice by accident.\n' >> "$WORK/dup.md"
bash "$HP" check --project "$P" --body-file "$WORK/dup.md" >/dev/null 2>&1
[ $? -eq 3 ] && ok "refuses a duplicated section" || bad "accepted a duplicated section"

good_body miss "$WORK/miss.md"
grep -v '^### Workflow$' "$WORK/miss.md" > "$WORK/miss2.md"
bash "$HP" check --project "$P" --body-file "$WORK/miss2.md" >/dev/null 2>&1
[ $? -eq 3 ] && ok "refuses a missing section" || bad "accepted a missing section"

good_body empt "$WORK/empt.md"
sed 's/^None\.$//' "$WORK/empt.md" > "$WORK/empt2.md"
bash "$HP" check --project "$P" --body-file "$WORK/empt2.md" >/dev/null 2>&1
[ $? -eq 3 ] && ok "refuses an empty 'Before you start'" || bad "accepted an empty prerequisites section"

good_body unk "$WORK/unk.md"
printf '\n### Some Other Heading\nStray paste.\n' >> "$WORK/unk.md"
bash "$HP" check --project "$P" --body-file "$WORK/unk.md" >/dev/null 2>&1
[ $? -eq 3 ] && ok "refuses an unknown section" || bad "accepted an unknown section"

# and the important one: a refused body must not reach the file
COUNT_BEFORE=$(bash "$HP" count --project "$P")
bash "$HP" add --project "$P" --id WO-TEST-bad --title "Bad" --body-file "$WORK/dup.md" >/dev/null 2>&1
COUNT_AFTER=$(bash "$HP" count --project "$P")
[ "$COUNT_BEFORE" = "$COUNT_AFTER" ] \
  && ok "a refused body is not written" || bad "a malformed entry reached the file"

# ---------------------------------------------------------------- the command
hd "the launch command"
CMD=$(bash "$HP" command --project "$P" --id WO-20260818-7a0b --title "CI/CD + GitOps" --oneline)
EXPECT="claude --permission-mode bypassPermissions -n \"Session: WO-20260818-7a0b - CI/CD + GitOps\" \"Read Hydration Prompt located at $(cd "$P" && pwd)/HYDRATION.md, Process work order WO-20260818-7a0b per its acceptance criteria after you've read it.\""
[ "$CMD" = "$EXPECT" ] && ok "matches the template byte for byte" || {
  bad "command did not match the template"
  printf '    got:      %s\n    expected: %s\n' "$CMD" "$EXPECT"
}

# THE REGRESSION THIS FILE EXISTS TO PREVENT.
# The prompt used to be passed as -p, which is --print: "print response and
# exit". The command ran the hydration prompt headless and quit, so the user
# never landed in a session - the one thing this skill exists to arrange. It
# looked right in every transcript, because the output was a plausible reply.
# The prompt is a positional argument now. -p must never come back.
printf '%s' "$CMD" | grep -qE '(^| )-p( |$)|--print' \
  && bad "-p/--print is back: the session would run headless and exit" \
  || ok "no -p/--print: the session is interactive"
printf '%s' "$CMD" | grep -q 'Read Hydration Prompt located at' \
  && ok "the prompt still ships with the command" \
  || bad "the prompt was lost when -p was dropped"
printf '%s' "$CMD" | grep -q 'you.ve read it\."$' \
  && ok "the positional prompt is the last argument" \
  || bad "the prompt is not last - a flag would have to step over it"

# WHY IT IS FOLDED BY US RATHER THAN BY WHATEVER RENDERS IT.
# A one-line command is not safe: every surface it travels through soft-wraps at
# its own width, and a copy out of that surface can carry the break with it,
# landing in the middle of a quoted string. The first fragment is then usually a
# syntactically VALID command that does the wrong thing, so the shell runs it.
# Folding it ourselves at a narrow width, with a real backslash at each break,
# means the line the user sees is the line we wrote.
FOLDED=$(bash "$HP" command --project "$P" --id WO-20260818-7a0b --title "CI/CD + GitOps")
[ "$(printf '%s\n' "$FOLDED" | wc -l)" -ge 3 ] \
  && ok "one line per argument: 3 arguments, at least 3 lines" \
  || bad "arguments are sharing lines"
printf '%s\n' "$FOLDED" | grep -q '" -' \
  && bad "an argument ends and another begins on the same line" \
  || ok "no argument ends and another begins on the same line"
[ "$(printf '%s\n' "$FOLDED" | awk 'length($0) > 68 {c++} END{print c+0}')" = "0" ] \
  && ok "no line exceeds the 68-column default" || bad "a line is wider than 68"
[ "$(printf '%s\n' "$FOLDED" | awk 'NR>1 && /^[[:space:]]/ {c++} END{print c+0}')" = "0" ] \
  && ok "continuations are flush left" || bad "a continuation line is indented"
[ "$(printf '%s\n' "$FOLDED" | sed '$d' | grep -vc '\\$')" = "0" ] \
  && ok "every folded line but the last ends in a backslash" \
  || bad "a folded line is missing its continuation backslash"
printf '%s\n' "$FOLDED" | tail -n1 | grep -q '\\$' \
  && bad "the last line ends in a stray backslash" || ok "the last line has no backslash"

# --oneline is the unfolded form, for scripting
[ "$CMD" = "$(bash "$HP" command --project "$P" --id WO-20260818-7a0b --title "CI/CD + GitOps" --oneline)" ] \
  && ok "--oneline gives the unfolded command" || bad "--oneline shape wrong"

# --width is honoured
NARROW=$(bash "$HP" command --project "$P" --width 40 --id W --title T)
[ "$(printf '%s\n' "$NARROW" | awk 'length($0) > 40 {c++} END{print c+0}')" = "0" ] \
  && ok "--width 40 is respected" || bad "--width 40 was exceeded"
bash "$HP" command --project "$P" --width abc >/dev/null 2>&1
[ $? -eq 2 ] && ok "a non-numeric --width exits 2 (usage)" || bad "bad --width was accepted"
printf '%s' "$CMD" | grep -q '"Read Hydration Prompt located at /' \
  && ok "path is absolute" || bad "path is not absolute"
printf '%s' "$CMD" | grep -q "^claude --permission-mode bypassPermissions " \
  && ok "claude and the first flag share the opening line" \
  || bad "the command does not open as expected"

bash "$HP" command --project "$WORK/nope" --id X --title Y >/dev/null 2>&1
[ $? -eq 4 ] && ok "refuses to emit a command for a missing file" || bad "emitted a command for a missing file"

# ---------------------------------------------------------------- no work order
hd "the no-work-order edge case"
Q="$WORK/adhoc"; mkdir -p "$Q"
bash "$HP" init --project "$Q" >/dev/null 2>&1
good_body ad "$WORK/ad.md"
bash "$HP" add --project "$Q" --title "Spike: can Lightsail hold an IAM role" --body-file "$WORK/ad.md" >/dev/null 2>&1 \
  && ok "add works with no --id" || bad "add refused an entry with no --id"

[ -z "$(bash "$HP" latest --project "$Q" --id-only)" ] \
  && ok "id-only is empty when there is no ticket" || bad "id-only returned something"
T=$(bash "$HP" latest --project "$Q" --title-only)
[ "$T" = "Spike: can Lightsail hold an IAM role" ] \
  && ok "the title survives intact" || bad "title was '$T'"

ACMD=$(bash "$HP" command --project "$Q" --oneline)
AEXPECT="claude -n \"Session: \""
[ "$ACMD" = "$AEXPECT" ] && ok "emits the no-work-order command shape" || {
  bad "no-work-order command did not match"
  printf '    got:      %s\n    expected: %s\n' "$ACMD" "$AEXPECT"
}
# A ticketless session carries NO prompt - not a shortened one, not the bare
# located-at clause. Work outside a ticket has no instruction until the person
# starting it writes one, and a guessed prompt aims a session at the wrong
# thing with full confidence.
printf '%s' "$ACMD" | grep -q "Read Hydration Prompt" \
  && bad "a prompt leaked into a ticketless command" \
  || ok "no prompt at all when there is no ticket"
printf '%s' "$ACMD" | grep -q "Process work order" \
  && bad "the acceptance-criteria clause leaked into a ticketless command" \
  || ok "no acceptance-criteria clause when there is no ticket"
printf '%s' "$ACMD" | grep -q "permission-mode" \
  && bad "bypassPermissions leaked into a ticketless command" \
  || ok "no bypassPermissions when there is no ticket"
# The empty slot is the feature, not an oversight: the person pasting decides
# what this session is called, because ad-hoc work has no name until then.
[ "$(printf '%s' "$ACMD" | grep -c '\-n "Session: "$')" = "1" ] \
  && ok "the session name is left empty to be typed at paste time" \
  || bad "the session name slot was filled in"
printf '%s' "$ACMD" | grep -q "Spike: can Lightsail" \
  && bad "the entry title leaked into the session name" \
  || ok "the entry title does not leak into the session name"

# a title containing " - " must not be cut in half
good_body dash "$WORK/dash.md"
bash "$HP" add --project "$Q" --id WO-DASH-1 --title "Infra: Route53 - DNS-01 - passthrough" --body-file "$WORK/dash.md" >/dev/null 2>&1
DT=$(bash "$HP" latest --project "$Q" --title-only)
[ "$DT" = "Infra: Route53 - DNS-01 - passthrough" ] \
  && ok "a title containing ' - ' survives parsing" || bad "title was mangled to '$DT'"
[ "$(bash "$HP" latest --project "$Q" --id-only)" = "WO-DASH-1" ] \
  && ok "and its id still parses" || bad "id lost on a dashed title"

# derived form must agree with the explicit form
D1=$(bash "$HP" command --project "$Q" --oneline)
D2=$(bash "$HP" command --project "$Q" --id WO-DASH-1 --title "Infra: Route53 - DNS-01 - passthrough" --oneline)
[ "$D1" = "$D2" ] && ok "derived command matches the explicit one" || bad "derived and explicit commands differ"

# ---------------------------------------------------------------- whole file
hd "check on the file itself"
bash "$HP" check --project "$P" >/dev/null 2>&1 \
  && ok "the maintained file passes its own check" || bad "the maintained file fails check"

hd "Round-trip through a real shell"
bash "$HERE/wrap-roundtrip.sh" >/dev/null 2>&1 \
  && ok "folded and unfolded forms deliver identical argv at every width" \
  || { bad "wrap-roundtrip failed - run testing/wrap-roundtrip.sh to see it"; }

# ===========================================================================
# slot.sh - the treehouse workbench the close-out holds
#
# treehouse is the input under test here, not a dependency to install, so it is
# stubbed on PATH. Every JSON blob below is recorded verbatim from a real
# `treehouse status --json` v2.3.0 during the 2026-08-30 probe, so the parser
# is exercised against the renderer that actually ships rather than a shape
# invented to suit it. The stub swaps one recorded blob for another instead of
# simulating a pool: a fixture that cannot drift is worth more here than a
# model that can.
#
# testing/live-check.sh is the other half. It runs the real binary and proves
# treehouse still behaves the way these fixtures say it does.

S="$WORK/slot"; mkdir -p "$S/bin" "$S/repo"
export TH_STATE="$S/state.json" TH_LOG="$S/calls.log"
cat > "$S/bin/treehouse" <<'STUB'
#!/usr/bin/env bash
# Stub treehouse. It prints $TH_STATE for `status --json`, and for `get` and
# `return` it copies $TH_AFTER over $TH_STATE - so a case says what the pool
# looks like afterwards rather than trusting the stub to work it out. TH_RC is
# the exit code to hand back, which is exactly the thing slot.sh must ignore.
printf '%s\n' "$*" >> "$TH_LOG"
case $1 in
  # status always succeeds. TH_RC belongs to get and return - it is the thing
  # under test - and letting it leak into status would make every case that
  # scripts a non-zero return fail as an unreadable pool instead.
  status) cat "$TH_STATE"; exit 0 ;;
  get)    [ -n "${TH_AFTER:-}" ] && cp "$TH_AFTER" "$TH_STATE"
          printf '%s\n' "${TH_PATH:-}" ;;
  return) [ -n "${TH_AFTER:-}" ] && cp "$TH_AFTER" "$TH_STATE"
          printf 'stub: return spoke\n' ;;
esac
exit "${TH_RC:-0}"
STUB
chmod +x "$S/bin/treehouse"
PATH="$S/bin:$PATH"; export PATH

# --- the recorded fixtures ------------------------------------------------
cat > "$S/empty.json" <<'EOF'
[]
EOF
cat > "$S/held.json" <<'EOF'
[{"name":"1","path":"/pool/1/repo","status":"leased","flavor":"git","lease_id":"57ad1e6601fbd4dfc6fd8a3a431c06e3","lease_holder":"WO-TEST-a6cb","leased_at":"2026-08-30T14:20:11.403429345Z","processes":[]}]
EOF
cat > "$S/free.json" <<'EOF'
[{"name":"1","path":"/pool/1/repo","status":"available","flavor":"git","lease_id":"","lease_holder":"","leased_at":null,"processes":[]}]
EOF
# Two slots, and the second carries live processes - which is where a naive
# split on '},{' cuts a record in half and loses the holder behind it.
cat > "$S/two.json" <<'EOF'
[{"name":"1","path":"/pool/1/repo","status":"available","flavor":"git","lease_id":"","lease_holder":"","leased_at":null,"processes":[]},{"name":"2","path":"/pool/2/repo","status":"leased","flavor":"git","lease_id":"16b8675308056cb5128ff3bbcb430aaf","lease_holder":"WO-TEST-other","leased_at":"2026-08-30T14:20:11.462811811Z","processes":[{"pid":244,"name":"bash"},{"pid":245,"name":"treehouse"}]}]
EOF
# A returned slot inspected from INSIDE itself. treehouse calls that status
# "you're here", not "available", so a check reading the status field would
# call a freed slot occupied for the whole of any close-out standing in it.
cat > "$S/here.json" <<'EOF'
[{"name":"2","path":"/pool/2/repo","status":"you're here","flavor":"git","lease_id":"","lease_holder":"","leased_at":null,"processes":[{"pid":298,"name":"bash"},{"pid":299,"name":"treehouse"}]}]
EOF

use() { cp "$1" "$TH_STATE"; : > "$TH_LOG"; }
R="$S/repo"

hd "slot.sh - the dispatcher"
bash "$SLOT" --help >/dev/null 2>&1 \
  && ok "--help exits 0" || bad "--help did not exit 0"
HELPTEXT=$(bash "$SLOT" --help 2>&1)
grep -q 'acquire' <<<"$HELPTEXT" && grep -q 'release' <<<"$HELPTEXT" \
  && ok "--help names both verbs" || bad "--help does not name the verbs"
bash "$SLOT" >/dev/null 2>&1
[ $? -eq 2 ] && ok "no command exits 2 (usage)" || bad "wrong exit code for no command"
bash "$SLOT" fly --holder X >/dev/null 2>&1
[ $? -eq 2 ] && ok "an unknown command exits 2" || bad "an unknown command was accepted"
bash "$SLOT" status --wat >/dev/null 2>&1
[ $? -eq 2 ] && ok "an unknown option exits 2" || bad "an unknown option was accepted"
bash "$SLOT" status --repo "$WORK/nowhere" >/dev/null 2>&1
[ $? -eq 4 ] && ok "a missing --repo exits 4 (io)" || bad "wrong exit code for a missing --repo"

# treehouse absent is an io failure with a message that says where it lives,
# not a stack of "command not found" from three different call sites.
# Drop the stub directory rather than emptying PATH: an empty PATH loses bash
# too, and the 127 that comes back is the shell failing to start the script,
# not the script reporting anything.
OUT=$(PATH="${PATH#"$S/bin:"}" bash "$SLOT" status --repo "$R" 2>&1); RC=$?
[ $RC -eq 4 ] && ok "treehouse missing from PATH exits 4" || bad "treehouse missing exited $RC"
grep -q 'treehouse update' <<<"$OUT" \
  && ok "and the message says how to install it" || bad "the message does not say how to install it"

hd "slot.sh - the holder label"
# A quote in the label is re-encoded by treehouse, so the holder comparison
# would miss it silently - and on the release path a silent miss reads as a
# clean hand-back that never happened. Refused rather than escaped.
use "$S/empty.json"
bash "$SLOT" acquire --holder 'ho"ler' --repo "$R" >/dev/null 2>&1
[ $? -eq 3 ] && ok "a quote in --holder exits 3 (validation)" || bad "a quoted holder was accepted"
[ ! -s "$TH_LOG" ] && ok "and treehouse was never called" || bad "treehouse was called with a bad holder"
bash "$SLOT" acquire --holder '-leading-dash' --repo "$R" >/dev/null 2>&1
[ $? -eq 3 ] && ok "a leading dash in --holder exits 3" || bad "a dash-leading holder was accepted"
bash "$SLOT" acquire --repo "$R" >/dev/null 2>&1
[ $? -eq 2 ] && ok "a missing --holder exits 2 (usage)" || bad "a missing --holder was accepted"
use "$S/held.json"
bash "$SLOT" holder --holder 'WO-TEST-a6cb' --repo "$R" >/dev/null 2>&1 \
  && ok "a ticket ID is a legal holder" || bad "a ticket ID was refused"

hd "slot.sh - acquire"
use "$S/empty.json"
GOT=$(TH_PATH=/pool/1/repo TH_AFTER="$S/held.json" bash "$SLOT" acquire --holder WO-TEST-a6cb --repo "$R" 2>/dev/null)
[ "$GOT" = "/pool/1/repo" ] \
  && ok "acquire prints the path and nothing else" || bad "acquire printed '$GOT'"
LOG=$(cat "$TH_LOG")
grep -q -- '--lease-holder WO-TEST-a6cb' <<<"$LOG" \
  && ok "the ticket ID is recorded as the lease holder" || bad "the lease holder was not passed"
grep -q -- '--no-fetch' <<<"$LOG" \
  && ok "the origin fetch is skipped by default" || bad "acquire fetched without being asked"
use "$S/empty.json"
TH_PATH=/pool/1/repo TH_AFTER="$S/held.json" bash "$SLOT" acquire --holder WO-TEST-a6cb --repo "$R" --fetch >/dev/null 2>&1
LOG=$(cat "$TH_LOG")
grep -q -- '--no-fetch' <<<"$LOG" \
  && bad "--fetch did not re-enable the fetch" || ok "--fetch re-enables the origin fetch"

# THE CONTENTION CASE. treehouse hands a second slot to a holder that already
# has one and records the same holder against both - observed in the probe. One
# ticket is one session is one workbench, so this refuses.
use "$S/held.json"
OUT=$(TH_PATH=/pool/2/repo bash "$SLOT" acquire --holder WO-TEST-a6cb --repo "$R" 2>&1); RC=$?
[ $RC -eq 3 ] && ok "acquiring twice for one holder exits 3" || bad "a second acquire exited $RC"
grep -q '/pool/1/repo' <<<"$OUT" \
  && ok "and the refusal names the slot already held" || bad "the refusal does not name the held slot"
LOG=$(cat "$TH_LOG")
grep -q '^get' <<<"$LOG" \
  && bad "treehouse get ran anyway - the slot was double-leased" \
  || ok "treehouse get never ran, so nothing was double-leased"

# A holder must match a lease exactly. A substring test over the raw JSON would
# report WO-TEST-a6 as holding the slot that WO-TEST-a6cb actually holds, and
# the close-out for the shorter ticket would then release the longer one's
# workbench.
use "$S/held.json"
bash "$SLOT" holder --holder WO-TEST-a6 --repo "$R" >/dev/null 2>&1
[ $? -eq 3 ] && ok "a holder that is a prefix of another matches nothing" \
  || bad "prefix matching claimed an unrelated holder's slot"

# get exits 0 having recorded nothing. Reading rc would hand back a path into a
# slot this holder does not own.
use "$S/empty.json"
OUT=$(TH_PATH=/pool/1/repo bash "$SLOT" acquire --holder WO-TEST-a6cb --repo "$R" 2>&1); RC=$?
[ $RC -eq 5 ] && ok "get exiting 0 with no lease recorded exits 5" || bad "a phantom acquire exited $RC"
grep -q 'nothing was acquired' <<<"$OUT" \
  && ok "and says nothing was acquired" || bad "the phantom-acquire message is unclear"

hd "slot.sh - release, the load-bearing half"
# THE CASE THIS SCRIPT EXISTS FOR. A dirty tree makes treehouse prompt, the
# prompt takes its no-TTY default, the return is abandoned, the slot stays
# leased - and it exits 0. TH_AFTER is unset, so the pool does not move.
use "$S/held.json"
OUT=$(TH_RC=0 bash "$SLOT" release --holder WO-TEST-a6cb --repo "$R" 2>&1); RC=$?
[ $RC -eq 5 ] && ok "return exiting 0 with the slot still leased exits 5" \
  || bad "a leaked slot exited $RC - the close-out would report success"
grep -q 'still leased' <<<"$OUT" \
  && ok "and the failure says the slot is still leased" || bad "the leak message does not say what leaked"
grep -q -i 'uncommitted' <<<"$OUT" \
  && ok "and names the usual cause" || bad "the leak message does not name the cause"
grep -q 'treehouse return /pool/1/repo' <<<"$OUT" \
  && ok "and hands back the command that frees it" || bad "the leak message has no recovery command"

# The mirror, and the one that proves the claim rather than restating it: a
# NON-ZERO return that did free the slot is a success, because the pool is the
# authority and the exit code is not consulted in either direction.
use "$S/held.json"
TH_RC=1 TH_AFTER="$S/free.json" bash "$SLOT" release --holder WO-TEST-a6cb --repo "$R" >/dev/null 2>&1
[ $? -eq 0 ] && ok "return exiting 1 having freed the slot is a success" \
  || bad "release read the exit code instead of the pool"

use "$S/held.json"
TH_RC=0 TH_AFTER="$S/free.json" bash "$SLOT" release --holder WO-TEST-a6cb --repo "$R" >/dev/null 2>&1
[ $? -eq 0 ] && ok "a clean release exits 0" || bad "a clean release did not exit 0"
LOG=$(cat "$TH_LOG")
grep -q -- 'return /pool/1/repo --if-lease-holder WO-TEST-a6cb' <<<"$LOG" \
  && ok "release guards with --if-lease-holder" \
  || bad "release did not pass --if-lease-holder - it could return another agent's slot"

# Releasing what you do not hold is the state release exists to reach, so it is
# success. Otherwise re-running a finished close-out reports a problem it does
# not have.
use "$S/free.json"
bash "$SLOT" release --holder WO-TEST-a6cb --repo "$R" >/dev/null 2>&1
[ $? -eq 0 ] && ok "releasing a slot you do not hold is success" || bad "an idempotent release failed"
LOG=$(cat "$TH_LOG")
grep -q '^return' <<<"$LOG" \
  && bad "it called return on a slot it does not hold" \
  || ok "and it does not call return on a slot it does not hold"

# The freed slot the close-out is standing in. Keying on the status field would
# read "you're here" as occupied and report a leak on every clean close-out.
use "$S/here.json"
bash "$SLOT" release --holder WO-TEST-a6cb --repo "$R" >/dev/null 2>&1
[ $? -eq 0 ] && ok "a slot reporting \"you're here\" is not read as still held" \
  || bad "the 'you're here' status was mistaken for a lease"

hd "slot.sh - holder and status"
use "$S/two.json"
[ "$(bash "$SLOT" holder --holder WO-TEST-other --repo "$R" 2>/dev/null)" = "/pool/2/repo" ] \
  && ok "holder finds a record sitting behind nested processes" \
  || bad "the record was cut in half by its processes array"
bash "$SLOT" holder --holder WO-TEST-nobody --repo "$R" >/dev/null 2>&1
[ $? -eq 3 ] && ok "holder exits 3 when the label holds nothing" || bad "holder did not exit 3"

MAP=$(bash "$SLOT" status --repo "$R" 2>/dev/null)
[ "$(printf '%s\n' "$MAP" | wc -l)" = "2" ] \
  && ok "status prints one row per slot" || bad "status printed the wrong number of rows"
ROW=$(printf 'WO-TEST-other\t2\t/pool/2/repo')
grep -qxF -- "$ROW" <<<"$MAP" \
  && ok "status is keyed by holder, then name, then path" || bad "the status row shape is wrong"
ROW=$(printf -- '-\t1\t/pool/1/repo')
grep -qxF -- "$ROW" <<<"$MAP" \
  && ok "an unleased slot shows '-' for its holder" || bad "an unleased slot was not marked"
use "$S/empty.json"
[ -z "$(bash "$SLOT" status --repo "$R" 2>/dev/null)" ] \
  && ok "an empty pool prints nothing" || bad "an empty pool printed something"

hd "Result"
printf '  %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
