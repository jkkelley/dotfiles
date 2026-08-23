#!/usr/bin/env bash
# Drives checkpoint.sh. Run in a container, per root CLAUDE.md Rule 14:
#
#   just test
#
# The claim under test is the one the old skill broke: a second checkpoint must
# not disturb the first. Most of what follows exists to prove that from several
# directions - byte-identical history after a write, ordering, and the refusal
# to rewrite older checkpoints to satisfy a newer schema.
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SRC=$(cd "$HERE/.." && pwd)
CP="$SRC/scripts/checkpoint.sh"
WORK=${WORK:-/work}
PASS=0
FAIL=0

ok()  { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; printf '        %s\n' "${2:-}"; FAIL=$((FAIL + 1)); }

expect_exit() {
  local want=$1 label=$2; shift 2
  local out rc
  out=$("$@" 2>&1); rc=$?
  if [[ $rc -eq $want ]]; then ok "$label"; else bad "$label" "wanted $want, got $rc: $out"; fi
}

newproj() { local p="$WORK/$1"; rm -rf "$p"; mkdir -p "$p"; printf '%s' "$p"; }

body() {
  cat > "$1" <<EOF
### Current state

#### Infrastructure
host: ${2:-alpha}

#### Toolchain
podman

#### Active Tasks
${3:-do the thing}

#### Blockers
none

### New this checkpoint

#### Decisions
chose ${2:-alpha}

### Hydration prompt
focus: ${3:-do the thing}
EOF
}

printf '\ncontext-compaction / checkpoint.sh\n\n'

# --- init ------------------------------------------------------------------
P=$(newproj init1)
expect_exit 0 "init writes CONTEXT_STATE.md" bash "$CP" init --project "$P"
[[ -f "$P/CONTEXT_STATE.md" ]] && ok "file exists" || bad "file exists" "missing"
grep -q 'Read the top checkpoint and stop' "$P/CONTEXT_STATE.md" \
  && ok "preamble states the read rule" || bad "preamble states the read rule" "missing"
grep -q '^## Checkpoint ' "$P/CONTEXT_STATE.md" \
  && bad "init writes no checkpoint" "found one" || ok "init writes no checkpoint"

before=$(sha256sum < "$P/CONTEXT_STATE.md")
bash "$CP" init --project "$P" >/dev/null 2>&1
[[ $before == "$(sha256sum < "$P/CONTEXT_STATE.md")" ]] \
  && ok "init is byte-identical on re-run" || bad "init is byte-identical on re-run" "changed"

expect_exit 2 "init without --project is usage" bash "$CP" init
expect_exit 4 "init on a missing directory is io" bash "$CP" init --project "$WORK/nope"

# --- check -----------------------------------------------------------------
B="$WORK/body.md"; body "$B"
expect_exit 0 "check accepts a complete body" bash "$CP" check --body-file "$B"

printf '### Current state\n#### Infrastructure\nx\n' > "$WORK/partial.md"
expect_exit 3 "check rejects a body missing sections" bash "$CP" check --body-file "$WORK/partial.md"
# Captured, not piped. Under pipefail a correctly-failing check poisons the
# pipeline status even when grep matches, reporting working code as broken.
cout=$(bash "$CP" check --body-file "$WORK/partial.md" 2>&1)
printf '%s' "$cout" | grep -q 'Blockers' \
  && ok "check names the missing section" || bad "check names the missing section" "not in: $cout"

: > "$WORK/empty.md"
expect_exit 3 "check rejects an empty body" bash "$CP" check --body-file "$WORK/empty.md"
expect_exit 4 "check on a missing file is io" bash "$CP" check --body-file "$WORK/absent.md"

cp "$B" "$WORK/withhead.md"
printf '## Checkpoint 2020-01-01 00:00 UTC\n' >> "$WORK/withhead.md"
expect_exit 3 "check rejects a body carrying its own heading" bash "$CP" check --body-file "$WORK/withhead.md"

# --- new: the regression this whole change exists for -----------------------
P=$(newproj new1)
bash "$CP" init --project "$P" >/dev/null 2>&1
mkdir -p "$WORK/noinit"
expect_exit 6 "new before init is not-found" bash "$CP" new --project "$WORK/noinit" --body-file "$B"

