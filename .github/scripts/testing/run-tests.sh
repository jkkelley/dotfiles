#!/usr/bin/env bash
#
# run-tests.sh - the only entry point for .github/scripts/.
#
# The gate this drives is the one piece of the pipeline whose natural feedback
# loop is a push. Every branch below is therefore exercised against a fixture
# repository built in a scratch mount, so the workflow's shell arrives at CI
# already proved rather than being debugged there one push at a time.
#
# Everything runs inside Podman, per root CLAUDE.md Rule 14, which has no size
# threshold.
#
#   --network=none      nothing here reaches anything. The gate reads a tree and
#                       a registry file, and that is all it is allowed to do
#   /repo mounted ro    a passing run also proves the gate never writes into the
#                       repository it is reading, which is its whole contract
#   /work separate      every fixture lands in a scratch mount
#   --userns=keep-id    files in that mount are owned by you, not by root
#
# The refusals are the point. A gate exists to say no, and a gate that has only
# ever been watched saying yes is decorative.
#
# No -e, deliberately. Most checks here run a command that is expected to fail.
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$HERE/../../.." && pwd)

# Pinned by digest per Rule 15. docker.io/bitnami/git:latest as of 2026-08-23,
# the same digest the living-docs, context-compaction and skill-versioning
# suites run on. git is a dependency here rather than an accident: the fixture
# is a real repository and the trailers are parsed by git interpret-trailers.
IMAGE="${GATE_TEST_IMAGE:-docker.io/bitnami/git@sha256:1baa6ddbde79fa7ba2fdf441cea47c4f04fae067504d9265e416358db0879ab2}"

if [[ ${IN_GATE_CONTAINER:-0} != 1 ]]; then
  command -v podman >/dev/null 2>&1 || {
    printf 'podman is required: every check in this suite runs in a container.\n' >&2
    printf 'Running these on the host would prove only that they work on this machine.\n' >&2
    exit 1
  }
  SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-gate-test.XXXXXX")
  trap 'rm -rf -- "$SCRATCH"' EXIT INT TERM
  exec podman run --rm --userns=keep-id --network=none --entrypoint="" \
    -v "$REPO_ROOT:/repo:ro,Z" -v "$SCRATCH:/work:Z" -w /work \
    -e IN_GATE_CONTAINER=1 \
    "$IMAGE" bash /repo/.github/scripts/testing/run-tests.sh
fi

# ── inside the container from here ─────────────────────────────────────────────
WORK=${WORK:-/work}
GATE=/repo/.github/scripts/bump-gate.sh
PASS=0
FAIL=0

export GIT_AUTHOR_NAME=gate GIT_AUTHOR_EMAIL=gate@example.com
export GIT_COMMITTER_NAME=gate GIT_COMMITTER_EMAIL=gate@example.com

ok()  { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; printf '        %s\n' "${2:-}"; FAIL=$((FAIL + 1)); }
hd()  { printf '\n=== %s\n' "$1"; }

want_eq() { # label want got
  if [[ $2 == "$3" ]]; then ok "$1"; else bad "$1" "want [$2], got [$3]"; fi
}
want_rc() { # label want got extra
  if [[ $2 -eq $3 ]]; then ok "$1"; else bad "$1" "want exit $2, got $3. ${4:-}"; fi
}
want_has() { # label needle haystack
  if [[ $3 == *"$2"* ]]; then ok "$1"; else bad "$1" "no [$2] in: $3"; fi
}
want_not() { # label needle haystack
  if [[ $3 != *"$2"* ]]; then ok "$1"; else bad "$1" "unwanted [$2] in: $3"; fi
}

# ── the fixture ────────────────────────────────────────────────────────────────
# A repository shaped exactly like this one: skills under claude/skills/, a
# registry beside them, a tools tree and a .github tree. main holds the base
# commit; every case branches from it, changes something, and commits.
#
# alpha and beta ship a suite. gamma does not, which is what separates "changed"
# from "changed and testable" in detect. delta is absent from the registry,
# which is how a brand new skill arrives.
mkfixture() {
  local p="$WORK/$1"
  rm -rf "$p"; mkdir -p "$p"
  (
    cd "$p" || exit 1
    git init -q -b main .
    local s
    for s in alpha beta gamma; do
      mkdir -p "claude/skills/$s"
      printf -- '---\nname: %s\nversion: 1.2.3\n---\n\n%s.\n' "$s" "$s" > "claude/skills/$s/SKILL.md"
    done
    for s in alpha beta; do
      mkdir -p "claude/skills/$s/testing"
      printf '#!/usr/bin/env bash\nexit 0\n' > "claude/skills/$s/testing/run-tests.sh"
    done
    cat > claude/skills/registry.json <<'JSON'
{
  "schema": 2,
  "generator": "skill-version.sh",
  "skills": {
    "alpha": { "version": "1.2.3", "sha256": "aaa", "type": "skill", "requires": [] },
    "beta": { "version": "2.0.0", "sha256": "bbb", "type": "skill", "requires": [] },
    "gamma": { "version": "0.9.9", "sha256": "ccc", "type": "skill", "requires": [] }
  },
  "tools": {
    "beta": { "version": "9.9.9", "sha256": "ddd" }
  }
}
JSON
    mkdir -p claude/tools/testing .github/workflows docs
    printf 'tool\n'  > claude/tools/thing.sh
    printf 'wf\n'    > .github/workflows/other.yml
    printf 'docs\n'  > docs/README.md
    git add -A && git commit -qm 'base'
    git checkout -qb work
  ) || { printf 'fixture build failed\n' >&2; exit 1; }
  printf '%s' "$p"
}

