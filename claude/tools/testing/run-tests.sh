#!/usr/bin/env bash
#
# run-tests.sh - the only entry point for the tools in claude/tools/.
#
# Everything runs inside Podman, per root CLAUDE.md Rule 14, which has no size
# threshold: a single --help run whose purpose is to check that something works
# goes in a container too.
#
#   --network=none      no check reaches the network. The registry fetch is
#                       stubbed, and an unreachable registry is therefore the
#                       default state rather than something to arrange
#   /repo mounted ro    nothing writes next to itself, which also proves
#                       skill-sync.sh never writes into the repository it reads
#   /work separate      every fixture and every output lands in a scratch mount
#   --userns=keep-id    files in that mount are owned by you, not by root
#
# The failure cases are the point. skill-sync.sh's whole contract is what it does
# when something is wrong: silence when the project does not use the system, a
# loud two-line warning and exit 0 when the registry is unreachable, and a
# refusal when a name is not a name. A green happy path cannot tell a working
# guard from a decorative one.
#
# No -e, deliberately. Many checks here run a command that is expected to fail,
# and under -e the first of them ends the run and reports the assertion passing
# as an error. Every step that must not continue after a failure guards itself.
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TOOLS_DIR=$(cd "$HERE/.." && pwd)
REPO_ROOT=$(cd "$TOOLS_DIR/../.." && pwd)
IMAGE="${CLAUDE_TOOLS_TEST_IMAGE:-localhost/dotfiles-claude-tools-test:1}"

# Re-exec inside the container unless we are already in it.
if [[ ${IN_CLAUDE_TOOLS_CONTAINER:-0} != 1 ]]; then
  command -v podman >/dev/null 2>&1 || {
    printf 'podman is required: every check in this suite runs in a container.\n' >&2
    printf 'Running these on the host would prove only that they work on this machine.\n' >&2
    exit 1
  }
  if ! podman image exists "$IMAGE"; then
    printf 'building %s (needs network; the checks run with --network=none)\n' "$IMAGE"
    podman build -t "$IMAGE" -f "$HERE/Containerfile" "$HERE" >/dev/null || {
      printf 'image build failed\n' >&2; exit 1; }
  fi
  SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-claude-tools-test.XXXXXX")
  trap 'rm -rf -- "$SCRATCH"' EXIT INT TERM
  exec podman run --rm --userns=keep-id --network=none \
    -v "$REPO_ROOT:/repo:ro,Z" -v "$SCRATCH:/work:Z" -w /work \
    -e IN_CLAUDE_TOOLS_CONTAINER=1 --entrypoint="" \
    "$IMAGE" bash /repo/claude/tools/testing/run-tests.sh
fi

# ── inside the container from here ─────────────────────────────────────────────
WORK=${WORK:-/work}
PASS=0
FAIL=0

