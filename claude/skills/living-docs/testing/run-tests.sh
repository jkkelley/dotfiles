#!/usr/bin/env bash
# Drives docs.sh. Run in a container, per root CLAUDE.md Rule 14:
#
#   just test
#
# or directly:
#
#   podman run --rm --userns=keep-id --network=none --entrypoint="" \
#     -v "$PWD:/skill:ro,Z" -v "$(mktemp -d):/work:Z" -w /work \
#     docker.io/bitnami/git@sha256:1baa6ddbde79fa7ba2fdf441cea47c4f04fae067504d9265e416358db0879ab2 \
#     bash /skill/testing/run-tests.sh
#
# The source mount is read-only, so a passing run also proves docs.sh never
# writes back into its own source. --network=none proves it reaches nothing.
# SOURCE_DATE_EPOCH pins the clock so determinism is provable with cmp rather
# than asserted around a moving value.
#
# The negative cases are the point. verify's whole job is to reject, and a gate
# that never rejects anything is not a gate.
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SRC=$(cd "$HERE/.." && pwd)
DOCS="$SRC/scripts/docs.sh"
WORK=${WORK:-/work}
PASS=0
FAIL=0

# 2026-08-23T00:00:00Z
export SOURCE_DATE_EPOCH=1787443200
FIXED_DATE=2026-08-23