commit_in() { # dir msg
  git -C "$1" add -A && git -C "$1" commit -qm "$2"
}

# resolve <dir> <title> <body> -> stdout+stderr in OUT, exit in RC
#
# The title and body land outside the fixture on purpose. Written inside it they
# would be indistinguishable from the gate having written something, and the
# check that the gate writes nothing would be checking the harness instead.
resolve() {
  local p=$1 title=$2 body=$3
  printf '%s\n' "$title" > "$WORK/title.txt"
  printf '%s\n' "$body"  > "$WORK/body.txt"
  OUT=$(bash "$GATE" resolve --repo "$p" --base main \
          --title-file "$WORK/title.txt" --body-file "$WORK/body.txt" 2>&1)
  RC=$?
}

detect() {
  OUT=$(bash "$GATE" detect --repo "$1" --base main 2>&1)
  RC=$?
}

printf '\n.github/scripts - the PR gate\n\n'

# ── detect ─────────────────────────────────────────────────────────────────────
hd 'detect - what changed, and what of it is testable'

P=$(mkfixture d1); printf 'more\n' >> "$P/docs/README.md"; commit_in "$P" docs
detect "$P"
want_rc  'docs-only: exit 0' 0 $RC "$OUT"
want_has 'docs-only: empty matrix'  'skills=[]'  "$OUT"
want_has 'docs-only: no tools job'  'tools=false' "$OUT"
want_has 'docs-only: no gate job'   'gate=false'  "$OUT"

P=$(mkfixture d2); printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"; commit_in "$P" alpha
detect "$P"
want_has 'one skill with a suite: one leg' 'skills=["alpha"]' "$OUT"

P=$(mkfixture d3); printf 'x\n' >> "$P/claude/skills/gamma/SKILL.md"; commit_in "$P" gamma
detect "$P"
want_has 'skill with no suite: no leg' 'skills=[]' "$OUT"

P=$(mkfixture d4)
printf 'x\n' >> "$P/claude/skills/beta/SKILL.md"
printf 'x\n' >> "$P/claude/skills/alpha/testing/run-tests.sh"
commit_in "$P" two
detect "$P"
want_has 'two skills: sorted, both legs' 'skills=["alpha","beta"]' "$OUT"

P=$(mkfixture d5); printf 'x\n' >> "$P/claude/tools/thing.sh"; commit_in "$P" tools
detect "$P"
want_has 'claude/tools change: tools job on' 'tools=true' "$OUT"
want_has 'claude/tools change: matrix still empty' 'skills=[]' "$OUT"

P=$(mkfixture d6); printf 'x\n' >> "$P/.github/workflows/other.yml"; commit_in "$P" gh
detect "$P"
want_has '.github change: gate self-test on' 'gate=true' "$OUT"

# registry.json lives directly under claude/skills/ with no directory of its
# own. If the path split ever treats it as a skill name the matrix grows a leg
# for a skill that does not exist, and the job fails on a missing directory.
P=$(mkfixture d7); printf '\n' >> "$P/claude/skills/registry.json"; commit_in "$P" reg
detect "$P"
want_has 'registry.json is not a skill' 'skills=[]' "$OUT"

# A deleted skill still shows up in the diff. It must not become a matrix leg:
# the job would check out a tree with no such directory and fail on the mount.
P=$(mkfixture d8); rm -rf "$P/claude/skills/alpha"; commit_in "$P" 'rm alpha'
detect "$P"
want_has 'deleted skill: no matrix leg' 'skills=[]' "$OUT"

# ── resolve, the happy paths ───────────────────────────────────────────────────
hd 'resolve - a level for every changed skill'