ok()  { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
hd()  { printf '\n=== %s\n' "$1"; }

check() { if [[ $2 -eq 0 ]]; then ok "$1"; else bad "$1"; fi; }

# Inverts a command's success into check()'s 0-is-good convention. Written as an
# if rather than arithmetic on $? because a non-zero that is not 1 is still a
# failure and must not read as a pass.
neg() { if "$@" >/dev/null 2>&1; then echo 1; else echo 0; fi; }

expect_rc() { # desc want cmd...
  local desc=$1 want=$2 got
  shift 2
  "$@" >/dev/null 2>&1
  got=$?
  if [[ $got -eq $want ]]; then ok "$desc (exit $got)"; else bad "$desc (exit $got, want $want)"; fi
}

# Copied out of the read-only mount so nothing runs from a path a check could
# write to.
mkdir -p "$WORK/bin"
cp /repo/claude/tools/skill-sync.sh "$WORK/bin/"
SS="$WORK/bin/skill-sync.sh"

PROJ="$WORK/proj"
REGFIX="$WORK/registry.json"
OUT="$WORK/out"
ERR="$WORK/err"
COUNT="$WORK/curl-count"

# ── fixtures ───────────────────────────────────────────────────────────────────
# Written before the parser was, so that a fixture invented while chasing a
# failing assertion cannot encode the bug it was invented to explain.
#
# The shape is the registry skill-version.sh actually renders: one entry per
# line, a fixed key set on every entry including an empty requires, and a tools
# block whose entries look exactly like skill entries and must not be read as
# skills.
mkregistry() {
  cat > "$REGFIX" <<'EOF'
{
  "schema": 2,
  "generator": "skill-version.sh",
  "skills": {
    "cartography": { "version": "1.0.3", "sha256": "aaa1", "type": "skill", "requires": ["work-order"] },
    "container-sandbox": { "version": "1.1.0", "sha256": "aaa2", "type": "skill", "requires": [] },
    "deep-1": { "version": "1.0.0", "sha256": "aaa3", "type": "skill", "requires": ["deep-2"] },
    "deep-2": { "version": "1.0.0", "sha256": "aaa4", "type": "skill", "requires": ["deep-3"] },
    "deep-3": { "version": "1.0.0", "sha256": "aaa5", "type": "skill", "requires": [] },
    "living-docs": { "version": "1.0.1", "sha256": "aaa6", "type": "skill", "requires": ["work-order"] },
    "loop-a": { "version": "1.0.0", "sha256": "aaa7", "type": "skill", "requires": ["loop-b"] },
    "loop-b": { "version": "1.0.0", "sha256": "aaa8", "type": "skill", "requires": ["loop-a"] },
    "work-order": { "version": "1.0.0", "sha256": "aaa9", "type": "skill", "requires": [] }
  },
  "tools": {
    "read-only-notice": { "version": "1.0.0", "sha256": "bbb1" },
    "skill-sync": { "version": "1.0.0", "sha256": "bbb2" }
  }
}
EOF
}

# $1 = the [skills] body, already formatted. Everything else is held constant so
# a case that changes the manifest changes one thing.
mkproject() {
  rm -rf "$PROJ"
  mkdir -p "$PROJ/.claude/cache"
  {
    printf '# .claude/skills.toml\n'
    printf '# What this project uses.\n\n'
    printf '[skills]\n'
    printf '%s\n\n' "$1"
    printf '[agents]\n'
    printf 'use = [\n  "k8s-master",\n]\n'
  } > "$PROJ/.claude/skills.toml"
}

mkreceipt() {
  cat > "$PROJ/.claude/cache/skills-receipt.json" <<'EOF'
{
  "synced": "2026-08-21T18:04:11Z",
  "source": "jkkelley/dotfiles@a1b7bb1",
  "status": "ok",
  "owned": ["work-order", "gone-skill", "container-sandbox"],
  "skills": {
    "work-order": { "version": "1.0.0", "sha256": "aaa9" }
  }
}
EOF
}

FETCH_ATTEMPTS_EXPECTED=3

# The registry fetch is stubbed rather than installed, per skill-testing.md:
# what curl *reports* is the input under test. The counter proves the retry loop
# retries, which no assertion on the final exit code can.
mkstub() { # $1 = fail | empty | flaky | ok | real
  mkdir -p "$WORK/stub"
  printf '0' > "$COUNT"
  cat > "$WORK/stub/curl" <<STUB
#!/usr/bin/env bash
n=\$(cat "$COUNT" 2>/dev/null)
n=\$(( \${n:-0} + 1 ))
printf '%s' "\$n" > "$COUNT"
dest=""; prev=""
for a in "\$@"; do [[ \$prev == -o ]] && dest=\$a; prev=\$a; done
case "$1" in
  fail)  exit 7 ;;
  empty) : > "\$dest" ;;
  flaky) if (( n < $FETCH_ATTEMPTS_EXPECTED )); then exit 7; fi; cat "$REGFIX" > "\$dest" ;;
  ok)    cat "$REGFIX" > "\$dest" ;;
  real)  cat /repo/claude/skills/registry.json > "\$dest" ;;
esac
STUB
  chmod +x "$WORK/stub/curl"
}

# Runs the tool in the project directory with the stub on PATH, capturing the
# two streams separately - "prints nothing at all" is a claim about both, and
# asserting on stdout alone would pass with a message on stderr.
run_sync() { # $1... = arguments
  ( cd "$PROJ" && PATH="$WORK/stub:$PATH" bash "$SS" "$@" ) > "$OUT" 2> "$ERR"
}

