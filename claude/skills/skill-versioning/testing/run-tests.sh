#!/usr/bin/env bash
# Drives skill-version.sh and skill-update.sh. Run in a container:
#
#   podman run --rm --userns=keep-id --network=none \
#     -v "$PWD:/skill:ro,Z" -v "$(mktemp -d):/work:Z" -w /work \
#     --entrypoint="" \
#     docker.io/bitnami/git@sha256:1baa6ddbde79fa7ba2fdf441cea47c4f04fae067504d9265e416358db0879ab2 \
#     bash /skill/testing/run-tests.sh
#
# The source mount is read-only because both scripts rewrite SKILL.md files. A
# passing run therefore also proves neither one writes back into its own source.
# --network=none proves the same about the network: standalone mode is driven
# against a local bare repo with a stubbed gh, never against GitHub.
#
# The failure cases are the point. A gate that never rejects anything is not a
# gate, and verify's whole job is to reject.
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SRC=$(cd "$HERE/.." && pwd)
WORK=${WORK:-/work}
PASS=0
FAIL=0

ok()  { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
hd()  { printf '\n=== %s\n' "$1"; }

check() { # desc, condition already evaluated as $2 exit status
  if [[ $2 -eq 0 ]]; then ok "$1"; else bad "$1"; fi
}

# Inverts a command's success into check()'s 0-is-good convention. Written as an
# if rather than arithmetic on $? because git returns 128, not 1, for a missing
# ref, and 1-128 is not a passing value.
neg() { if "$@" >/dev/null 2>&1; then echo 1; else echo 0; fi; }

expect_rc() { # desc want cmd...
  local desc=$1 want=$2 got
  shift 2
  "$@" >/dev/null 2>&1
  got=$?
  if [[ $got -eq $want ]]; then ok "$desc (exit $got)"; else bad "$desc (exit $got, want $want)"; fi
}

# The scripts are copied out of the read-only mount so nothing is executed from
# a path the tests could accidentally write to.
mkdir -p "$WORK/bin"
cp "$SRC/scripts/skill-version.sh" "$SRC/scripts/skill-update.sh" "$WORK/bin/"
SV="$WORK/bin/skill-version.sh"
SU="$WORK/bin/skill-update.sh"

# ── fixtures ───────────────────────────────────────────────────────────────────
mkfixture() { # $1 = skills dir to build
  local d=$1
  rm -rf "$d"
  mkdir -p "$d/alpha/scripts" "$d/beta" "$d/not-a-skill"
  cat > "$d/alpha/SKILL.md" <<'EOF'
---
name: alpha
description: Fixture skill carrying no version yet.
---

# Alpha

> **This copy is read-only.**
> Upstream is https://raw.githubusercontent.com/jkkelley/dotfiles/refs/heads/main/claude/skills/alpha/SKILL.md, and `skill-update.sh` pulls it from there - no dotfiles checkout is needed on this machine.
EOF
  printf 'echo alpha\n' > "$d/alpha/scripts/run.sh"
  cat > "$d/beta/SKILL.md" <<'EOF'
---
name: beta
description: Fixture skill that already carries a version.
version: 2.3.4
---

# Beta

> **This copy is read-only.**
> Upstream is https://raw.githubusercontent.com/jkkelley/dotfiles/refs/heads/main/claude/skills/beta/SKILL.md, and `skill-update.sh` pulls it from there - no dotfiles checkout is needed on this machine.
EOF
  # A directory with no SKILL.md is not a skill and must never reach the registry.
  printf 'not a skill\n' > "$d/not-a-skill/README.md"
}

setup_project() { # $1 = worktree path, $2 = bare origin path
  local proj=$1 origin=$2
  rm -rf "$proj" "$origin"
  git init --bare -b main "$origin" >/dev/null 2>&1
  git init -b main "$proj" >/dev/null 2>&1
  git -C "$proj" config user.email tester@example.com
  git -C "$proj" config user.name Tester
  printf 'fixture\n' > "$proj/README.md"
  git -C "$proj" add -A >/dev/null 2>&1
  git -C "$proj" commit -q -m "initial commit"
  git -C "$proj" remote add origin "$origin"
  git -C "$proj" push -q -u origin main
}

# ── 1. every entry point loads ─────────────────────────────────────────────────
hd "entry points"
expect_rc "skill-version.sh --help" 0 bash "$SV" --help
expect_rc "skill-update.sh --help"  0 bash "$SU" --help
expect_rc "skill-version.sh rejects an unknown subcommand" 1 bash "$SV" frobnicate

# ── 2. init ────────────────────────────────────────────────────────────────────
hd "init"
SKILLS="$WORK/skills"
mkfixture "$SKILLS"
export SKILL_VERSION_SKILLS_DIR="$SKILLS"

bash "$SV" init >/dev/null 2>&1
check "init stamps an unversioned skill at 1.0.0" \
  "$(grep -qx 'version: 1.0.0' "$SKILLS/alpha/SKILL.md"; echo $?)"
check "init leaves an already-versioned skill alone" \
  "$(grep -qx 'version: 2.3.4' "$SKILLS/beta/SKILL.md"; echo $?)"
check "init writes the registry" "$([[ -f "$SKILLS/registry.json" ]]; echo $?)"
check "a directory without SKILL.md stays out of the registry" \
  "$(neg grep -q 'not-a-skill' "$SKILLS/registry.json")"

cp "$SKILLS/registry.json" "$WORK/reg1.json"
bash "$SV" init >/dev/null 2>&1
check "init is idempotent and the registry is byte-identical" \
  "$([[ "$(cat "$WORK/reg1.json")" == "$(cat "$SKILLS/registry.json")" ]]; echo $?)"

# ── 3. verify: the negative cases are the reason it exists ─────────────────────
hd "verify"
expect_rc "verify passes on a freshly initialised tree" 0 bash "$SV" verify

printf 'echo drift\n' >> "$SKILLS/alpha/scripts/run.sh"
expect_rc "verify FAILS when a skill changes without a bump" 1 bash "$SV" verify
bash "$SV" verify > "$WORK/verify-drift.out" 2>&1
check "verify names the skill that drifted" \
  "$(grep -q '^drifted .*alpha' "$WORK/verify-drift.out"; echo $?)"

bash "$SV" bump alpha --patch >/dev/null 2>&1
expect_rc "verify passes once the drifted skill is bumped" 0 bash "$SV" verify
check "--patch took 1.0.0 to 1.0.1" \
  "$(grep -qx 'version: 1.0.1' "$SKILLS/alpha/SKILL.md"; echo $?)"

mkdir -p "$SKILLS/gamma"
printf -- '---\nname: gamma\ndescription: No version on purpose.\n---\n' > "$SKILLS/gamma/SKILL.md"
expect_rc "verify FAILS when any skill has no version" 1 bash "$SV" verify
bash "$SV" verify > "$WORK/verify-unversioned.out" 2>&1
check "verify names the unversioned skill" \
  "$(grep -q '^unversioned .*gamma' "$WORK/verify-unversioned.out"; echo $?)"
rm -rf "$SKILLS/gamma"

# The read-only notice is what a vendored copy carries into a project. A skill
# without it ships saying nothing, and skill-update.sh will one day replace a
# local edit with no conflict and no warning. The gate is the only thing that
# stops a new skill from being born that way.
cp "$SKILLS/alpha/SKILL.md" "$WORK/alpha-ro.bak"
grep -v 'This copy is read-only.' "$WORK/alpha-ro.bak" > "$SKILLS/alpha/SKILL.md"
expect_rc "verify FAILS when a skill has no read-only notice" 1 bash "$SV" verify
bash "$SV" verify > "$WORK/verify-noro.out" 2>&1
check "verify names the skill missing the notice" \
  "$(grep -q '^no read-only notice .*alpha' "$WORK/verify-noro.out"; echo $?)"
# The URL is half the notice, and the half that still works on a machine with no
# dotfiles checkout. Checked per skill, because the likeliest way to get it
# wrong is a copy-paste that kept the neighbour's name - which reads as correct
# and sends someone to the wrong skill.
sed 's|claude/skills/alpha|claude/skills/beta|g' "$WORK/alpha-ro.bak" > "$SKILLS/alpha/SKILL.md"
expect_rc "verify FAILS when the notice names another skill" 1 bash "$SV" verify
bash "$SV" verify > "$WORK/verify-wrongurl.out" 2>&1
check "verify names the skill whose notice points elsewhere" \
  "$(grep -q '^notice has no upstream URL.*alpha' "$WORK/verify-wrongurl.out"; echo $?)"

cp "$WORK/alpha-ro.bak" "$SKILLS/alpha/SKILL.md"
expect_rc "verify passes once the notice is back" 0 bash "$SV" verify

rm -rf "$SKILLS/beta"
expect_rc "verify FAILS when the registry lists a skill that is gone" 1 bash "$SV" verify
bash "$SV" verify > "$WORK/verify-stale.out" 2>&1
check "verify names the stale registry entry" \
  "$(grep -q '^stale entry .*beta' "$WORK/verify-stale.out"; echo $?)"

# ── 4. bump arithmetic ─────────────────────────────────────────────────────────
hd "bump"
mkfixture "$SKILLS"
bash "$SV" init >/dev/null 2>&1

bash "$SV" bump alpha --minor >/dev/null 2>&1
check "--minor took 1.0.0 to 1.1.0" "$(grep -qx 'version: 1.1.0' "$SKILLS/alpha/SKILL.md"; echo $?)"
bash "$SV" bump alpha --patch >/dev/null 2>&1
check "--patch took 1.1.0 to 1.1.1" "$(grep -qx 'version: 1.1.1' "$SKILLS/alpha/SKILL.md"; echo $?)"
bash "$SV" bump alpha --major >/dev/null 2>&1
check "--major took 1.1.1 to 2.0.0 and zeroed the rest" \
  "$(grep -qx 'version: 2.0.0' "$SKILLS/alpha/SKILL.md"; echo $?)"
expect_rc "verify passes after every bump" 0 bash "$SV" verify

expect_rc "bump rejects an unknown skill"     1 bash "$SV" bump nope  --patch
expect_rc "bump rejects an unknown level"     1 bash "$SV" bump alpha --sideways
expect_rc "bump rejects a missing level"      1 bash "$SV" bump alpha

check "a rejected bump left the version untouched" \
  "$(grep -qx 'version: 2.0.0' "$SKILLS/alpha/SKILL.md"; echo $?)"

# ── 5. skill-update, inline ────────────────────────────────────────────────────
hd "skill-update --mode inline"
DOT="$WORK/dotfiles"
rm -rf "$DOT"
mkdir -p "$DOT/claude/skills"
mkfixture "$DOT/claude/skills"
SKILL_VERSION_SKILLS_DIR="$DOT/claude/skills" bash "$SV" init >/dev/null 2>&1

setup_project "$WORK/proj" "$WORK/origin.git"
expect_rc "inline exits 0" 0 \
  bash "$SU" --skill alpha --mode inline --project "$WORK/proj" --dotfiles "$DOT"
check "inline installed the skill" \
  "$([[ -f "$WORK/proj/.claude/skills/alpha/SKILL.md" ]]; echo $?)"
check "the installed copy carries the version" \
  "$(grep -qx 'version: 1.0.0' "$WORK/proj/.claude/skills/alpha/SKILL.md"; echo $?)"
check "inline left the change uncommitted" \
  "$([[ -n "$(git -C "$WORK/proj" status --porcelain -- .claude/skills/alpha)" ]]; echo $?)"

printf 'stale\n' > "$WORK/proj/.claude/skills/alpha/scripts/REMOVED-UPSTREAM.sh"
bash "$SU" --skill alpha --mode inline --project "$WORK/proj" --dotfiles "$DOT" >/dev/null 2>&1
check "inline deletes a file that no longer exists upstream" \
  "$([[ ! -f "$WORK/proj/.claude/skills/alpha/scripts/REMOVED-UPSTREAM.sh" ]]; echo $?)"

mkdir -p "$WORK/notarepo"
expect_rc "unknown skill rejected"  1 bash "$SU" --skill nope  --mode inline --project "$WORK/proj" --dotfiles "$DOT"
expect_rc "unknown mode rejected"   1 bash "$SU" --skill alpha --mode sideways --project "$WORK/proj" --dotfiles "$DOT"
expect_rc "missing --skill rejected" 1 bash "$SU" --mode inline --project "$WORK/proj" --dotfiles "$DOT"
expect_rc "missing project rejected" 1 bash "$SU" --skill alpha --mode inline --project "$WORK/nosuchdir" --dotfiles "$DOT"

# The remote path. Both of these are safe with --network=none: an unresolvable
# host and a nonexistent repo both fail the download, and the run must die
# rather than quietly copy nothing.
expect_rc "--from with a bad value rejected" 1 \
  bash "$SU" --skill alpha --mode inline --project "$WORK/proj" --from sideways
expect_rc "unreachable remote source fails" 1 \
  bash "$SU" --skill alpha --mode inline --project "$WORK/proj" --repo jkkelley/definitely-not-a-repo
expect_rc "non-repo rejected in standalone" 1 \
  bash "$SU" --skill alpha --mode standalone --project "$WORK/notarepo" --dotfiles "$DOT"

# ── 6. skill-update, standalone ────────────────────────────────────────────────
# gh is stubbed rather than mocked away entirely: the stub performs the merge on
# the local bare repo, so the branch/commit/push/merge/delete orchestration is
# genuinely exercised end to end without a network.
hd "skill-update --mode standalone"
export GH_STUB_STATE="$WORK/ghstate"
export GH_STUB_ORIGIN="$WORK/origin2.git"
mkdir -p "$GH_STUB_STATE"

cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
sub="${1:-} ${2:-}"; shift 2 || true
case "$sub" in
  "pr create")
    head=""
    while [[ $# -gt 0 ]]; do
      if [[ $1 == --head ]]; then head=${2:-}; fi
      shift
    done
    printf '%s\n' "$head" > "$GH_STUB_STATE/branch"
    printf 'https://example.invalid/pr/1\n'
    ;;
  "pr merge")
    b=$(cat "$GH_STUB_STATE/branch")
    git --git-dir="$GH_STUB_ORIGIN" update-ref refs/heads/main "refs/heads/$b"
    printf 'merged (stub)\n'
    ;;
  *)
    printf 'stub gh: unhandled invocation: %s\n' "$sub" >&2
    exit 64
    ;;