export SOURCE_DATE_EPOCH=1787443200   # 2026-08-23 00:00 UTC
body "$B" alpha "first task"
s1=$(bash "$CP" new --project "$P" --body-file "$B" 2>/dev/null)
[[ $s1 == "2026-08-23 00:00 UTC" ]] && ok "new stamps the pinned clock" || bad "new stamps the pinned clock" "got '$s1'"

first_block=$(bash "$CP" read --project "$P" --top 1)
first_hash=$(printf '%s' "$first_block" | sha256sum)

export SOURCE_DATE_EPOCH=1787529600   # 2026-08-24 00:00 UTC
body "$B" beta "second task"
s2=$(bash "$CP" new --project "$P" --body-file "$B" 2>/dev/null)
[[ $s2 == "2026-08-24 00:00 UTC" ]] && ok "second checkpoint stamps its own time" || bad "second checkpoint stamps its own time" "got '$s2'"

n=$(grep -c '^## Checkpoint ' "$P/CONTEXT_STATE.md")
[[ $n -eq 2 ]] && ok "two checkpoints coexist" || bad "two checkpoints coexist" "found $n"

top=$(bash "$CP" read --project "$P" --top 1)
printf '%s' "$top" | grep -q 'beta' && ok "newest checkpoint is on top" || bad "newest checkpoint is on top" "top is not the newest"

# THE regression: checkpoint 1 must survive byte-identical
second_block=$(bash "$CP" read --project "$P" --top 2 | awk '/^## Checkpoint 2026-08-23/{f=1} f')
[[ $(printf '%s' "$second_block" | sha256sum) == "$first_hash" ]] \
  && ok "the first checkpoint survives a second write, byte-identical" \
  || bad "the first checkpoint survives a second write, byte-identical" "history was altered"

grep -q 'Read the top checkpoint and stop' "$P/CONTEXT_STATE.md" \
  && ok "preamble survives writes" || bad "preamble survives writes" "preamble lost"

expect_exit 3 "a same-minute checkpoint is refused" bash "$CP" new --project "$P" --body-file "$B"
unset SOURCE_DATE_EPOCH

# --- read ------------------------------------------------------------------
P=$(newproj read1)
bash "$CP" init --project "$P" >/dev/null 2>&1
for i in 1 2 3 4 5; do
  export SOURCE_DATE_EPOCH=$(( 1787443200 + i * 86400 ))
  body "$B" "host$i" "task$i"
  bash "$CP" new --project "$P" --body-file "$B" >/dev/null 2>&1
done
unset SOURCE_DATE_EPOCH

[[ $(bash "$CP" read --project "$P" --top 1 | grep -c '^## Checkpoint ') -eq 1 ]] \
  && ok "read --top 1 returns one" || bad "read --top 1 returns one" "wrong count"
[[ $(bash "$CP" read --project "$P" --top 3 | grep -c '^## Checkpoint ') -eq 3 ]] \
  && ok "read --top 3 returns three" || bad "read --top 3 returns three" "wrong count"
[[ $(bash "$CP" read --project "$P" | grep -c '^## Checkpoint ') -eq 5 ]] \
  && ok "read defaults to 10 and returns all five" || bad "read defaults to 10 and returns all five" "wrong count"
bash "$CP" read --project "$P" --top 1 | grep -q 'Read the top checkpoint' \
  && bad "read omits the preamble" "preamble leaked" || ok "read omits the preamble"
bash "$CP" read --project "$P" --top 1 | grep -q 'host5' \
  && ok "read returns newest first" || bad "read returns newest first" "wrong order"
expect_exit 2 "a non-numeric --top is usage" bash "$CP" read --project "$P" --top abc

# --- verify ----------------------------------------------------------------
expect_exit 0 "verify passes on a healthy file" bash "$CP" verify --project "$P"
v=$(bash "$CP" verify --project "$P" --json 2>/dev/null)
printf '%s' "$v" | grep -q '"checkpoints":5' && ok "verify --json counts checkpoints" || bad "verify --json counts checkpoints" "got '$v'"
[[ $(printf '%s' "$v" | wc -l) -eq 0 ]] && ok "verify --json is a single line" || bad "verify --json is a single line" "multi-line"

