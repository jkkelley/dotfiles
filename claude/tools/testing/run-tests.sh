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
# The tag is bumped whenever the Containerfile changes. `podman image exists`
# below only builds when the tag is absent, so an edited Containerfile under an
# unchanged tag means every machine that already ran this suite keeps the old
# image and the new checks fail for a reason that has nothing to do with them.
# :2 added jq.
IMAGE="${CLAUDE_TOOLS_TEST_IMAGE:-localhost/dotfiles-claude-tools-test:2}"

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
UPSTREAM="$WORK/upstream"           # the fake dotfiles tree the tarball is made of
TARBALL="$WORK/src.tar.gz"
TARMODE="$WORK/mode-tar"            # ok | fail | corrupt | noskills
SELFMODE="$WORK/mode-self"          # ok | fail | broken | empty
SELFVER="$WORK/mode-self-version"   # the version the served replacement carries

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
    "no-heading": { "version": "1.0.0", "sha256": "aab1", "type": "skill", "requires": [] },
    "not-in-tree": { "version": "1.0.0", "sha256": "aab2", "type": "skill", "requires": [] },
    "stale-notice": { "version": "1.0.0", "sha256": "aab3", "type": "skill", "requires": [] },
    "work-order": { "version": "1.2.3", "sha256": "aaa9", "type": "skill", "requires": [] }
  },
  "tools": {
    "read-only-notice": { "version": "1.0.0", "sha256": "bbb1" },
    "skill-sync": { "version": "1.0.0", "sha256": "bbb2" }
  }
}
EOF
}

# The registry's own skill-sync version is deliberately *older* than the file
# under test, so no ordinary case triggers a self-update and quietly swaps the
# binary the rest of the suite is asserting on. The self-update group publishes
# a newer one on purpose, and puts the real file back afterwards.
mkregistry_publishing_self() { # $1 = the version the registry claims
  mkregistry
  local tmp="$WORK/registry.tmp"
  awk -v ver="$1" '
    /"skill-sync"[[:space:]]*:/ { sub(/"version": "[^"]*"/, "\"version\": \"" ver "\"") }
    { print }' "$REGFIX" > "$tmp" && mv "$tmp" "$REGFIX"
}

# The fake dotfiles tree the tarball is cut from. Every skill the registry
# fixture lists exists here except `not-in-tree`, which is the "the registry
# promises a skill the source does not have" case and must stay absent.
#
# Three of them carry a deliberately awkward SKILL.md, because the notice
# renderer is the only thing in this ticket that rewrites a file's contents
# rather than moving it whole:
#
#   stale-notice  already carries the inline notice all 43 upstream SKILL.md
#                 files still have, naming skill-update.sh. The rendered one has
#                 to replace it rather than land beside it
#   no-heading    has no `# ` heading at all, so there is nowhere to insert
#   work-order    is more than one file, which is 20 of the 43 in real life
mkupstream() {
  local name root="$UPSTREAM/dotfiles-main"
  rm -rf "$UPSTREAM"
  mkdir -p "$root/claude/tools/partials"
  cp /repo/claude/tools/partials/read-only-notice.md.tmpl "$root/claude/tools/partials/"

  for name in cartography container-sandbox deep-1 deep-2 deep-3 living-docs \
              loop-a loop-b work-order stale-notice no-heading; do
    mkdir -p "$root/claude/skills/$name"
    {
      printf -- '---\nname: %s\nversion: 9.9.9\n---\n\n' "$name"
      printf '# %s\n\n' "$name"
      printf 'Upstream body for %s.\n' "$name"
    } > "$root/claude/skills/$name/SKILL.md"
  done

  mkdir -p "$root/claude/skills/work-order/scripts"
  printf '#!/usr/bin/env bash\nprintf work-order\n' \
    > "$root/claude/skills/work-order/scripts/work-order.sh"

  {
    printf -- '---\nname: stale-notice\n---\n\n'
    printf '# Stale Notice\n\n'
    printf '> **This copy is read-only.**\n'
    printf '> An older wording that named the other tool.\n'
    printf '> `skill-update.sh` replaces the skill directory rather than merging into it.\n\n'
    printf 'Upstream body for stale-notice.\n'
  } > "$root/claude/skills/stale-notice/SKILL.md"

  {
    printf -- '---\nname: no-heading\n---\n\n'
    printf 'This file has no level-one heading anywhere in it.\n'
  } > "$root/claude/skills/no-heading/SKILL.md"

  tar -czf "$TARBALL" -C "$UPSTREAM" dotfiles-main
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

# A receipt claiming exactly the names given, and nothing else. The ownership
# matrix is a statement about this list, so each row sets it explicitly rather
# than inheriting the shared fixture's.
mkreceipt_owning() { # $@ = names
  local first=1 name
  {
    printf '{\n  "synced": "2026-08-21T18:04:11Z",\n'
    printf '  "source": "jkkelley/dotfiles@main",\n  "status": "ok",\n'
    printf '  "owned": ['
    for name in "$@"; do
      ((first)) || printf ', '
      printf '"%s"' "$name"
      first=0
    done
    printf '],\n  "skills": {}\n}\n'
  } > "$PROJ/.claude/cache/skills-receipt.json"
}

# A directory under .claude/skills/ that the sync did not put there. The marker
# file is what tells "replaced wholesale" apart from "merged into", which is the
# difference the read-only notice exists to warn people about.
plant_skill() { # $1 = name
  mkdir -p "$PROJ/.claude/skills/$1"
  printf 'planted, not synced\n' > "$PROJ/.claude/skills/$1/LOCAL-MARKER"
  {
    printf -- '---\nname: %s\n---\n\n' "$1"
    printf '# %s\n\nPlanted body, not the upstream one.\n' "$1"
  } > "$PROJ/.claude/skills/$1/SKILL.md"
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

FETCH_ATTEMPTS_EXPECTED=3

# Every fetch is stubbed rather than installed, per skill-testing.md: what curl
# *reports* is the input under test. The counter proves the retry loop retries,
# which no assertion on the final exit code can.
#
# There are three fetches now and they fail independently - a reachable registry
# with an unreachable archive is a real state - so the registry's behaviour is
# this function's argument and the other two are files the cases write. Folding
# all three into one mode argument would be a five-by-four-by-four grid of names
# nobody could keep straight.
mkstub() { # $1 = fail | empty | flaky | ok | real   (the registry only)
  mkdir -p "$WORK/stub"
  printf '0' > "$COUNT"
  printf 'ok' > "$TARMODE"
  printf 'ok' > "$SELFMODE"
  printf '9.9.9' > "$SELFVER"
  cat > "$WORK/stub/curl" <<STUB
#!/usr/bin/env bash
dest=""; prev=""; url=""
for a in "\$@"; do
  [[ \$prev == -o ]] && dest=\$a
  [[ \$a == http* ]] && url=\$a
  prev=\$a
done

case "\$url" in
  *registry.json)
    n=\$(cat "$COUNT" 2>/dev/null)
    n=\$(( \${n:-0} + 1 ))
    printf '%s' "\$n" > "$COUNT"
    case "$1" in
      fail)  exit 7 ;;
      empty) : > "\$dest" ;;
      flaky) if (( n < $FETCH_ATTEMPTS_EXPECTED )); then exit 7; fi; cat "$REGFIX" > "\$dest" ;;
      ok)    cat "$REGFIX" > "\$dest" ;;
      real)  cat /repo/claude/skills/registry.json > "\$dest" ;;
    esac
    ;;
  *codeload*)
    case "\$(cat "$TARMODE" 2>/dev/null)" in
      fail)    exit 7 ;;
      empty)   : > "\$dest" ;;
      corrupt) printf 'not a tarball at all\n' > "\$dest" ;;
      slow)    printf 'started' > "$WORK/tar-started"; sleep 10; cat "$TARBALL" > "\$dest" ;;
      *)       cat "$TARBALL" > "\$dest" ;;
    esac
    ;;
  *skill-sync.sh)
    case "\$(cat "$SELFMODE" 2>/dev/null)" in
      fail)   exit 7 ;;
      empty)  : > "\$dest" ;;
      broken) { printf '# skill-tool-version: %s\n' "\$(cat "$SELFVER")"
                printf 'if [ this is not bash\n'; } > "\$dest" ;;
      *)      { printf '#!/usr/bin/env bash\n# skill-tool-version: %s\n' "\$(cat "$SELFVER")"
                printf 'exit 0\n'; } > "\$dest" ;;
    esac
    ;;