esac
STUB
chmod +x "$WORK/bin/gh"
export PATH="$WORK/bin:$PATH"

setup_project "$WORK/proj2" "$WORK/origin2.git"
bash "$SU" --skill alpha --mode standalone --project "$WORK/proj2" --dotfiles "$DOT" \
  > "$WORK/standalone.out" 2>&1
SA_RC=$?
if [[ $SA_RC -eq 0 ]]; then
  ok "standalone exits 0"
else
  bad "standalone exits 0 (got $SA_RC)"
  printf '    ---- last 25 lines ----\n'
  tail -25 "$WORK/standalone.out" | sed 's/^/    /'
fi

check "standalone reports the PR URL" \
  "$(grep -q 'https://example.invalid/pr/1' "$WORK/standalone.out"; echo $?)"
check "the skill landed on origin/main" \
  "$(git --git-dir="$WORK/origin2.git" cat-file -e main:.claude/skills/alpha/SKILL.md 2>/dev/null; echo $?)"
check "the throwaway worktree was removed" \
  "$([[ "$(git -C "$WORK/proj2" worktree list | wc -l)" -eq 1 ]]; echo $?)"
check "the local branch was deleted" \
  "$(neg git -C "$WORK/proj2" rev-parse --verify chore/skill-alpha-v1.0.0)"