# out of order
P=$(newproj verify2)
bash "$CP" init --project "$P" >/dev/null 2>&1
{
  printf '\n## Checkpoint 2026-01-01 00:00 UTC\n\n'
  cat "$B"
  printf '\n## Checkpoint 2026-12-31 00:00 UTC\n\n'
  cat "$B"
} >> "$P/CONTEXT_STATE.md"
expect_exit 3 "verify rejects checkpoints out of order" bash "$CP" verify --project "$P"

# duplicates
P=$(newproj verify3)
bash "$CP" init --project "$P" >/dev/null 2>&1
for _ in 1 2; do
  printf '\n## Checkpoint 2026-05-05 00:00 UTC\n\n' >> "$P/CONTEXT_STATE.md"
  cat "$B" >> "$P/CONTEXT_STATE.md"
done
expect_exit 3 "verify rejects duplicate timestamps" bash "$CP" verify --project "$P"

# an incomplete TOP checkpoint fails
P=$(newproj verify4)
bash "$CP" init --project "$P" >/dev/null 2>&1
printf '\n## Checkpoint 2026-05-05 00:00 UTC\n\n### Current state\n#### Infrastructure\nx\n' >> "$P/CONTEXT_STATE.md"
expect_exit 3 "verify rejects an incomplete top checkpoint" bash "$CP" verify --project "$P"

# an incomplete OLDER checkpoint is tolerated - rewriting it would be the very
# in-place edit this change exists to prevent
P=$(newproj verify5)
bash "$CP" init --project "$P" >/dev/null 2>&1
printf '\n## Checkpoint 2026-01-01 00:00 UTC\n\n### Current state\n#### Infrastructure\nlegacy\n' >> "$P/CONTEXT_STATE.md"
export SOURCE_DATE_EPOCH=1787443200
body "$B"
bash "$CP" new --project "$P" --body-file "$B" >/dev/null 2>&1
unset SOURCE_DATE_EPOCH
expect_exit 0 "verify tolerates an incomplete older checkpoint" bash "$CP" verify --project "$P"

expect_exit 6 "verify with no file is not-found" bash "$CP" verify --project "$WORK/nope3"

# --- locking ---------------------------------------------------------------
P=$(newproj lock1)
bash "$CP" init --project "$P" >/dev/null 2>&1
for i in 1 2 3 4 5; do
  ( export SOURCE_DATE_EPOCH=$(( 1787443200 + i * 3600 )); body "$WORK/b$i.md" "h$i"; \
    bash "$CP" new --project "$P" --body-file "$WORK/b$i.md" >/dev/null 2>&1 ) &
done
wait
n=$(grep -c '^## Checkpoint ' "$P/CONTEXT_STATE.md")
[[ $n -eq 5 ]] && ok "five concurrent writes produce five checkpoints" || bad "five concurrent writes produce five checkpoints" "got $n"
[[ $(find "$P" -name '*.lockdir' -type d | wc -l) -eq 0 ]] \
  && ok "no lock directory is left behind" || bad "no lock directory is left behind" "leftover"

# --- injection -------------------------------------------------------------
P=$(newproj inject1)
bash "$CP" init --project "$P" >/dev/null 2>&1
body "$WORK/inj.md" '$(touch /work/pwned)' 'a `whoami` b'
bash "$CP" new --project "$P" --body-file "$WORK/inj.md" >/dev/null 2>&1
[[ ! -e /work/pwned ]] && ok "body content is not evaluated" || bad "body content is not evaluated" "substitution ran"
grep -qF '$(touch /work/pwned)' "$P/CONTEXT_STATE.md" \
  && ok "body content is written literally" || bad "body content is written literally" "altered"

# --- misc ------------------------------------------------------------------
expect_exit 2 "no subcommand is usage" bash "$CP"
expect_exit 2 "an unknown subcommand is usage" bash "$CP" frobnicate

printf '\n  %d passed, %d failed\n\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