esac
STUB
  chmod +x "$WORK/stub/curl"
}

# Seconds a run will wait for the lock. Long enough that the parallel case is
# about locking rather than about how fast this machine is; overridden to 1 by
# the case that deliberately never releases it.
LOCKWAIT=30

# Fixed so two receipts can be compared byte for byte, per skill-testing.md.
NOW=2026-08-24T12:00:00Z

# Runs the tool in the project directory with the stub on PATH, capturing the
# two streams separately - "prints nothing at all" is a claim about both, and
# asserting on stdout alone would pass with a message on stderr.
run_sync() { # $1... = arguments
  ( cd "$PROJ" && PATH="$WORK/stub:$PATH" \
      SKILL_SYNC_LOCK_WAIT="$LOCKWAIT" SKILL_SYNC_NOW="$NOW" \
      bash "$SS" "$@" ) > "$OUT" 2> "$ERR"
}

# Runs it with no stub at all, so curl genuinely does not exist.
run_sync_nocurl() {
  ( cd "$PROJ" && bash "$SS" "$@" ) > "$OUT" 2> "$ERR"
}

# A full sync from a clean stamp. Almost every case below wants this and not
# --plan: --plan is the read-only half and proves nothing about installing.
sync_now() {
  rm -f "$PROJ/.claude/cache/.sync-stamp"
  run_sync --boot
}

receipt_owns() { # $1 = name
  grep -qF "\"$1\"" <<<"$(awk '/"owned"/ { print }' "$PROJ/.claude/cache/skills-receipt.json" 2>/dev/null)"
}

# Temp build directories currently sitting in the project's cache. Zero after a
# run that finished; one after a run that was killed.
count_builds() {
  local dir n=0
  for dir in "$PROJ/.claude/cache/.sync."*; do
    [[ -d $dir ]] && n=$((n + 1))
  done
  printf '%d' "$n"
}

receipt_status() {
  awk 'match($0, /"status"[[:space:]]*:[[:space:]]*"[^"]*"/) {
    s = substr($0, RSTART, RLENGTH); sub(/.*: "/, "", s); sub(/"$/, "", s); print s; exit
  }' "$PROJ/.claude/cache/skills-receipt.json" 2>/dev/null
}

plan_has() { # tag name
  grep -qxF "$(printf '%-8s  %s' "$1" "$2")" "$OUT"
}

snapshot() { # $1 = dir; a listing of every file and its hash
  ( cd "$1" && find . -type f -exec sha256sum {} + 2>/dev/null | sort )
}

# The source tree every --boot below installs from. Built once: it is a fixture,
# not a variable, and a case that needed a different one would be a case that had
# stopped testing the same thing as its neighbours.
mkupstream

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
sync_now
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
sync_now
check "with no receipt the second line still reads as a sentence" \
  "$(grep -qx '!! Skills are as of an unknown date. Say so before doing skill-dependent work.' "$OUT"; echo $?)"
mkreceipt

# A response that arrives empty is a failed fetch, not an empty registry.
mkstub empty
sync_now
check "an empty response is treated as a failure, not as a registry with no skills" \
  "$(grep -q '^!! SKILL SYNC FAILED' "$OUT"; echo $?)"
check "an empty response is retried the full $FETCH_ATTEMPTS_EXPECTED times" \
  "$([[ "$(cat "$COUNT")" -eq $FETCH_ATTEMPTS_EXPECTED ]]; echo $?)"

# The retry has to actually retry. A loop that gives up after one attempt passes
# every assertion above.
mkstub flaky
sync_now
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
rm -f "$PROJ/.claude/cache/.sync-stamp"
run_sync_nocurl --boot
rc=$?
check "--boot with no curl on PATH still exits 0" "$([[ $rc -eq 0 ]]; echo $?)"
check "the message says curl is missing rather than blaming the network" \
  "$(grep -qx '!! SKILL SYNC FAILED - curl is not installed, so the registry cannot be fetched' "$OUT"; echo $?)"

# ── 8. --plan writes nothing ───────────────────────────────────────────────────
# The read-only half stayed read-only. --boot installs now, so the claim it used
# to make for the whole script is made here for the one entry point that still
# owes it - and it is the entry point a human runs to find out what would happen.
hd "--plan writes nothing"
mkproject "$MANIFEST_MAIN"
mkreceipt
plant_skill some-local-thing
before=$(snapshot "$PROJ")
mkstub ok;   run_sync --plan
mkstub fail; run_sync --plan
mkstub real; run_sync --plan
after=$(snapshot "$PROJ")
check "the project is byte-identical after three plans, one of them failed" \
  "$([[ "$before" == "$after" ]]; echo $?)"
check "--plan writes no stamp" "$([[ ! -e "$PROJ/.claude/cache/.sync-stamp" ]]; echo $?)"
check "--plan takes no lock, or leaves none behind" \
  "$([[ ! -e "$PROJ/.claude/cache/.sync-lock" ]]; echo $?)"
check "--plan builds nothing" "$([[ "$(count_builds)" -eq 0 ]]; echo $?)"

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