P=$(mkfixture r0); printf 'more\n' >> "$P/docs/README.md"; commit_in "$P" docs
resolve "$P" 'docs: tidy the readme' ''
want_rc  'docs-only: exit 0' 0 $RC "$OUT"
want_has 'docs-only: says so' 'Nothing to resolve' "$OUT"

P=$(mkfixture r1); printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"; commit_in "$P" a
resolve "$P" 'feat(skills): something' 'Body.

Bump: alpha=major'
want_rc  'trailer major: exit 0' 0 $RC "$OUT"
want_has 'trailer major: 1.2.3 -> 2.0.0' '1.2.3     -> 2.0.0' "$OUT"
want_has 'trailer major: source is the trailer' 'major  trailer' "$OUT"

resolve "$P" 'feat(skills): something' ''
want_rc  'title feat: exit 0' 0 $RC "$OUT"
want_has 'title feat: minor, 1.3.0' '1.2.3     -> 1.3.0     minor  title' "$OUT"

resolve "$P" 'fix(skills): something' ''
want_has 'title fix: patch, 1.2.4' '1.2.3     -> 1.2.4     patch  title' "$OUT"

resolve "$P" 'feat(skills)!: something' ''
want_has 'title feat!: major' '-> 2.0.0     major  title' "$OUT"

resolve "$P" 'feat(skills): something' 'BREAKING CHANGE: the flag is gone'
want_has 'BREAKING CHANGE footer: major' '-> 2.0.0     major  title' "$OUT"

resolve "$P" 'chore(skills): reword a comment' ''
want_has 'title chore: patch' '-> 1.2.4     patch  title' "$OUT"

# The trailer is the explicit statement and the title is the inferred one. An
# explicit statement that loses to an inference is not a statement, so the
# trailer wins - and the table is what makes the override visible.
resolve "$P" 'feat(skills): something' 'Bump: alpha=patch'
want_rc  'trailer beats title: exit 0' 0 $RC "$OUT"
want_has 'trailer beats title: patch, not minor' '-> 1.2.4     patch  trailer' "$OUT"

P=$(mkfixture r2)
printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"
printf 'x\n' >> "$P/claude/skills/beta/SKILL.md"
commit_in "$P" ab
resolve "$P" 'fix(skills): two of them' 'Bump: beta=major'
want_rc  'mixed sources: exit 0' 0 $RC "$OUT"
want_has 'mixed sources: alpha falls back to the title' 'alpha                      1.2.3     -> 1.2.4     patch  title' "$OUT"
want_has 'mixed sources: beta takes the trailer'        'beta                       2.0.0     -> 3.0.0     major  trailer' "$OUT"

# Absence from the registry is unambiguous, so a new skill needs no trailer and
# no title type. If the gate demanded one, adding a skill would be the one
# change nobody could land.
P=$(mkfixture r3)
mkdir -p "$P/claude/skills/delta"
printf -- '---\nname: delta\n---\n\nNew.\n' > "$P/claude/skills/delta/SKILL.md"
commit_in "$P" delta
resolve "$P" 'a title with no type at all' ''
want_rc  'new skill: exit 0 with no trailer' 0 $RC "$OUT"
want_has 'new skill: stamped at 1.0.0' '-> 1.0.0     new    absent from the registry' "$OUT"

# A deleted skill is not a skill that needs a bump. The publisher regenerates
# the registry from the tree and the row goes away on its own.
P=$(mkfixture r4); rm -rf "$P/claude/skills/gamma"; commit_in "$P" rm
resolve "$P" 'a title with no type at all' ''
want_rc  'deleted skill: exit 0, no bump wanted' 0 $RC "$OUT"
want_not 'deleted skill: absent from the table' 'gamma' "$OUT"

# ── resolve, the refusals ──────────────────────────────────────────────────────
hd 'resolve - the refusals, which are the point'

P=$(mkfixture x1); printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"; commit_in "$P" a

resolve "$P" 'feat(skills): something' 'Bump: beta=major'
want_rc  'trailer names an unchanged skill: refused' 1 $RC "$OUT"
want_has 'trailer names an unchanged skill: names it' 'not changed here    beta' "$OUT"

resolve "$P" 'feat(skills): something' 'Bump: alpa=major'
want_rc  'typo in the skill name: refused' 1 $RC "$OUT"
want_has 'typo in the skill name: names it' 'no such skill       alpa' "$OUT"

# A level that is not one of the three words is refused rather than corrected,
# and the title's fallback does not quietly rescue it: the run still exits 1.
resolve "$P" 'feat(skills): something' 'Bump: alpha=mayor'
want_rc  'typo in the level: refused' 1 $RC "$OUT"
want_has 'typo in the level: names it' 'bad level           alpha=mayor' "$OUT"