# Runs it with no stub at all, so curl genuinely does not exist.
run_sync_nocurl() {
  ( cd "$PROJ" && bash "$SS" "$@" ) > "$OUT" 2> "$ERR"
}

plan_has() { # tag name
  grep -qxF "$(printf '%-8s  %s' "$1" "$2")" "$OUT"
}

snapshot() { # $1 = dir; a listing of every file and its hash
  ( cd "$1" && find . -type f -exec sha256sum {} + 2>/dev/null | sort )
}

MANIFEST_MAIN='use = [
  "cartography",        # pulls work-order transitively
  "deep-1",             # pulls deep-2, which pulls deep-3
  "container-sandbox",
  "no-such-skill",      # in no registry
  "cartography",        # declared twice on purpose
]'

# ── 1. entry points ────────────────────────────────────────────────────────────
hd "entry points"
check "the file carries a skill-tool-version marker in its first 20 lines" \
  "$(head -20 "$SS" | grep -q 'skill-tool-version: [0-9]\+\.[0-9]\+\.[0-9]\+'; echo $?)"
expect_rc "--help exits 0" 0 bash "$SS" --help
expect_rc "no arguments is a usage error, not a silent sync" 2 bash "$SS"
expect_rc "an unknown argument is rejected" 2 bash "$SS" --frobnicate
bash "$SS" >"$OUT" 2>"$ERR"
check "the usage error goes to stderr, never stdout" \
  "$([[ ! -s $OUT && -s $ERR ]]; echo $?)"

# ── 2. AC-H2: --boot is silent where the system does not apply ─────────────────
# The hook fires in every project on the machine. Most of them have never heard
# of this system, and in those the correct output is nothing at all - on both
# streams, because a message on stderr is still a message in a terminal.
hd "AC-H2: --boot says nothing where there is nothing to do"
mkregistry
mkstub ok
rm -rf "$PROJ"; mkdir -p "$PROJ"
run_sync --boot
rc=$?
check "--boot with no manifest exits 0" "$([[ $rc -eq 0 ]]; echo $?)"
check "--boot with no manifest prints nothing on stdout" "$([[ ! -s $OUT ]]; echo $?)"
check "--boot with no manifest prints nothing on stderr" "$([[ ! -s $ERR ]]; echo $?)"

mkproject "$MANIFEST_MAIN"
touch "$PROJ/.claude/cache/.sync-stamp"
run_sync --boot
rc=$?
check "--boot with a stamp under 15 minutes old exits 0" "$([[ $rc -eq 0 ]]; echo $?)"
check "a fresh stamp prints nothing on stdout" "$([[ ! -s $OUT ]]; echo $?)"
check "a fresh stamp prints nothing on stderr" "$([[ ! -s $ERR ]]; echo $?)"

# The guard has to be a guard, not a permanent silence. Without this the two
# checks above pass on a --boot that never does anything.
touch -d '20 minutes ago' "$PROJ/.claude/cache/.sync-stamp"
run_sync --boot
check "a stamp older than 15 minutes does NOT suppress the run" "$([[ -s $OUT ]]; echo $?)"
rm -f "$PROJ/.claude/cache/.sync-stamp"

# ── 3. AC-H1: the resolved owned set ───────────────────────────────────────────
hd "AC-H1: resolution"
mkproject "$MANIFEST_MAIN"
mkreceipt
mkstub ok
run_sync --plan
rc=$?
check "--plan against a reachable registry exits 0" "$([[ $rc -eq 0 ]]; echo $?)"

check "a declared skill is owned"                "$(plan_has owned container-sandbox; echo $?)"
check "a declared skill with a dependency is owned" "$(plan_has owned cartography; echo $?)"
check "the dependency it requires is owned too"  "$(plan_has owned work-order; echo $?)"
check "requires is transitive: deep-2 arrived via deep-1" "$(plan_has owned deep-2; echo $?)"
check "requires is transitive past one hop: deep-3 arrived via deep-2" \
  "$(plan_has owned deep-3; echo $?)"
check "a name the registry does not have is reported as unknown" \
  "$(plan_has unknown no-such-skill; echo $?)"