# ── 11. AC-H1: the ownership matrix ────────────────────────────────────────────
# The highest-value group in the suite. `.claude/skills/` is blanket gitignored,
# hand-authored project-only skills legitimately live in it beside the managed
# ones, and a wrong answer in the last row deletes one of them with no diff, no
# recovery and nothing to notice it by.
#
# All four rows run off one sync, because the rows are not independent: the bug
# this catches is a sync that gets three of them right by treating the parent
# directory as its own.
hd "AC-H1: the ownership matrix"
mkregistry
mkupstream
mkstub ok

# The first sync a project ever runs, which is a manifest and nothing else. The
# lock is a directory inside .claude/cache/, so a cache that does not exist yet
# reads as a lock that cannot be taken - a 20-second wait and a loud failure on
# the single most common state this runs in.
rm -rf "$PROJ"
mkdir -p "$PROJ/.claude"
printf '[skills]\nuse = ["container-sandbox"]\n' > "$PROJ/.claude/skills.toml"
run_sync --boot
rc=$?
check "the first sync in a project with no .claude/cache exits 0" \
  "$([[ $rc -eq 0 ]]; echo $?)"
check "the first sync installs what is declared" \
  "$([[ -f "$PROJ/.claude/skills/container-sandbox/SKILL.md" ]]; echo $?)"
check "the first sync creates the cache it needs" \
  "$([[ -f "$PROJ/.claude/cache/skills-receipt.json" ]]; echo $?)"
check "the first sync did not stall on a lock it could not take" \
  "$(neg grep -q 'another sync has held' "$OUT")"

mkproject 'use = ["work-order", "container-sandbox"]'
mkreceipt_owning work-order gone-skill      # yes/yes, no/yes
plant_skill work-order                      # in the manifest and in the receipt
plant_skill gone-skill                      # in the receipt, no longer declared
plant_skill some-local-thing                # in neither. Not the sync's business
local_before=$(snapshot "$PROJ/.claude/skills/some-local-thing")

# Unreadable for the duration of the run. A snapshot proves the bytes did not
# change; this proves nothing so much as opened it, which is the actual claim -
# a sync that reads a local directory to decide about it is one refactor away
# from acting on what it read.
chmod 000 "$PROJ/.claude/skills/some-local-thing"
sync_now
rc=$?
chmod 755 "$PROJ/.claude/skills/some-local-thing"

check "a full sync exits 0" "$([[ $rc -eq 0 ]]; echo $?)"
check "in the manifest and in the receipt: the directory is replaced" \
  "$([[ ! -e "$PROJ/.claude/skills/work-order/LOCAL-MARKER" ]]; echo $?)"
check "replaced means replaced, not merged: the upstream body is what is there" \
  "$(grep -q 'Upstream body for work-order' "$PROJ/.claude/skills/work-order/SKILL.md"; echo $?)"
check "a skill that is more than one file arrives whole" \
  "$([[ -f "$PROJ/.claude/skills/work-order/scripts/work-order.sh" ]]; echo $?)"
check "in the manifest and not in the receipt: the directory is installed" \
  "$([[ -f "$PROJ/.claude/skills/container-sandbox/SKILL.md" ]]; echo $?)"
check "not in the manifest and in the receipt: the directory is removed" \
  "$([[ ! -e "$PROJ/.claude/skills/gone-skill" ]]; echo $?)"
check "in neither: the directory is still there" \
  "$([[ -d "$PROJ/.claude/skills/some-local-thing" ]]; echo $?)"
check "in neither: it is byte-identical" \
  "$([[ "$local_before" == "$(snapshot "$PROJ/.claude/skills/some-local-thing")" ]]; echo $?)"
check "in neither: the sync did not read it, and did not fail for lack of it" \
  "$(neg grep -q 'SKILL SYNC FAILED' "$OUT")"
check "in neither: it is not mentioned on stdout" \
  "$(neg grep -q some-local-thing "$OUT")"
check "in neither: it is not mentioned on stderr either" \
  "$(neg grep -q some-local-thing "$ERR")"
check "the parent directory is not rebuilt: it still holds all three names" \
  "$([[ "$(ls "$PROJ/.claude/skills" | sort | tr '\n' ' ')" == \
        "container-sandbox some-local-thing work-order " ]]; echo $?)"

# The receipt is the only record of the answer above, so it is asserted too.
check "the receipt claims what was installed" "$(receipt_owns work-order; echo $?)"
check "the receipt claims the newly installed one as well" \
  "$(receipt_owns container-sandbox; echo $?)"
check "the receipt no longer claims what was removed" "$(neg receipt_owns gone-skill)"
check "the receipt never claims a directory the sync did not install" \
  "$(neg receipt_owns some-local-thing)"
check "the receipt records the sync as ok" \
  "$([[ "$(receipt_status)" == ok ]]; echo $?)"
check "the receipt carries the registry's version for an installed skill" \
  "$(grep -q '"work-order": { "version": "1.2.3", "sha256": "aaa9" }' \
       "$PROJ/.claude/cache/skills-receipt.json"; echo $?)"
check "the stamp was written" "$([[ -f "$PROJ/.claude/cache/.sync-stamp" ]]; echo $?)"
check "the build directory was cleaned up" "$([[ "$(count_builds)" -eq 0 ]]; echo $?)"

# The receipt's writer and its reader are the same file on purpose. --plan reads
# it back with json_array and reports what it found, so this is the round trip
# rather than a second assertion about the same bytes.
run_sync --plan
check "the receipt it wrote is one its own reader reads back" \
  "$(plan_has previous work-order; echo $?)"
check "and the reader agrees about the newly installed one too" \
  "$(plan_has previous container-sandbox; echo $?)"
check "nothing is dropped when nothing changed" \
  "$([[ "$(grep -c '^dropped ' "$OUT")" -eq 0 ]]; echo $?)"

# The second sync is the one that proves the receipt is read rather than
# regenerated: nothing changed, so nothing may be dropped.
prev=$(snapshot "$PROJ/.claude/skills")
sync_now
check "a second sync with the same manifest changes nothing" \
  "$([[ "$prev" == "$(snapshot "$PROJ/.claude/skills")" ]]; echo $?)"
check "and it still claims both skills" \
  "$([[ "$(receipt_owns work-order && receipt_owns container-sandbox; echo $?)" -eq 0 ]]; echo $?)"

# ── 12. AC-H2: a missing or corrupt receipt orphans, never deletes ─────────────
# The failure mode of a lost receipt has to be a managed directory nobody
# removes, and never a local directory somebody loses.
hd "AC-H2: a lost receipt orphans rather than deletes"
mkproject 'use = ["container-sandbox"]'
plant_skill work-order        # was managed once, but there is no receipt to say so
plant_skill some-local-thing
sync_now
check "with no receipt at all the sync still installs what is declared" \
  "$([[ -f "$PROJ/.claude/skills/container-sandbox/SKILL.md" ]]; echo $?)"
