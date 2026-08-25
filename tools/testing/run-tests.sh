#!/usr/bin/env bash
#
# run-tests.sh - the only entry point for the repo-local tools in tools/.
#
# Everything runs inside Podman, per root CLAUDE.md Rule 14, which has no size
# threshold: a single --help run whose purpose is to check that something works
# goes in a container too.
#
#   --network=none      no check reaches the network
#   /repo mounted ro    nothing writes next to itself, which also proves
#                       workflow-version.sh never writes back into its own source
#   /work separate      every output lands in a scratch mount
#   --userns=keep-id    files in that mount are owned by you, not by root
#
# The failure cases are the point. A verify that never rejects anything is not a
# gate, and rejecting is the whole job.
#
# No -e, deliberately. Over half the checks here run a command that is expected
# to fail, and under -e the first of them ends the run and reports the assertion
# passing as an error. Every step that must not continue after a failure guards
# itself explicitly instead.
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TOOLS_DIR=$(cd "$HERE/.." && pwd)
REPO_ROOT=$(cd "$TOOLS_DIR/.." && pwd)
IMAGE="${TOOLS_TEST_IMAGE:-localhost/dotfiles-tools-test:1}"

# Re-exec inside the container unless we are already in it.
if [[ ${IN_TOOLS_CONTAINER:-0} != 1 ]]; then
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
  SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tools-test.XXXXXX")
  trap 'rm -rf -- "$SCRATCH"' EXIT INT TERM
  exec podman run --rm --userns=keep-id --network=none \
    -v "$REPO_ROOT:/repo:ro,Z" -v "$SCRATCH:/work:Z" -w /work \
    -e IN_TOOLS_CONTAINER=1 --entrypoint="" \
    "$IMAGE" bash /repo/tools/testing/run-tests.sh
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
cp /repo/tools/workflow-version.sh "$WORK/bin/"
WV="$WORK/bin/workflow-version.sh"

DOCS="$WORK/workflows"
export WORKFLOW_VERSION_DIR="$DOCS"

mkfixture() {
  rm -rf "$DOCS"
  mkdir -p "$DOCS/nested"
  printf '# Alpha procedure\n\nBody.\n' > "$DOCS/alpha.md"
  printf '# Beta procedure\n\n<!-- workflow-version: 2.3.4 -->\n\nBody.\n' > "$DOCS/beta.md"
  # Not a markdown file, and a nested one. Neither is a procedure document.
  printf 'notes\n' > "$DOCS/notes.txt"
  printf '# Nested\n' > "$DOCS/nested/deep.md"
}

# ── 1. entry points ────────────────────────────────────────────────────────────
hd "entry points"
expect_rc "workflow-version.sh --help" 0 bash "$WV" --help
expect_rc "rejects an unknown subcommand" 1 bash "$WV" frobnicate
expect_rc "fails when the workflows directory is absent" 1 \
  env WORKFLOW_VERSION_DIR="$WORK/nope" bash "$WV" list

# ── 2. discovery ───────────────────────────────────────────────────────────────
hd "discovery"
mkfixture
bash "$WV" init >/dev/null 2>&1
check "a .txt file is not a procedure document" \
  "$(neg grep -q 'workflow-version' "$DOCS/notes.txt")"
check "a nested .md is not a procedure document" \
  "$(neg grep -q 'workflow-version' "$DOCS/nested/deep.md")"

# ── 3. init ────────────────────────────────────────────────────────────────────
hd "init"
check "init stamps an unversioned document at 1.0.0" \
  "$(grep -q '<!-- workflow-version: 1.0.0 -->' "$DOCS/alpha.md"; echo $?)"
check "init leaves an already-versioned document alone" \
  "$(grep -q '<!-- workflow-version: 2.3.4 -->' "$DOCS/beta.md"; echo $?)"
check "the marker is placed under the title, not above it" \
  "$([[ "$(head -1 "$DOCS/alpha.md")" == '# Alpha procedure' ]]; echo $?)"

cp "$DOCS/alpha.md" "$WORK/alpha1.md"
bash "$WV" init >/dev/null 2>&1
check "init is idempotent and the file is byte-identical" \
  "$([[ "$(cat "$WORK/alpha1.md")" == "$(cat "$DOCS/alpha.md")" ]]; echo $?)"
check "init did not add a second marker" \
  "$([[ "$(grep -c 'workflow-version:' "$DOCS/alpha.md")" -eq 1 ]]; echo $?)"

# ── 4. verify: the negative cases are the reason it exists ─────────────────────
hd "verify"
expect_rc "verify passes on a freshly initialised tree" 0 bash "$WV" verify

mkfixture
expect_rc "verify FAILS when a document carries no version" 1 bash "$WV" verify
bash "$WV" verify > "$WORK/verify-unversioned.out" 2>&1
check "verify names the unversioned document" \
  "$(grep -q '^unversioned   alpha' "$WORK/verify-unversioned.out"; echo $?)"