check "an unknown name is not silently owned" "$(neg plan_has owned no-such-skill)"
check "a name under [agents] never reaches the skills set" "$(neg plan_has owned k8s-master)"
check "a name under [agents] is not reported as an unknown skill either" \
  "$(neg plan_has unknown k8s-master)"
check "a skill declared twice is owned once" \
  "$([[ "$(grep -c '^owned  *cartography$' "$OUT")" -eq 1 ]]; echo $?)"
check "the owned set is exactly the six expected names" \
  "$([[ "$(grep -c '^owned ' "$OUT")" -eq 6 ]]; echo $?)"
check "the tools block is not read as skills: skill-sync is not owned" \
  "$(neg plan_has owned skill-sync)"
check "the tools block is not read as skills: read-only-notice is not owned" \
  "$(neg plan_has owned read-only-notice)"
check "the plan is sorted, so two runs can be compared" \
  "$([[ "$(grep '^owned ' "$OUT")" == "$(grep '^owned ' "$OUT" | sort)" ]]; echo $?)"

# ── 4. the receipt: what the previous sync owned ───────────────────────────────
# The receipt answers exactly one question - which directories the sync owns -
# and getting it wrong in the "no longer declared" direction silently deletes
# hand-authored work in a gitignored directory. Part two acts on `dropped`; this
# is where the answer it will act on is proved.
hd "the receipt"
check "a name in the receipt is reported as previous" "$(plan_has previous gone-skill; echo $?)"
check "a name in the receipt and still declared is previous too" \
  "$(plan_has previous work-order; echo $?)"
check "a name in the receipt and no longer declared is dropped" \
  "$(plan_has dropped gone-skill; echo $?)"
check "a name in the receipt and still declared is NOT dropped" \
  "$(neg plan_has dropped work-order)"
check "a name in the receipt and still declared indirectly is NOT dropped" \
  "$(neg plan_has dropped container-sandbox)"
check "nothing is dropped that the receipt never claimed" \
  "$([[ "$(grep -c '^dropped ' "$OUT")" -eq 1 ]]; echo $?)"

# Missing receipt: sync owns nothing, so nothing can be dropped. Orphaning a
# managed directory is the correct failure; deleting a local one is not.
rm -f "$PROJ/.claude/cache/skills-receipt.json"
run_sync --plan
check "a missing receipt still resolves the owned set" "$(plan_has owned cartography; echo $?)"
check "a missing receipt means sync owns nothing previously" \
  "$([[ "$(grep -c '^previous ' "$OUT")" -eq 0 ]]; echo $?)"
check "a missing receipt drops nothing" \
  "$([[ "$(grep -c '^dropped ' "$OUT")" -eq 0 ]]; echo $?)"

# A corrupt receipt collapses to the same answer rather than throwing.
printf '{ this is not json at all\n' > "$PROJ/.claude/cache/skills-receipt.json"
run_sync --plan
rc=$?
check "a corrupt receipt does not stop resolution" "$([[ $rc -eq 0 ]]; echo $?)"
check "a corrupt receipt drops nothing" \
  "$([[ "$(grep -c '^dropped ' "$OUT")" -eq 0 ]]; echo $?)"
mkreceipt

# ── 5. the manifest parser ─────────────────────────────────────────────────────
hd "the manifest parser"
mkproject 'use = ["work-order", "living-docs"]'
run_sync --plan
check "an inline array on one line is read" "$(plan_has owned living-docs; echo $?)"
check "its transitive dependency is read too" "$(plan_has owned work-order; echo $?)"

mkproject 'use = [
  "work-order",   # a trailing comment
]'
run_sync --plan
check "a comment after an entry is not part of the name" "$(plan_has owned work-order; echo $?)"
check "a commented line contributes nothing" \
  "$([[ "$(grep -c '^owned ' "$OUT")" -eq 1 ]]; echo $?)"

mkproject 'use = []'
run_sync --plan
rc=$?
check "an empty manifest resolves to an empty owned set, not an error" \
  "$([[ $rc -eq 0 && "$(grep -c '^owned ' "$OUT")" -eq 0 ]]; echo $?)"