check "with no receipt the undeclared managed directory is orphaned, not deleted" \
  "$([[ -f "$PROJ/.claude/skills/work-order/LOCAL-MARKER" ]]; echo $?)"
check "with no receipt a local directory is untouched" \
  "$([[ -f "$PROJ/.claude/skills/some-local-thing/LOCAL-MARKER" ]]; echo $?)"

mkproject 'use = ["container-sandbox"]'
plant_skill work-order
printf '{ this is not json at all\n' > "$PROJ/.claude/cache/skills-receipt.json"
sync_now
rc=$?
check "a corrupt receipt does not stop the sync" "$([[ $rc -eq 0 ]]; echo $?)"
check "a corrupt receipt deletes nothing" \
  "$([[ -f "$PROJ/.claude/skills/work-order/LOCAL-MARKER" ]]; echo $?)"
check "a corrupt receipt is replaced by a readable one" \
  "$([[ "$(receipt_status)" == ok ]]; echo $?)"

# A receipt is a file in a gitignored directory. A name in it becomes an rm -rf,
# so it is checked against NAME_RE exactly like a manifest name - and neither
# check covers the other, because they read different files.
mkproject 'use = ["container-sandbox"]'
mkreceipt_owning ../../etc "has space" gone-skill
plant_skill gone-skill
sync_now
check "a path traversal in the receipt is refused rather than removed" \
  "$(grep -q 'ignoring the receipt entry' "$ERR"; echo $?)"
check "the refusal names the offending entry" "$(grep -q '\.\./\.\./etc' "$ERR"; echo $?)"
check "the valid name beside it is still dropped" \
  "$([[ ! -e "$PROJ/.claude/skills/gone-skill" ]]; echo $?)"
check "a refused receipt entry never reaches the plan" "$(neg grep -q 'etc' "$OUT")"

# ── 13. AC-H3: every failure path exits 0, loudly, having destroyed nothing ────
hd "AC-H3: failure leaves the tree alone"
mkregistry
mkstub ok
mkproject 'use = ["work-order", "container-sandbox"]'
mkreceipt_owning work-order
plant_skill work-order
plant_skill some-local-thing

# The archive is the fetch part one never had. It fails separately from the
# registry: a reachable registry and an unreachable codeload is a real state.
printf 'fail' > "$TARMODE"
before=$(snapshot "$PROJ/.claude/skills")
sync_now
rc=$?
check "an unreachable archive exits 0" "$([[ $rc -eq 0 ]]; echo $?)"
check "an unreachable archive says so loudly" \
  "$(grep -q '^!! SKILL SYNC FAILED - the skills archive could not be downloaded' "$OUT"; echo $?)"
check "an unreachable archive installs nothing and removes nothing" \
  "$([[ "$before" == "$(snapshot "$PROJ/.claude/skills")" ]]; echo $?)"
check "an unreachable archive records the failure in the receipt" \
  "$([[ "$(receipt_status)" == failed ]]; echo $?)"
check "a failed sync still claims what it owned, or it would orphan it" \
  "$(receipt_owns work-order; echo $?)"
check "a failed sync does not stamp itself as done" \
  "$([[ ! -e "$PROJ/.claude/cache/.sync-stamp" ]]; echo $?)"
check "a failed sync leaves no build directory behind" \
  "$([[ "$(count_builds)" -eq 0 ]]; echo $?)"
check "the previous sync date survives a failure, so the warning stays true" \
  "$(grep -q '"synced": "2026-08-21T18:04:11Z"' "$PROJ/.claude/cache/skills-receipt.json"; echo $?)"

printf 'corrupt' > "$TARMODE"
sync_now
rc=$?
check "an archive that is not a tarball exits 0" "$([[ $rc -eq 0 ]]; echo $?)"
check "an archive that is not a tarball says so loudly" \
  "$(grep -q '^!! SKILL SYNC FAILED' "$OUT"; echo $?)"
check "an archive that is not a tarball destroys nothing" \
  "$([[ "$before" == "$(snapshot "$PROJ/.claude/skills")" ]]; echo $?)"

printf 'ok' > "$TARMODE"
mkproject 'use = ["not-in-tree", "container-sandbox"]'
sync_now
rc=$?
check "a registry entry the source tree does not have exits 0" "$([[ $rc -eq 0 ]]; echo $?)"
check "it is named in the failure rather than skipped quietly" \
  "$(grep -q 'not-in-tree' "$OUT"; echo $?)"
check "the skills that do exist are still installed" \
  "$([[ -f "$PROJ/.claude/skills/container-sandbox/SKILL.md" ]]; echo $?)"
check "the receipt does not claim a skill that was never installed" \
  "$(neg receipt_owns not-in-tree)"
check "the receipt records the run as failed" \
  "$([[ "$(receipt_status)" == failed ]]; echo $?)"

# ── 14. the read-only notice ───────────────────────────────────────────────────
# The renderer is the only thing in this ticket that rewrites a file's contents
# instead of moving it whole, and its output has to match six specific lines.
# The template comes out of /repo, so a change to it that nobody meant to make
# fails here rather than reaching 43 projects.
hd "the read-only notice"
mkproject 'use = ["work-order", "stale-notice", "no-heading"]'
sync_now
SM="$PROJ/.claude/skills/work-order/SKILL.md"

cat > "$WORK/notice-expected" <<'EOF'
> **This copy is read-only.**
> Skills are vendored into a project as copies, and this may be one.
> Edit this skill upstream, bump its version, then re-pull it - never edit the copy where it landed.
> Upstream is https://raw.githubusercontent.com/jkkelley/dotfiles/refs/heads/main/claude/skills/work-order/SKILL.md, and `skill-sync.sh` pulls it from there - no dotfiles checkout is needed on this machine.
> `skill-sync.sh` replaces the skill's directory rather than merging into it, so a local edit is destroyed by the next update with no conflict and no warning.
> The registry's content hash cannot catch it either, because a project's copy legitimately differs from upstream.
EOF
check "the rendered notice is the exact six lines, byte for byte" \
  "$([[ "$(grep '^>' "$SM")" == "$(cat "$WORK/notice-expected")" ]]; echo $?)"
check "%%SKILL_NAME%% is substituted, not emitted" "$(neg grep -q 'SKILL_NAME' "$SM")"
check "the template header never reaches the output" \
  "$(neg grep -q 'skill-tool-version' "$SM")"
check "the notice lands after the first heading, not before it" \
  "$([[ "$(grep -n -m1 '^# ' "$SM" | cut -d: -f1)" -lt \
        "$(grep -n -m1 '^> ' "$SM" | cut -d: -f1)" ]]; echo $?)"