check "verify does not name the versioned one" \
  "$(neg grep -q '^unversioned   beta' "$WORK/verify-unversioned.out")"

bash "$WV" init >/dev/null 2>&1
printf '# Gamma\n\n<!-- workflow-version: 1.0 -->\n' > "$DOCS/gamma.md"
expect_rc "verify FAILS on a version that is not semver" 1 bash "$WV" verify
bash "$WV" verify > "$WORK/verify-malformed.out" 2>&1
check "verify names the malformed version and prints it" \
  "$(grep -q '^malformed     gamma  (1.0)' "$WORK/verify-malformed.out"; echo $?)"
# init skips a file that already has a marker, so pointing a reader with a
# malformed one at init sends them to a command that does nothing and succeeds.
check "a malformed version is NOT told to run init" \
  "$(neg grep -q "run '.*' init" "$WORK/verify-malformed.out")"
check "a malformed version is told to correct the marker" \
  "$(grep -q 'correct the marker by hand' "$WORK/verify-malformed.out"; echo $?)"
run_init_out=$(bash "$WV" init 2>&1)
check "init leaves a malformed marker alone rather than stamping over it" \
  "$(grep -q 'workflow-version: 1.0 ' "$DOCS/gamma.md"; echo $?)"
rm -f "$DOCS/gamma.md"
expect_rc "verify passes once it is gone" 0 bash "$WV" verify

# A marker in the body is prose, not metadata - the same rule read_version has
# followed since the beginning, and for the same reason.
printf '\nThe marker looks like <!-- workflow-version: 9.9.9 --> in a document.\n' >> "$DOCS/beta.md"
check "a marker below the head of the file is ignored" \
  "$([[ "$(bash "$WV" list | awk '$1=="beta"{print $2}')" == "2.3.4" ]]; echo $?)"

# ── 5. bump arithmetic ─────────────────────────────────────────────────────────
hd "bump"
mkfixture
bash "$WV" init >/dev/null 2>&1

bash "$WV" bump alpha --minor >/dev/null 2>&1
check "--minor took 1.0.0 to 1.1.0" "$(grep -q 'workflow-version: 1.1.0' "$DOCS/alpha.md"; echo $?)"
bash "$WV" bump alpha --patch >/dev/null 2>&1
check "--patch took 1.1.0 to 1.1.1" "$(grep -q 'workflow-version: 1.1.1' "$DOCS/alpha.md"; echo $?)"
bash "$WV" bump alpha --major >/dev/null 2>&1
check "--major took 1.1.1 to 2.0.0 and zeroed the rest" \
  "$(grep -q 'workflow-version: 2.0.0' "$DOCS/alpha.md"; echo $?)"
check "bump did not add a second marker" \
  "$([[ "$(grep -c 'workflow-version:' "$DOCS/alpha.md")" -eq 1 ]]; echo $?)"
check "bump left the title untouched" \
  "$([[ "$(head -1 "$DOCS/alpha.md")" == '# Alpha procedure' ]]; echo $?)"
expect_rc "verify passes after every bump" 0 bash "$WV" verify

check "the name may be given with or without .md" \
  "$(bash "$WV" bump alpha.md --patch >/dev/null 2>&1; echo $?)"

expect_rc "bump rejects an unknown document" 1 bash "$WV" bump nope  --patch
expect_rc "bump rejects an unknown level"    1 bash "$WV" bump alpha --sideways
expect_rc "bump rejects a missing level"     1 bash "$WV" bump alpha
check "a rejected bump left the version untouched" \
  "$(grep -q 'workflow-version: 2.0.1' "$DOCS/alpha.md"; echo $?)"

# ── 6. list ────────────────────────────────────────────────────────────────────
hd "list"
check "list prints a name and a version per document" \
  "$([[ "$(bash "$WV" list | wc -l)" -eq 2 ]]; echo $?)"
check "list reports the version bump wrote" \
  "$([[ "$(bash "$WV" list | awk '$1=="alpha"{print $2}')" == "2.0.1" ]]; echo $?)"

# ── 7. the real workflows/ tree ────────────────────────────────────────────────
# The fixtures prove the mechanism. This proves the repository is actually in the
# state the mechanism demands, which is the assertion a PR gate would run.
hd "the repository's own workflows/"
expect_rc "every document in the real workflows/ carries a version" 0 \
  env WORKFLOW_VERSION_DIR=/repo/workflows bash "$WV" verify
check "close-out-procedure.md is one of them" \
  "$(WORKFLOW_VERSION_DIR=/repo/workflows bash "$WV" list | grep -q '^close-out-procedure'; echo $?)"

# ── summary ────────────────────────────────────────────────────────────────────
printf '\n=========================================\n'
printf '  PASS %d   FAIL %d\n' "$PASS" "$FAIL"
printf '=========================================\n'
[[ $FAIL -eq 0 ]]