# A name becomes a directory in part two. It is refused here, by name, rather
# than pasted into a path there.
mkproject 'use = ["../../etc", "work-order", "has space"]'
run_sync --plan
check "a path traversal is refused rather than resolved" "$(neg grep -q '\.\./\.\.' "$OUT")"
check "the refusal is reported loudly on stderr" "$(grep -q 'refusing the name' "$ERR"; echo $?)"
check "a name with a space in it is refused" "$(neg grep -q 'has space' "$OUT")"
check "the valid name beside them still resolves" "$(plan_has owned work-order; echo $?)"

# The two sections must not bleed into each other in either direction.
mkproject 'use = ["work-order"]'
run_sync --plan
check "only [skills] feeds the owned set, with [agents] present" \
  "$([[ "$(grep -c '^owned ' "$OUT")" -eq 1 ]]; echo $?)"

# ── 6. cycles ──────────────────────────────────────────────────────────────────
# A cycle in requires must terminate. Inside a SessionStart hook the failure
# mode is not a hang, it is a 30-second timeout that looks like a slow network.
hd "a dependency cycle"
mkproject 'use = ["loop-a"]'
run_sync --plan
rc=$?
check "a cycle terminates and exits 0" "$([[ $rc -eq 0 ]]; echo $?)"
check "the declared side of the cycle is owned" "$(plan_has owned loop-a; echo $?)"
check "the side it requires is owned"           "$(plan_has owned loop-b; echo $?)"
check "neither side is owned twice" \
  "$([[ "$(grep -c '^owned ' "$OUT")" -eq 2 ]]; echo $?)"

# ── 7. AC-H3: the registry is unreachable ──────────────────────────────────────
# Exit 0 on failure is the assertion most likely to be written backwards by
# someone who has just read that failures should be loud. Both halves are
# asserted here: loud, and still 0.
hd "AC-H3: an unreachable registry"
mkproject "$MANIFEST_MAIN"
mkreceipt
mkstub fail
run_sync --boot
rc=$?
check "--boot exits 0 when the registry is unreachable" "$([[ $rc -eq 0 ]]; echo $?)"
check "it tried exactly $FETCH_ATTEMPTS_EXPECTED times" \
  "$([[ "$(cat "$COUNT")" -eq $FETCH_ATTEMPTS_EXPECTED ]]; echo $?)"
check "the failure is two lines and no more" \
  "$([[ "$(wc -l < "$OUT")" -eq 2 ]]; echo $?)"
check "the first line names the failure" \
  "$(grep -qx '!! SKILL SYNC FAILED - registry unreachable after 3 tries' "$OUT"; echo $?)"
check "the second line dates the skills from the receipt" \
  "$(grep -qx '!! Skills are as of 2026-08-21. Say so before doing skill-dependent work.' "$OUT"; echo $?)"
check "the failure lands on stdout, where a hook's output reaches the agent" \
  "$([[ ! -s $ERR ]]; echo $?)"
check "no plan is printed when nothing could be resolved" "$(neg grep -q '^owned ' "$OUT")"

# Without a receipt there is no date to give, and the second line still has to
# be a sentence rather than a blank.
rm -f "$PROJ/.claude/cache/skills-receipt.json"
mkstub fail
run_sync --boot
check "with no receipt the second line still reads as a sentence" \
  "$(grep -qx '!! Skills are as of an unknown date. Say so before doing skill-dependent work.' "$OUT"; echo $?)"
mkreceipt

# A response that arrives empty is a failed fetch, not an empty registry.
mkstub empty
run_sync --boot
check "an empty response is treated as a failure, not as a registry with no skills" \
  "$(grep -q '^!! SKILL SYNC FAILED' "$OUT"; echo $?)"
check "an empty response is retried the full $FETCH_ATTEMPTS_EXPECTED times" \
  "$([[ "$(cat "$COUNT")" -eq $FETCH_ATTEMPTS_EXPECTED ]]; echo $?)"

# The retry has to actually retry. A loop that gives up after one attempt passes
# every assertion above.
mkstub flaky
run_sync --boot
rc=$?
check "a fetch that succeeds on the last attempt resolves normally" \
  "$([[ $rc -eq 0 ]]; echo $?)"
check "and the plan it produces is the real one" "$(plan_has owned work-order; echo $?)"