ok()   { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
bad()  { printf '  FAIL  %s\n' "$1"; printf '        %s\n' "${2:-}"; FAIL=$((FAIL + 1)); }

# expect_exit <want> <label> <command...>
expect_exit() {
  local want=$1 label=$2; shift 2
  local out rc
  out=$("$@" 2>&1); rc=$?
  if [[ $rc -eq $want ]]; then ok "$label"; else bad "$label" "wanted exit $want, got $rc: $out"; fi
}

newproj() {
  local p="$WORK/$1"
  rm -rf "$p"; mkdir -p "$p"
  printf '%s' "$p"
}

printf '\nliving-docs\n\n'

# --- init ------------------------------------------------------------------
P=$(newproj init1)
expect_exit 0 "init writes docs/README.md" bash "$DOCS" init --project "$P"
[[ -f "$P/docs/README.md" ]] && ok "README.md exists" || bad "README.md exists" "missing"
grep -q 'Diataxis mode:' "$P/docs/README.md" && ok "README declares a mode" || bad "README declares a mode" "no mode line"
grep -q "Last reviewed: $FIXED_DATE" "$P/docs/README.md" && ok "README carries the pinned date" || bad "README carries the pinned date" "date not pinned"

# init creates no empty directories
n=$(find "$P/docs" -mindepth 1 -type d | wc -l)
[[ $n -eq 0 ]] && ok "init creates no empty directories" || bad "init creates no empty directories" "found $n"

# idempotent, and byte-identical on a second run
# sha256sum rather than cmp: the test image ships neither cmp nor diff, and a
# suite that assumes a utility it never checked for is the bug it exists to catch.
before=$(sha256sum < "$P/docs/README.md")
bash "$DOCS" init --project "$P" >/dev/null 2>&1
after=$(sha256sum < "$P/docs/README.md")
[[ $before == "$after" ]] && ok "init is byte-identical on re-run" || bad "init is byte-identical on re-run" "file changed"

expect_exit 2 "init without --project is usage" bash "$DOCS" init
expect_exit 4 "init on a missing directory is io" bash "$DOCS" init --project "$WORK/nope"

# --- adr -------------------------------------------------------------------
P=$(newproj adr1)
bash "$DOCS" init --project "$P" >/dev/null 2>&1

id=$(bash "$DOCS" adr --project "$P" --title "Use mkdir locking" \
      --context "flock is absent on Windows" \
      --decision "Lock with mkdir" \
      --consequences "Works on both platforms" 2>/dev/null)
[[ $id == ADR-0001 ]] && ok "first adr is ADR-0001" || bad "first adr is ADR-0001" "got '$id'"
[[ -f "$P/docs/decisions/ADR-0001-use-mkdir-locking.md" ]] \
  && ok "adr filename is id plus slug" || bad "adr filename is id plus slug" "$(ls "$P/docs/decisions" 2>&1)"
grep -q 'Status: \*\*proposed\*\*' "$P/docs/decisions/ADR-0001-use-mkdir-locking.md" \
  && ok "adr defaults to proposed" || bad "adr defaults to proposed" "wrong default"

id2=$(bash "$DOCS" adr --project "$P" --title "Second one" \
      --context c --decision d --consequences x 2>/dev/null)
[[ $id2 == ADR-0002 ]] && ok "adr numbering increments" || bad "adr numbering increments" "got '$id2'"

# stdout is the id and nothing else
line_count=$(bash "$DOCS" adr --project "$P" --title "Third" \
             --context c --decision d --consequences x 2>/dev/null | wc -l)
[[ $line_count -eq 1 ]] && ok "adr stdout is one line of data" || bad "adr stdout is one line of data" "$line_count lines"

# supersede
id4=$(bash "$DOCS" adr --project "$P" --title "Replaces the first" \
      --context c --decision d --consequences x \
      --status superseded --supersedes ADR-0001 2>/dev/null)
grep -q 'Supersedes: ADR-0001' "$P/docs/decisions/$id4-replaces-the-first.md" \
  && ok "adr records what it supersedes" || bad "adr records what it supersedes" "no supersedes line"

expect_exit 6 "superseding a missing adr is not-found" \
  bash "$DOCS" adr --project "$P" --title t --context c --decision d \
       --consequences x --supersedes ADR-9999
expect_exit 3 "a bad status is validation" \
  bash "$DOCS" adr --project "$P" --title t --context c --decision d \
       --consequences x --status maybe
expect_exit 2 "a missing required field is usage" \
  bash "$DOCS" adr --project "$P" --title t --context c --decision d
expect_exit 2 "an empty required field is usage" \
  bash "$DOCS" adr --project "$P" --title "" --context c --decision d --consequences x
expect_exit 2 "an unknown flag is usage" \
  bash "$DOCS" adr --project "$P" --title t --context c --decision d --consequences x --nope 1

# field values are written literally, never evaluated
bash "$DOCS" adr --project "$P" --title "Injection" \
  --context '$(touch /work/pwned)' --decision 'a `whoami` b' --consequences 'c' >/dev/null 2>&1
[[ ! -e /work/pwned ]] && ok "field values are not evaluated" || bad "field values are not evaluated" "command substitution ran"
grep -qF '$(touch /work/pwned)' "$P/docs/decisions/ADR-0005-injection.md" \
  && ok "field values are written literally" || bad "field values are written literally" "content altered"

# --- sop -------------------------------------------------------------------
P=$(newproj sop1)
bash "$DOCS" init --project "$P" >/dev/null 2>&1
sid=$(bash "$DOCS" sop --project "$P" --title "Restore a snapshot" \
      --purpose p --when w --steps s 2>/dev/null)
[[ $sid == SOP-0001 ]] && ok "first sop is SOP-0001" || bad "first sop is SOP-0001" "got '$sid'"
grep -q 'Diataxis mode: \*\*how-to\*\*' "$P/docs/sops/SOP-0001-restore-a-snapshot.md" \
  && ok "sop declares how-to" || bad "sop declares how-to" "wrong mode"
grep -q '## Verification' "$P/docs/sops/SOP-0001-restore-a-snapshot.md" \
  && ok "sop carries a Verification section" || bad "sop carries a Verification section" "missing"

# adr and sop number independently
aid=$(bash "$DOCS" adr --project "$P" --title a --context c --decision d --consequences x 2>/dev/null)
[[ $aid == ADR-0001 ]] && ok "adr and sop number independently" || bad "adr and sop number independently" "got '$aid'"

# --- verify ----------------------------------------------------------------
P=$(newproj verify1)
expect_exit 6 "verify before init is not-found" bash "$DOCS" verify --project "$P"

bash "$DOCS" init --project "$P" >/dev/null 2>&1
bash "$DOCS" adr --project "$P" --title a --context c --decision d --consequences x >/dev/null 2>&1
expect_exit 0 "verify passes on generated documents" bash "$DOCS" verify --project "$P"

printf '# no mode here\n' > "$P/docs/reference.md"
expect_exit 3 "verify rejects a document with no mode" bash "$DOCS" verify --project "$P"
# Captured, not piped. Under pipefail a failing verify poisons the pipeline
# status even when grep matches, which reports a passing script as broken.
vout=$(bash "$DOCS" verify --project "$P" 2>&1)
printf '%s' "$vout" | grep -q 'reference.md' \
  && ok "verify names the offending file" || bad "verify names the offending file" "no filename in: $vout"

printf 'Diataxis mode: **reference**.\n' > "$P/docs/reference.md"
expect_exit 3 "verify rejects a document with no review date" bash "$DOCS" verify --project "$P"

printf 'Diataxis mode: **reference**.\nLast reviewed: 2026-08-23.\n' > "$P/docs/reference.md"
expect_exit 0 "verify accepts once both lines are present" bash "$DOCS" verify --project "$P"

# --json is one object on stdout
j=$(bash "$DOCS" verify --project "$P" --json 2>/dev/null)
printf '%s' "$j" | grep -q '"ok":true' && ok "verify --json reports ok" || bad "verify --json reports ok" "got '$j'"
[[ $(printf '%s' "$j" | wc -l) -eq 0 ]] && ok "verify --json is a single line" || bad "verify --json is a single line" "multi-line"

# --- locking ---------------------------------------------------------------
# The claim is that writes serialise. Two concurrent adrs must not collide on an id.
P=$(newproj lock1)
bash "$DOCS" init --project "$P" >/dev/null 2>&1
for i in 1 2 3 4 5; do
  bash "$DOCS" adr --project "$P" --title "concurrent $i" \
    --context c --decision d --consequences x >/dev/null 2>&1 &
done
wait
written=$(find "$P/docs/decisions" -name 'ADR-*.md' | wc -l)
uniq_ids=$(find "$P/docs/decisions" -name 'ADR-*.md' -exec basename {} \; | cut -d- -f1,2 | sort -u | wc -l)
[[ $written -eq 5 && $uniq_ids -eq 5 ]] \
  && ok "five concurrent writes produce five distinct ids" \
  || bad "five concurrent writes produce five distinct ids" "wrote $written, $uniq_ids unique"

# no lock directory survives a clean run
leftover=$(find "$P/docs" -name '*.lockdir' -type d | wc -l)
[[ $leftover -eq 0 ]] && ok "no lock directory is left behind" || bad "no lock directory is left behind" "$leftover left"

# --- misc ------------------------------------------------------------------
expect_exit 0 "modes prints the four modes" bash "$DOCS" modes
[[ $(bash "$DOCS" modes 2>/dev/null | wc -l) -eq 4 ]] && ok "modes prints exactly four" || bad "modes prints exactly four" "wrong count"
expect_exit 2 "no subcommand is usage" bash "$DOCS"
expect_exit 2 "an unknown subcommand is usage" bash "$DOCS" frobnicate

# the read-only mount must be untouched
if [[ -n $(find "$SRC" -newer "$SRC/SKILL.md" -not -path '*/.git/*' -type f 2>/dev/null | head -1) ]]; then
  printf '  note  source appears modified - check the mount is read-only\n'
fi

printf '\n  %d passed, %d failed\n\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