resolve "$P" 'feat(skills): something' 'Bump: alpha=MAJOR'
want_rc  'uppercase level: refused' 1 $RC "$OUT"

resolve "$P" 'feat(skills): something' 'Bump: alpha=minor
Bump: alpha=patch'
want_rc  'same skill named twice: refused' 1 $RC "$OUT"
want_has 'same skill named twice: shows both' 'named twice         alpha   (minor and then patch)' "$OUT"

resolve "$P" 'feat(skills): something' 'Bump: alpha major'
want_rc  'trailer with no equals: refused' 1 $RC "$OUT"
want_has 'trailer with no equals: quotes it' 'malformed trailer' "$OUT"

resolve "$P" 'no conventional type here' ''
want_rc  'no trailer and no parseable title: refused' 1 $RC "$OUT"
want_has 'no trailer and no parseable title: names the skill' 'unresolved          alpha' "$OUT"

# Reverting a feature is not a patch, and what the right level is depends on
# what was reverted. Left unmapped on purpose so it forces an explicit trailer.
resolve "$P" 'revert: undo the thing' ''
want_rc  'revert: has no fallback level' 1 $RC "$OUT"

# One round of CI per error is how a three-typo description costs three pushes.
resolve "$P" 'no conventional type here' 'Bump: beta=major
Bump: nosuch=patch'
want_rc  'three problems at once: refused' 1 $RC "$OUT"
want_has 'three problems: the unchanged skill'  'not changed here    beta'  "$OUT"
want_has 'three problems: the missing skill'    'no such skill       nosuch' "$OUT"
want_has 'three problems: the unresolved skill' 'unresolved          alpha'  "$OUT"

# ── the gate writes nothing ────────────────────────────────────────────────────
hd 'the gate writes nothing'

P=$(mkfixture w1); printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"; commit_in "$P" a
BEFORE=$(cd "$P" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum)
resolve "$P" 'feat(skills): something' 'Bump: alpha=major'
detect "$P"
AFTER=$(cd "$P" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum)
# .t and .b are the harness's own title and body files, written before the run.
want_eq 'the tree is byte-identical after resolve and detect' "$BEFORE" "$AFTER"

# ── the suite dispatch, against the real repository ────────────────────────────
hd 'run-suite - dispatch, checked against every real suite'

# These are the seven suites as they actually are today, not as a list this
# file keeps in step by hand. Three containerise themselves and must be invoked
# directly; four expect to be started inside a container already. A wrong answer
# either runs a suite on the host, which Rule 14 forbids, or tries podman inside
# a container, which cannot work.
for s in cartography project-scaffold work-order; do
  OUT=$(bash "$GATE" run-suite "/repo/claude/skills/$s" --print 2>&1)
  want_eq "dispatch: $s runs its own container" 'self' "$OUT"
done
for s in context-compaction hydration-prompt living-docs skill-versioning; do
  OUT=$(bash "$GATE" run-suite "/repo/claude/skills/$s" --print 2>&1)
  want_eq "dispatch: $s is wrapped" 'wrapped' "$OUT"
done
OUT=$(bash "$GATE" run-suite /repo/claude/tools --print 2>&1)
want_eq 'dispatch: claude/tools runs its own container' 'self' "$OUT"

# Every skill the matrix can produce has to be dispatchable. A suite that is
# neither is a leg that fails on the runner for a reason nobody can read.
MISSED=""
for d in /repo/claude/skills/*/; do
  [[ -f "$d/testing/run-tests.sh" ]] || continue
  bash "$GATE" run-suite "$d" --print >/dev/null 2>&1 || MISSED="$MISSED $(basename "$d")"
done
want_eq 'every real suite dispatches' '' "$MISSED"

# ── the interface ──────────────────────────────────────────────────────────────
hd 'the interface'

bash "$GATE" --help >/dev/null 2>&1; want_rc '--help exits 0' 0 $?
bash "$GATE" >/dev/null 2>&1;        want_rc 'no arguments exits 2' 2 $?
bash "$GATE" nonsense >/dev/null 2>&1; want_rc 'unknown command exits 2' 2 $?
bash "$GATE" detect --repo "$P" >/dev/null 2>&1; want_rc 'detect with no --base exits 2' 2 $?
bash "$GATE" detect --repo "$P" --base nope >/dev/null 2>&1; want_rc 'detect with a bad --base exits 2' 2 $?
bash "$GATE" run-suite /repo/docs --print >/dev/null 2>&1; want_rc 'run-suite on a dir with no suite exits 2' 2 $?

# ── ─────────────────────────────────────────────────────────────────────────────
printf '\n%d passed, %d failed\n\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