# --plan is not a session and does not owe one an exit 0.
mkstub fail
run_sync --plan
rc=$?
check "--plan exits 1 when the registry is unreachable" "$([[ $rc -eq 1 ]]; echo $?)"
check "--plan still prints the two-line failure" \
  "$(grep -q '^!! SKILL SYNC FAILED' "$OUT"; echo $?)"

# curl absent is a different sentence, because "unreachable after 3 tries" sends
# the reader to look at a network that is fine.
run_sync_nocurl --boot
rc=$?
check "--boot with no curl on PATH still exits 0" "$([[ $rc -eq 0 ]]; echo $?)"
check "the message says curl is missing rather than blaming the network" \
  "$(grep -qx '!! SKILL SYNC FAILED - curl is not installed, so the registry cannot be fetched' "$OUT"; echo $?)"

# ── 8. this build writes nothing ───────────────────────────────────────────────
# The one claim that has to hold for every path above: resolution is a pure
# function of its inputs. Part two is where writing starts, and a part one that
# had already started writing would be discovered there, on a real project.
hd "nothing is written"
mkproject "$MANIFEST_MAIN"
mkreceipt
before=$(snapshot "$PROJ")
mkstub ok;    run_sync --plan
mkstub ok;    run_sync --boot
mkstub fail;  run_sync --boot
after=$(snapshot "$PROJ")
check "the project is byte-identical after a plan, a boot and a failed boot" \
  "$([[ "$before" == "$after" ]]; echo $?)"
check "no stamp was written" "$([[ ! -e "$PROJ/.claude/cache/.sync-stamp" ]]; echo $?)"
check "no skills directory was created" "$([[ ! -e "$PROJ/.claude/skills" ]]; echo $?)"

# ── 9. Rule 17 ─────────────────────────────────────────────────────────────────
# A grep over the source is a legitimate test here. flock does not exist on Git
# Bash and its absence surfaces as a lock timeout that never happened, which is
# untraceable from the symptom; cmp and diff are missing from minimal images.
# None of the three fails in a way that points at itself.
#
# Comments are stripped first. The script's own header says it uses none of the
# three, and grepping the raw file finds that sentence and calls it a violation -
# a check that fails on a file documenting its own compliance is a check nobody
# will keep.
hd "Rule 17: portable to Git Bash"
CODE=$(awk '{ sub(/^[[:space:]]*#.*/, ""); sub(/[[:space:]]#.*/, "") } NF' "$SS")
check "the stripped source is not empty, so these three checks mean something" \
  "$([[ $(printf '%s\n' "$CODE" | wc -l) -gt 100 ]]; echo $?)"
check "the source calls no flock" "$(neg grep -qw flock <<<"$CODE")"
check "the source calls no cmp"   "$(neg grep -qw cmp <<<"$CODE")"
check "the source calls no diff"  "$(neg grep -qw diff <<<"$CODE")"

# ── 10. the real registry ──────────────────────────────────────────────────────
# The fixtures prove the mechanism against a registry written by hand. This
# proves the parser against the file skill-version.sh actually renders, and the
# two real requires edges in it - both on work-order, from cartography and from
# living-docs. A parser correct only against its own fixtures is the failure this
# catches.
hd "the repository's own registry.json"
mkproject 'use = ["cartography"]'
mkstub real
run_sync --plan
rc=$?
check "the real registry parses" "$([[ $rc -eq 0 ]]; echo $?)"
check "cartography resolves against it" "$(plan_has owned cartography; echo $?)"
check "the real cartography -> work-order edge is followed" "$(plan_has owned work-order; echo $?)"

mkproject 'use = ["living-docs"]'
run_sync --plan
check "the real living-docs -> work-order edge is followed" "$(plan_has owned work-order; echo $?)"

mkproject 'use = ["hydration-prompt"]'
run_sync --plan
check "a real skill with no requires pulls nothing in" \
  "$([[ "$(grep -c '^owned ' "$OUT")" -eq 1 ]]; echo $?)"

# ── summary ────────────────────────────────────────────────────────────────────
printf '\n=========================================\n'
printf '  PASS %d   FAIL %d\n' "$PASS" "$FAIL"
printf '=========================================\n'
[[ $FAIL -eq 0 ]]