check "the notice lands after the frontmatter, not inside it" \
  "$([[ "$(grep -n -m2 '^---$' "$SM" | tail -1 | cut -d: -f1)" -lt \
        "$(grep -n -m1 '^> ' "$SM" | cut -d: -f1)" ]]; echo $?)"
check "the skill's own body survives the insertion" \
  "$(grep -q 'Upstream body for work-order' "$SM"; echo $?)"

SN="$PROJ/.claude/skills/stale-notice/SKILL.md"
check "an inline notice already in the file is replaced, not duplicated" \
  "$([[ "$(grep -c 'This copy is read-only' "$SN")" -eq 1 ]]; echo $?)"
check "the stale wording is gone with it" "$(neg grep -q 'skill-update.sh' "$SN")"
check "the rendered notice names this skill, not the one it was copied from" \
  "$(grep -q 'claude/skills/stale-notice/SKILL.md' "$SN"; echo $?)"

NH="$PROJ/.claude/skills/no-heading/SKILL.md"
check "a SKILL.md with no heading is installed rather than dropped" \
  "$([[ -f $NH ]]; echo $?)"
check "a SKILL.md with no heading is left exactly as it was found" \
  "$(neg grep -q 'read-only' "$NH")"
check "and the reason is reported rather than swallowed" \
  "$(grep -q "no '# ' heading" "$ERR"; echo $?)"

# Rendering twice must produce the same file. A second sync re-renders from the
# same template into a freshly downloaded copy, so this is the real idempotency
# question rather than a synthetic one.
first=$(sha256sum "$SM" | cut -d' ' -f1)
sync_now
check "a second sync renders the notice identically" \
  "$([[ "$first" == "$(sha256sum "$SM" | cut -d' ' -f1)" ]]; echo $?)"

# ── 15. a kill mid-sync, and the sweep that cleans up after it ────────────────
# A hook that overruns its 30-second budget is killed, not asked to stop, so the
# EXIT trap never runs. This is the failure mode the whole build-then-swap shape
# exists for, and the only one the sweep covers.
hd "a kill mid-sync leaves the previous state intact"
mkproject 'use = ["work-order", "container-sandbox"]'
mkreceipt_owning work-order
plant_skill work-order
plant_skill some-local-thing
before=$(snapshot "$PROJ/.claude/skills")
rm -f "$WORK/tar-started" "$PROJ/.claude/cache/.sync-stamp"
printf 'slow' > "$TARMODE"

# `exec` so $! is the sync itself and not a subshell wrapping it: killing the
# wrapper would prove nothing about the process holding the temp directory.
( cd "$PROJ" && PATH="$WORK/stub:$PATH" SKILL_SYNC_LOCK_WAIT=$LOCKWAIT \
    exec bash "$SS" --boot ) > "$OUT" 2> "$ERR" &
killpid=$!
for _ in $(seq 1 100); do [[ -e "$WORK/tar-started" ]] && break; sleep 0.1; done
check "the run reached the download before it was killed" \
  "$([[ -e "$WORK/tar-started" ]]; echo $?)"
kill -9 "$killpid" 2>/dev/null
wait "$killpid" 2>/dev/null
printf 'ok' > "$TARMODE"

check "every skills directory is at its previous version" \
  "$([[ "$before" == "$(snapshot "$PROJ/.claude/skills")" ]]; echo $?)"
check "nothing is half-written: no directory without a SKILL.md" \
  "$([[ -f "$PROJ/.claude/skills/work-order/SKILL.md" ]]; echo $?)"
check "a hard kill does skip the trap, so a build directory is left behind" \
  "$([[ "$(count_builds)" -eq 1 ]]; echo $?)"
check "a hard kill also leaves the lock behind" \
  "$([[ -d "$PROJ/.claude/cache/.sync-lock" ]]; echo $?)"

# The lock the killed run left behind is seconds old, and a lock that young
# still means "a sync is running". Aged past LOCK_MAX_AGE it means "a sync was
# killed", which is what actually happened. Time is injected by setting the
# mtime rather than by waiting five minutes.
touch -d '10 minutes ago' "$PROJ/.claude/cache/.sync-lock"
sync_now   # the leftover build is minutes old, so this run must not sweep it
check "the run after a kill gets going again" \
  "$(grep -q '^skill-sync.sh: ' "$OUT"; echo $?)"
check "a build directory younger than an hour survives the sweep" \
  "$([[ "$(count_builds)" -eq 1 ]]; echo $?)"

for d in "$PROJ/.claude/cache/.sync."*; do
  [[ -d $d ]] && touch -d '2 hours ago' "$d"
done
sync_now
check "a build directory older than an hour is swept" \
  "$([[ "$(count_builds)" -eq 0 ]]; echo $?)"
check "the sweep does not eat the stamp, whose name is one character away" \
  "$([[ -f "$PROJ/.claude/cache/.sync-stamp" ]]; echo $?)"

# ── 16. the lock ───────────────────────────────────────────────────────────────
# Per skill-testing.md, a script that claims to take a lock has that claim
# tested. mkdir and not flock, per Rule 17.
hd "the lock"
mkproject 'use = ["work-order", "container-sandbox"]'
mkdir -p "$PROJ/.claude/cache/.sync-lock"
before=$(snapshot "$PROJ/.claude")
LOCKWAIT=1
sync_now
rc=$?
LOCKWAIT=30
check "a sync that cannot get the lock exits 0" "$([[ $rc -eq 0 ]]; echo $?)"
check "it says so loudly rather than doing the work anyway" \
  "$(grep -q '^!! SKILL SYNC FAILED - another sync has held' "$OUT"; echo $?)"
check "it installs nothing while another sync holds the lock" \
  "$([[ ! -e "$PROJ/.claude/skills/work-order" ]]; echo $?)"
check "and it does not steal the lock it failed to take" \
  "$([[ -d "$PROJ/.claude/cache/.sync-lock" ]]; echo $?)"

touch -d '2 hours ago' "$PROJ/.claude/cache/.sync-lock"
sync_now
check "a lock older than an hour belonged to a killed run and is broken" \
  "$([[ -f "$PROJ/.claude/skills/work-order/SKILL.md" ]]; echo $?)"
check "breaking it is reported rather than done quietly" \
  "$(grep -q 'breaking' "$ERR"; echo $?)"

# Four at once. Distinctness alone would pass on a lost write, so the tree and
# the receipt are both asserted afterwards.
mkproject 'use = ["work-order", "container-sandbox"]'
for i in 1 2 3 4; do
  ( cd "$PROJ" && PATH="$WORK/stub:$PATH" SKILL_SYNC_LOCK_WAIT=30 SKILL_SYNC_NOW="$NOW" \
      bash "$SS" --boot ) > "$WORK/par-$i" 2>&1 &