check "the remote branch was deleted" \
  "$(neg git --git-dir="$WORK/origin2.git" rev-parse --verify chore/skill-alpha-v1.0.0)"
check "local main was fast-forwarded to the merged state" \
  "$([[ -f "$WORK/proj2/.claude/skills/alpha/SKILL.md" ]]; echo $?)"
check "the user's working tree was never the build surface (README untouched)" \
  "$([[ "$(cat "$WORK/proj2/README.md")" == "fixture" ]]; echo $?)"
check "a run log was written" \
  "$(ls "$WORK/proj2"/.claude/logs/skill-update-alpha-*.log >/dev/null 2>&1; echo $?)"

# Re-running against an already-current origin must be a clean no-op, not a
# second empty PR.
bash "$SU" --skill alpha --mode standalone --project "$WORK/proj2" --dotfiles "$DOT" \
  > "$WORK/standalone2.out" 2>&1
NOOP_RC=$?
check "a second standalone run exits 0" "$([[ $NOOP_RC -eq 0 ]]; echo $?)"
check "a second standalone run opens no PR" \
  "$(grep -q 'already v1.0.0' "$WORK/standalone2.out"; echo $?)"

# ── 7. failure reporting ───────────────────────────────────────────────────────
hd "failure reporting"
setup_project "$WORK/proj3" "$WORK/origin3.git"
git -C "$WORK/proj3" remote set-url origin "$WORK/does-not-exist.git"
bash "$SU" --skill alpha --mode standalone --project "$WORK/proj3" --dotfiles "$DOT" \
  > "$WORK/fail.out" 2>&1
FAIL_RC=$?
check "an unreachable remote fails non-zero" "$([[ $FAIL_RC -ne 0 ]]; echo $?)"
check "the failure names the step it died on" \
  "$(grep -q 'step: fetch origin' "$WORK/fail.out"; echo $?)"
check "the failure points at the log" "$(grep -q 'log:' "$WORK/fail.out"; echo $?)"

# ── summary ────────────────────────────────────────────────────────────────────
printf '\n=========================================\n'
printf '  PASS %d   FAIL %d\n' "$PASS" "$FAIL"
printf '=========================================\n'
[[ $FAIL -eq 0 ]]