done
wait
check "four concurrent syncs all exit 0" \
  "$([[ "$(grep -lc 'SKILL SYNC FAILED' "$WORK"/par-* 2>/dev/null | wc -l)" -eq 0 ]]; echo $?)"
check "the tree they raced over is intact" \
  "$([[ -f "$PROJ/.claude/skills/work-order/SKILL.md" &&
        -f "$PROJ/.claude/skills/container-sandbox/SKILL.md" ]]; echo $?)"
check "no half-swapped directory survived the race" \
  "$([[ "$(ls "$PROJ/.claude/skills" | wc -l)" -eq 2 ]]; echo $?)"
check "the receipt is one document, not four interleaved" \
  "$([[ "$(grep -c '^{' "$PROJ/.claude/cache/skills-receipt.json")" -eq 1 ]]; echo $?)"
check "the receipt claims both skills" \
  "$([[ "$(receipt_owns work-order && receipt_owns container-sandbox; echo $?)" -eq 0 ]]; echo $?)"
check "no lock is left behind" \
  "$([[ ! -e "$PROJ/.claude/cache/.sync-lock" ]]; echo $?)"
check "no build directory is left behind" "$([[ "$(count_builds)" -eq 0 ]]; echo $?)"

# ── 17. AC-H4: self-update ─────────────────────────────────────────────────────
# The registry fixture publishes a version older than the file under test
# everywhere else in this suite, so nothing above can have swapped the binary
# being asserted on. Here it publishes a newer one on purpose.
hd "AC-H4: self-update"
MVCP='`mv`, never `cp`'   # assigned first: backticks inside $( ) are a substitution
check "the mv-not-cp comment is present in the source" \
  "$(grep -qF "$MVCP" "$SS"; echo $?)"
check "the comment explains what cp does to a running script" \
  "$(grep -q 'truncates and rewrites the live inode' "$SS"; echo $?)"
check "SKILL_SYNC_CHILD exists in the source" \
  "$([[ "$(grep -c 'SKILL_SYNC_CHILD' "$SS")" -gt 0 ]]; echo $?)"
check "the source contains no cp of itself" "$(neg grep -qE 'cp .*SELF_PATH' "$SS")"

restore_self() { cp /repo/claude/tools/skill-sync.sh "$SS"; rm -f "$SS.bak"; }
self_version() { head -20 "$1" | awk 'match($0, /skill-tool-version:[[:space:]]*[0-9.]+/) {
  s = substr($0, RSTART, RLENGTH); sub(/.*:[[:space:]]*/, "", s); print s; exit }'; }
REAL_VER=$(self_version "$SS")

mkproject 'use = ["work-order"]'
mkregistry_publishing_self 99.0.0
mkstub ok
printf '99.0.0' > "$SELFVER"
sync_now
rc=$?
check "a newer published version exits 0" "$([[ $rc -eq 0 ]]; echo $?)"
check "the skills were synced before the binary was touched" \
  "$([[ -f "$PROJ/.claude/skills/work-order/SKILL.md" ]]; echo $?)"
check "the binary was replaced with the published one" \
  "$([[ "$(self_version "$SS")" == 99.0.0 ]]; echo $?)"
check "the previous binary is kept as .bak" "$([[ -f "$SS.bak" ]]; echo $?)"
check "the .bak is the version that was running" \
  "$([[ "$(self_version "$SS.bak")" == "$REAL_VER" ]]; echo $?)"
check "the update is reported" "$(grep -q 'self-updated to 99.0.0' "$OUT"; echo $?)"
restore_self

printf 'broken' > "$SELFMODE"
sync_now
rc=$?
check "a replacement that does not run exits 0" "$([[ $rc -eq 0 ]]; echo $?)"
check "a replacement that does not run is rolled back" \
  "$([[ "$(self_version "$SS")" == "$REAL_VER" ]]; echo $?)"
check "the rollback is reported loudly" \
  "$(grep -q '^!! SKILL SYNC self-update failed' "$OUT"; echo $?)"
check "the rollback says the skills themselves are fine" \
  "$(grep -q 'The skills themselves are current' "$OUT"; echo $?)"
check "the skills stayed synced through a failed self-update" \
  "$([[ -f "$PROJ/.claude/skills/work-order/SKILL.md" ]]; echo $?)"
restore_self

printf 'fail' > "$SELFMODE"
sync_now
check "a download that fails is rolled back" \
  "$([[ "$(self_version "$SS")" == "$REAL_VER" ]]; echo $?)"
check "an empty download is not mistaken for a new version" \
  "$([[ -s "$SS" ]]; echo $?)"
restore_self

printf 'empty' > "$SELFMODE"
sync_now
check "a truncated download is rolled back rather than installed" \
  "$([[ "$(self_version "$SS")" == "$REAL_VER" ]]; echo $?)"
restore_self

# One deep by construction. The child is the replacement being smoke-tested, and
# a child that self-updated again is an unbounded loop inside a 30-second hook.
printf 'ok' > "$SELFMODE"
rm -f "$PROJ/.claude/cache/.sync-stamp"
( cd "$PROJ" && PATH="$WORK/stub:$PATH" SKILL_SYNC_LOCK_WAIT=$LOCKWAIT \
    SKILL_SYNC_NOW="$NOW" SKILL_SYNC_CHILD=1 bash "$SS" --boot ) > "$OUT" 2> "$ERR"
check "a run marked as the child does not self-update" \
  "$([[ "$(self_version "$SS")" == "$REAL_VER" ]]; echo $?)"
check "the child still does the real work" \
  "$([[ -f "$PROJ/.claude/skills/work-order/SKILL.md" ]]; echo $?)"
restore_self

mkregistry_publishing_self "$REAL_VER"
sync_now
check "a published version equal to this one is not fetched again" \
  "$([[ ! -e "$SS.bak" ]]; echo $?)"
mkregistry_publishing_self 0.0.1
sync_now
check "a published version older than this one is not a downgrade loop" \
  "$([[ ! -e "$SS.bak" && "$(self_version "$SS")" == "$REAL_VER" ]]; echo $?)"
mkregistry
restore_self

# ── setup.sh: the binary, then the hook ────────────────────────────────────────
# setup.sh writes into $HOME and nowhere else, so every case below runs against
# a fake one under the scratch mount. It is interactive, so each run is fed the
# same five answers from a file rather than from a pipe - a `printf | setup.sh`
# dies of SIGPIPE the moment setup.sh stops reading, and pipefail turns that
# into a failure that has nothing to do with the case.
#
# The property under test is an *order*, not an output. C4 of the plan: a
# SessionStart hook fires in every project on this machine, so a hook written
# before the binary exists breaks every session on the machine rather than only
# this one. The two cases that carry the ticket are therefore the idempotency of
# the hook and the refusal to write it at all when the binary did not land.
hd "setup.sh - skill-sync, then the SessionStart hook"

SETUP_HOME="$WORK/home"
SETTINGS="$SETUP_HOME/.claude/settings.json"
BIN="$SETUP_HOME/.local/bin/skill-sync"
ANSWERS="$WORK/answers"
BASH_BIN=$(command -v bash)

# install type 1 (symlink), mode 3 (type names), no agents, one skill, confirm.
printf '1\n3\n\ncontainer-sandbox\ny\n' > "$ANSWERS"

fresh_home() { rm -rf "$SETUP_HOME"; mkdir -p "$SETUP_HOME"; }

setup_run() { # $@ = extra args passed through to setup.sh
  ( cd "$WORK" && HOME="$SETUP_HOME" bash /repo/setup.sh "$@" ) \
    < "$ANSWERS" > "$OUT" 2> "$ERR"
}

# The number of SessionStart entries that call skill-sync. Counting entries the
# script wrote, rather than entries in total, is what makes "exactly one" a
# statement about idempotency instead of a statement about an empty file.
hook_count() {
  jq '[.hooks.SessionStart[]?
       | select(any(.hooks[]?; ((.command? // "") | tostring | contains("skill-sync"))))]
      | length' "$SETTINGS" 2>/dev/null
}
last_hook() { jq -r ".hooks.SessionStart[-1]$1" "$SETTINGS" 2>/dev/null; }

fresh_home
setup_run
rc=$?
check "a first run exits 0" "$([[ $rc -eq 0 ]]; echo $?)"
check "the binary is installed under the fake HOME" "$([[ -f $BIN ]]; echo $?)"
check "the binary is executable" "$([[ -x $BIN ]]; echo $?)"
check "the binary is a copy, not a symlink into the repo" "$([[ ! -L $BIN ]]; echo $?)"
check "the copy is byte-identical to the repo source" \
  "$([[ "$(sha256sum < "$BIN")" == "$(sha256sum < /repo/claude/tools/skill-sync.sh)" ]]; echo $?)"
check "the chosen skill was installed as well" \
  "$([[ -L "$SETUP_HOME/.claude/skills/container-sandbox" ]]; echo $?)"
check "exactly one skill-sync SessionStart hook" "$([[ "$(hook_count)" == 1 ]]; echo $?)"
check "the matcher is the filtered form WO-20260824-0615 confirmed" \
  "$([[ "$(last_hook .matcher)" == 'startup|resume|clear' ]]; echo $?)"
check "compact is nowhere in the written settings" "$(neg grep -q compact "$SETTINGS")"
check "the timeout is 30" "$([[ "$(last_hook '.hooks[0].timeout')" == 30 ]]; echo $?)"
check "the hook calls --boot, not --plan" \
  "$([[ "$(last_hook '.hooks[0].command')" == *' --boot' ]]; echo $?)"
check "the hook names an absolute path, since ~/.local/bin may not be on PATH" \
  "$(jq -e '.hooks.SessionStart[-1].hooks[0].command
            | startswith("\"$HOME/.local/bin/skill-sync\"")' "$SETTINGS" >/dev/null 2>&1; echo $?)"
check "the path in the hook is quoted, because \$HOME can contain a space" \
  "$([[ "$(last_hook '.hooks[0].command')" == '"'* ]]; echo $?)"

# AC-H2. The whole ticket in one assertion.
setup_run
rc=$?
check "a second run exits 0" "$([[ $rc -eq 0 ]]; echo $?)"
check "a second run leaves exactly ONE skill-sync hook, not two" \
  "$([[ "$(hook_count)" == 1 ]]; echo $?)"
check "a second run adds no SessionStart entry of any kind" \
  "$([[ "$(jq '.hooks.SessionStart | length' "$SETTINGS")" == 1 ]]; echo $?)"
setup_run
check "a third run is still exactly one" "$([[ "$(hook_count)" == 1 ]]; echo $?)"

# Rung 3. This is the settings.json every real machine actually has.
fresh_home
mkdir -p "$SETUP_HOME/.claude"
cat > "$SETTINGS" <<'EOF'
{
  "model": "opus",
  "hooks": {
    "PostToolUse": [
      { "matcher": "Write|Edit",
        "hooks": [ { "type": "command", "command": "prettier --write" } ] }
    ],
    "SessionStart": [
      { "matcher": "", "hooks": [ { "type": "command", "command": "gh-axi", "timeout": 10 } ] }
    ]
  }
}
EOF
setup_run
check "an unrelated top-level key survives" \
  "$([[ "$(jq -r .model "$SETTINGS")" == opus ]]; echo $?)"
check "an unrelated PostToolUse hook survives" \
  "$([[ "$(jq '.hooks.PostToolUse | length' "$SETTINGS")" == 1 ]]; echo $?)"
check "an unrelated SessionStart hook survives" \
  "$(jq -e '[.hooks.SessionStart[].hooks[0].command] | index("gh-axi")' "$SETTINGS" >/dev/null 2>&1; echo $?)"
check "the skill-sync hook lands beside it rather than replacing it" \
  "$([[ "$(jq '.hooks.SessionStart | length' "$SETTINGS")" == 2 ]]; echo $?)"
setup_run
check "a second run over a populated file still leaves one skill-sync hook" \
  "$([[ "$(hook_count)" == 1 ]]; echo $?)"
check "a second run over a populated file does not duplicate the others" \
  "$([[ "$(jq '.hooks.SessionStart | length' "$SETTINGS")" == 2 ]]; echo $?)"

# A hook this script wrote under an older matcher. Replacing it is the reason
# the jq drops by command rather than by exact-entry equality: an entry that
# only differs in its matcher would otherwise accumulate beside the new one.
fresh_home
mkdir -p "$SETUP_HOME/.claude"
cat > "$SETTINGS" <<'EOF'
{
  "hooks": {
    "SessionStart": [
      { "matcher": "",
        "hooks": [ { "type": "command", "command": "skill-sync --boot", "timeout": 10 } ] }
    ]
  }
}
EOF
setup_run
check "a stale skill-sync hook is replaced, not duplicated" \
  "$([[ "$(hook_count)" == 1 ]]; echo $?)"
check "the replacement carries the current matcher" \
  "$([[ "$(last_hook .matcher)" == 'startup|resume|clear' ]]; echo $?)"
check "the replacement carries the current timeout" \
  "$([[ "$(last_hook '.hooks[0].timeout')" == 30 ]]; echo $?)"

# A settings.json that is not JSON is the one file that must not be rewritten.
# Every project on the machine reads it.
fresh_home
mkdir -p "$SETUP_HOME/.claude"
printf 'not json at all\n' > "$SETTINGS"
setup_run
rc=$?
check "invalid settings.json makes setup.sh exit non-zero" "$([[ $rc -ne 0 ]]; echo $?)"
check "invalid settings.json is left exactly as it was" \
  "$([[ "$(cat "$SETTINGS")" == 'not json at all' ]]; echo $?)"
check "the refusal names the file rather than failing silently" \
  "$(grep -q 'not valid JSON' "$ERR"; echo $?)"
shopt -s nullglob
LEFTOVERS=("$SETTINGS".setup.*)
shopt -u nullglob
check "no half-written temp file is left beside it" \
  "$([[ ${#LEFTOVERS[@]} -eq 0 ]]; echo $?)"
check "the binary is installed even so, because it comes first" \
  "$([[ -x $BIN ]]; echo $?)"

# Rung 4. The order, asserted by breaking the first step. A file where the bin
# directory should be is the cheapest way to make the install fail for a real
# reason rather than a stubbed one.
fresh_home
mkdir -p "$SETUP_HOME/.local"
printf 'a file, not a directory\n' > "$SETUP_HOME/.local/bin"
setup_run
rc=$?
check "a binary that cannot be installed makes setup.sh exit non-zero" \
  "$([[ $rc -ne 0 ]]; echo $?)"
check "no binary was installed" "$([[ ! -f $BIN ]]; echo $?)"
check "NO hook was written, because the binary did not land" \
  "$([[ ! -e $SETTINGS ]]; echo $?)"
check "the failure says the hook was skipped and why" \
  "$(grep -q 'hook was NOT written' "$OUT"; echo $?)"
check "the failing step is named on stderr" \
  "$(grep -q 'Could not create' "$ERR"; echo $?)"

# jq missing. Built as a PATH rather than by removing the image's jq: this is
# the Git Bash case, and it has to fail as a refusal rather than as a sed.
fresh_home
NOJQ="$WORK/nojq"
rm -rf "$NOJQ"; mkdir -p "$NOJQ"
for b in cp mkdir chmod mv rm ln basename dirname cat; do
  ln -s "$(command -v "$b")" "$NOJQ/$b"
done
( cd "$WORK" && HOME="$SETUP_HOME" PATH="$NOJQ" "$BASH_BIN" /repo/setup.sh ) \
  < "$ANSWERS" > "$OUT" 2> "$ERR"
rc=$?
check "a missing jq still installs the binary" "$([[ -x $BIN ]]; echo $?)"
check "a missing jq writes no hook at all" "$([[ ! -e $SETTINGS ]]; echo $?)"
check "a missing jq is reported rather than worked around with sed" \
  "$(grep -q 'jq not found' "$ERR"; echo $?)"
check "a missing jq makes setup.sh exit non-zero" "$([[ $rc -ne 0 ]]; echo $?)"

# --dest moves the skills. It must not move the hook, which is machine level.
fresh_home
PROJDEST="$WORK/otherproj/.claude"
rm -rf "$WORK/otherproj"
setup_run --dest "$PROJDEST"
check "--dest puts the skills where it was told" \
  "$([[ -L "$PROJDEST/skills/container-sandbox" ]]; echo $?)"
check "--dest leaves the hook in the machine's own settings.json" \
  "$([[ "$(hook_count)" == 1 ]]; echo $?)"
check "--dest writes no settings.json beside the skills" \
  "$([[ ! -e "$PROJDEST/settings.json" ]]; echo $?)"
check "--dest still installs the binary to ~/.local/bin" "$([[ -x $BIN ]]; echo $?)"

# Selecting nothing is a real run, not a no-op: it is how the hook is installed
# on a machine whose agents and skills are already in place. It used to exit
# before anything was written, which would now skip the whole point of the run.
fresh_home
printf '1\n3\n\n\ny\n' > "$WORK/answers-none"
( cd "$WORK" && HOME="$SETUP_HOME" bash /repo/setup.sh ) \
  < "$WORK/answers-none" > "$OUT" 2> "$ERR"
rc=$?
check "selecting no agents and no skills still exits 0" "$([[ $rc -eq 0 ]]; echo $?)"
check "selecting nothing still installs the binary" "$([[ -x $BIN ]]; echo $?)"
check "selecting nothing still installs the hook" "$([[ "$(hook_count)" == 1 ]]; echo $?)"
check "selecting nothing installs no skills" \
  "$([[ ! -e "$SETUP_HOME/.claude/skills/container-sandbox" ]]; echo $?)"
check "the run says why it installed nothing else" \
  "$(grep -q 'skill-sync and its hook only' "$OUT"; echo $?)"

# Answering N at the confirmation prompt writes nothing, including the hook.
# That prompt is the only gate in front of a file every project on the machine
# reads, so it has to hold for the new step as well as the old ones.
fresh_home
printf '1\n3\n\ncontainer-sandbox\nn\n' > "$WORK/answers-abort"
( cd "$WORK" && HOME="$SETUP_HOME" bash /repo/setup.sh ) \
  < "$WORK/answers-abort" > "$OUT" 2> "$ERR"
rc=$?
check "declining the confirmation exits 0" "$([[ $rc -eq 0 ]]; echo $?)"
check "declining the confirmation installs no binary" "$([[ ! -e $BIN ]]; echo $?)"
check "declining the confirmation writes no hook" "$([[ ! -e $SETTINGS ]]; echo $?)"
check "the summary named the hook before it was declined" \
  "$(grep -q 'SessionStart in' "$OUT"; echo $?)"

# The containerisable half of AC-H1. A real session cannot be produced in here,
# so what is proved is that the binary setup.sh installed is silent in a project
# with no manifest. That the hook then fires at all is rung 5, on the host.
fresh_home
setup_run
NOMAN="$WORK/no-manifest"
rm -rf "$NOMAN"; mkdir -p "$NOMAN"
( cd "$NOMAN" && bash "$BIN" --boot ) > "$OUT" 2> "$ERR"
rc=$?
check "the installed binary exits 0 where there is no manifest" "$([[ $rc -eq 0 ]]; echo $?)"
check "it prints nothing on stdout there" "$([[ ! -s $OUT ]]; echo $?)"
check "it prints nothing on stderr there" "$([[ ! -s $ERR ]]; echo $?)"
check "it creates nothing there either" \
  "$([[ ! -e "$NOMAN/.claude" ]]; echo $?)"

# This image now carries jq for setup.sh's sake. That is only safe while
# skill-sync.sh does not reach for it, so the guard is an assertion rather than
# a comment. The one mention in the source is the comment saying why it is not
# a dependency.
check "no runnable line of skill-sync.sh names jq" \
  "$([[ "$(grep -vE '^[[:space:]]*#' /repo/claude/tools/skill-sync.sh | grep -cE '\bjq\b')" -eq 0 ]]; echo $?)"

# ── summary ────────────────────────────────────────────────────────────────────
printf '\n=========================================\n'
printf '  PASS %d   FAIL %d\n' "$PASS" "$FAIL"
printf '=========================================\n'
[[ $FAIL -eq 0 ]]
