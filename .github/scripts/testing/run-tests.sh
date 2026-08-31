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
# the same digest the living-docs, context-compaction and skill-registry
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
for s in context-compaction hydration-prompt living-docs skill-registry; do
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

# ══ the publisher ══════════════════════════════════════════════════════════════
#
# publish.sh writes, which the gate never does, so its fixture has to be a
# repository the real skill-version.sh can operate on: a copy of that script
# lives inside each fixture and renders the registry itself. That makes the
# registry real - real hashes over the real tree - which is the only way verify
# can be exercised as the loop guard rather than mocked.
#
# It is a second builder rather than a flag on mkfixture because the gate's
# fixture states a different contract: a hand-written registry, with a tools
# block whose key collides with a skill name, which is what proves the skills
# block is scoped. Rendering that registry would delete the collision.

PUB=/repo/.github/scripts/publish.sh
SVREL=claude/skills/skill-registry/scripts/skill-version.sh

mkpub() {
  local p="$WORK/$1"
  rm -rf "$p"; mkdir -p "$p"
  (
    cd "$p" || exit 1
    git init -q -b main .
    mkdir -p "claude/skills/skill-registry/scripts" claude/tools docs \
             claude/skills/alpha claude/skills/beta claude/skills/gamma
    printf -- '---\nname: skill-registry\nversion: 1.0.0\n---\n\nOwns the registry.\n' \
      > claude/skills/skill-registry/SKILL.md
    cp "/repo/$SVREL" "$SVREL"
    printf -- '---\nname: alpha\nversion: 1.2.3\n---\n\nalpha.\n' > claude/skills/alpha/SKILL.md
    printf -- '---\nname: beta\nversion: 2.0.0\n---\n\nbeta.\n'  > claude/skills/beta/SKILL.md
    printf -- '---\nname: gamma\nversion: 0.9.9\n---\n\ngamma.\n' > claude/skills/gamma/SKILL.md
    printf 'docs\n' > docs/README.md
    # The registry is generated, not written here. A hand-written one would put
    # the fixture in the state verify exists to detect, and every check below
    # would start from red.
    bash "$SVREL" init >/dev/null || exit 1
    git add -A && git commit -qm 'base'
  ) || { printf 'publisher fixture build failed\n' >&2; exit 1; }
  printf '%s' "$p"
}

svin() { bash "$1/$SVREL" "${@:2}"; }
head_of() { git -C "$1" rev-parse HEAD; }

# Reads the version out of the registry rather than out of SKILL.md, because a
# bump that moved one and not the other is precisely the drift being guarded
# against, and reading the file the consumers read is what proves it landed.
regver() {
  sed -n '/^  "skills": {/,/^  },/p' "$1/claude/skills/registry.json" \
    | grep -m1 "\"$2\":" | sed 's/.*"version": "\([^"]*\)".*/\1/'
}
mdver() {
  grep -m1 '^version:' "$1/claude/skills/$2/SKILL.md" | sed 's/^version:[[:space:]]*//'
}
treehash() {
  (cd "$1" && find . -path ./.git -prune -o -type f -print0 \
    | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum)
}

pcommit() { # dir subject [body]
  git -C "$1" add -A
  if [[ -n ${3:-} ]]; then
    git -C "$1" commit -q -m "$2" -m "$3"
  else
    git -C "$1" commit -q -m "$2"
  fi
}

pplan()  { OUT=$(bash "$PUB" plan  --repo "$1" --before "$2" 2>&1); RC=$?; }
papply() { OUT=$(bash "$PUB" apply --repo "$1" --before "$2" 2>&1); RC=$?; }

printf '\n\n.github/scripts - the publisher\n'

# ── the loop guard ─────────────────────────────────────────────────────────────
hd 'the loop guard - a run with nothing to do is free'

# AC-H2's shape. It is also what stops the second run of a batch re-bumping what
# the first one already did, so it comes before anything reads a trailer.
P=$(mkpub g1); B=$(head_of "$P"); H=$B
papply "$P" "$B"
want_rc  'verify green: exit 0' 0 $RC "$OUT"
want_has 'verify green: says there is nothing to allocate' 'Nothing to allocate' "$OUT"
want_eq  'verify green: no commit made' "$H" "$(head_of "$P")"
want_not 'verify green: never got as far as a range' 'range   ' "$OUT"

# ── a single skill ─────────────────────────────────────────────────────────────
hd 'one skill, one commit'

P=$(mkpub s1); B=$(head_of "$P")
printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"
pcommit "$P" 'chore(skills): tweak alpha' 'Bump: alpha=minor'

SNAP=$(treehash "$P")
pplan "$P" "$B"
want_rc  'plan: exit 0' 0 $RC "$OUT"
want_has 'plan: 1.2.3 -> 1.3.0 from the trailer' '1.2.3     -> 1.3.0     minor  trailer' "$OUT"
want_has 'plan: names the commit it read'        'chore(skills): tweak alpha' "$OUT"
want_eq  'plan writes nothing' "$SNAP" "$(treehash "$P")"

papply "$P" "$B"
want_rc  'apply: exit 0' 0 $RC "$OUT"
want_eq  'apply: SKILL.md carries the new version'  '1.3.0' "$(mdver  "$P" alpha)"
want_eq  'apply: the registry agrees'               '1.3.0' "$(regver "$P" alpha)"
want_eq  'apply: nothing else moved'                '2.0.0' "$(regver "$P" beta)"
svin "$P" verify >/dev/null 2>&1
want_rc  'apply: verify is green afterwards' 0 $?
want_has 'apply: the commit carries the marker' 'Skill-Publish: true' "$(git -C "$P" log -1 --format=%B)"
want_has 'apply: the commit says what it allocated' 'alpha -> 1.3.0 (minor, from the trailer)' \
  "$(git -C "$P" log -1 --format=%B)"

# The publisher writes version: lines and registry.json. A file it touched
# outside claude/skills/ would mean the scoped add is not doing its job.
OUT=$(git -C "$P" show --name-only --format= HEAD)
want_has 'apply: it wrote the registry'   'claude/skills/registry.json' "$OUT"
want_has 'apply: and the version line'    'claude/skills/alpha/SKILL.md' "$OUT"
want_not 'apply: and nothing outside the skills tree' 'docs/README.md' "$OUT"

# A run against a tree the publisher has already published finds verify green.
papply "$P" "$B"
want_rc  'a second run over the same range: exit 0' 0 $RC "$OUT"
want_has 'a second run over the same range: nothing to do' 'Nothing to allocate' "$OUT"

P=$(mkpub s2); B=$(head_of "$P")
printf 'x\n' >> "$P/claude/skills/beta/SKILL.md"
pcommit "$P" 'fix(skills): beta typo'
pplan "$P" "$B"
want_has 'title fix: patch, from the title' '2.0.0     -> 2.0.1     patch  title' "$OUT"

P=$(mkpub s3); B=$(head_of "$P")
printf 'x\n' >> "$P/claude/skills/beta/SKILL.md"
pcommit "$P" 'feat(skills)!: beta loses a flag'
pplan "$P" "$B"
want_has 'title feat!: major' '2.0.0     -> 3.0.0     major  title' "$OUT"

# ── a new skill ────────────────────────────────────────────────────────────────
hd 'a skill absent from the registry needs no trailer'

P=$(mkpub n1); B=$(head_of "$P")
mkdir -p "$P/claude/skills/delta"
printf -- '---\nname: delta\n---\n\nNew.\n' > "$P/claude/skills/delta/SKILL.md"
pcommit "$P" 'a subject with no conventional type at all'
pplan "$P" "$B"
want_rc  'new skill: plan exits 0 with no trailer and no type' 0 $RC "$OUT"
want_has 'new skill: stamped at 1.0.0' '-> 1.0.0     new    absent from the registry' "$OUT"

papply "$P" "$B"
want_rc  'new skill: apply exits 0' 0 $RC "$OUT"
want_eq  'new skill: 1.0.0 in the registry' '1.0.0' "$(regver "$P" delta)"
want_eq  'new skill: 1.0.0 in the frontmatter' '1.0.0' "$(mdver "$P" delta)"
svin "$P" verify >/dev/null 2>&1
want_rc  'new skill: verify green afterwards' 0 $?

# ── deletion ───────────────────────────────────────────────────────────────────
hd 'a deleted skill needs no bump, only a regenerated registry'

P=$(mkpub k1); B=$(head_of "$P")
rm -rf "$P/claude/skills/gamma"
pcommit "$P" 'a subject with no conventional type at all'
papply "$P" "$B"
want_rc  'deleted skill: exit 0, nothing to resolve' 0 $RC "$OUT"
want_not 'deleted skill: no row survives' '"gamma"' "$(cat "$P/claude/skills/registry.json")"
want_eq  'deleted skill: nothing else moved' '1.2.3' "$(regver "$P" alpha)"
svin "$P" verify >/dev/null 2>&1
want_rc  'deleted skill: verify green afterwards' 0 $?

# ── the refusal ────────────────────────────────────────────────────────────────
hd 'an unresolvable level fails the run and bumps nothing'

# AC-H3. The assertion that matters is the second one: a refusal that had
# already written half the registry would be worse than no refusal at all.
P=$(mkpub f1); B=$(head_of "$P")
printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"
pcommit "$P" 'a subject with no conventional type at all'
SNAP=$(treehash "$P"); H=$(head_of "$P")

papply "$P" "$B"
want_rc  'unresolvable: exit 1' 1 $RC "$OUT"
want_has 'unresolvable: names the skill'  'unresolved          alpha' "$OUT"
want_has 'unresolvable: names the commit' 'a subject with no conventional type at all' "$OUT"
want_eq  'unresolvable: every version unchanged' "$SNAP" "$(treehash "$P")"
want_eq  'unresolvable: no commit made' "$H" "$(head_of "$P")"
want_eq  'unresolvable: alpha still 1.2.3' '1.2.3' "$(regver "$P" alpha)"

# revert is unmapped on purpose: what the right level is depends on what was
# reverted, so it forces an explicit trailer rather than guessing.
P=$(mkpub f2); B=$(head_of "$P")
printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"
pcommit "$P" 'revert: undo the thing'
papply "$P" "$B"
want_rc 'revert has no fallback level: exit 1' 1 $RC "$OUT"

# One bad level in a batch stops the whole batch. Publishing the resolvable half
# would leave the other half's new content hash in the registry under its old
# version - the exact silent failure the wide range exists to prevent.
P=$(mkpub f3); B=$(head_of "$P")
printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"
pcommit "$P" 'feat(skills): alpha gains a thing'
printf 'x\n' >> "$P/claude/skills/beta/SKILL.md"
pcommit "$P" 'a subject with no conventional type at all'
papply "$P" "$B"
want_rc 'one bad commit in a batch: exit 1' 1 $RC "$OUT"
want_eq 'one bad commit in a batch: alpha not bumped either' '1.2.3' "$(regver "$P" alpha)"

P=$(mkpub f4); B=$(head_of "$P")
printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"
pcommit "$P" 'chore(skills): tweak alpha' 'Bump: alpha=mayor'
papply "$P" "$B"
want_rc  'a typo in the level: exit 1' 1 $RC "$OUT"
want_has 'a typo in the level: names it' 'malformed trailer' "$OUT"
want_eq  'a typo in the level: nothing bumped' '1.2.3' "$(regver "$P" alpha)"

# ── the batch ──────────────────────────────────────────────────────────────────
hd 'two merges in one push - AC-H1, and why the range is <before>..HEAD'

P=$(mkpub b1); B=$(head_of "$P")
printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"
pcommit "$P" 'feat(skills): alpha gains a thing'
printf 'x\n' >> "$P/claude/skills/beta/SKILL.md"
pcommit "$P" 'fix(skills): beta typo'

pplan "$P" "$B"
want_rc  'batch: plan exits 0' 0 $RC "$OUT"
want_has 'batch: alpha takes its own commit type' 'alpha                      1.2.3     -> 1.3.0     minor  title' "$OUT"
want_has 'batch: beta takes its own'              'beta                       2.0.0     -> 2.0.1     patch  title' "$OUT"

papply "$P" "$B"
want_rc  'batch: apply exits 0' 0 $RC "$OUT"
want_eq  'batch: alpha allocated' '1.3.0' "$(regver "$P" alpha)"
want_eq  'batch: beta allocated'  '2.0.1' "$(regver "$P" beta)"
svin "$P" verify >/dev/null 2>&1
want_rc  'batch: verify green afterwards' 0 $?
# One publisher commit covering both skills, not one per skill. Counted by the
# marker, because the range also holds the two merges that caused the run.
want_eq  'batch: one publisher commit for both' '1' \
  "$(git -C "$P" log "$B..HEAD" --format=%B | grep -c '^Skill-Publish: true')"

# The trap the wide range exists for, demonstrated rather than described.
# skill-version.sh bump regenerates the WHOLE registry, so bumping one of two
# changed skills silently writes the other's new content hash under its old
# version - and verify then reports green, forever.
P=$(mkpub b2)
printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"
printf 'x\n' >> "$P/claude/skills/beta/SKILL.md"
pcommit "$P" 'both'
svin "$P" bump alpha --patch >/dev/null
svin "$P" verify >/dev/null 2>&1
want_rc 'bumping one of two changed skills leaves verify green' 0 $?
want_eq 'and beta ships its change under its old number' '2.0.0' "$(regver "$P" beta)"

# Two commits touching the same skill resolve to the larger level. Taking the
# last one would make the answer depend on the order two unrelated pull
# requests happened to be merged in.
P=$(mkpub b3); B=$(head_of "$P")
printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"
pcommit "$P" 'fix(skills): a small one'
printf 'y\n' >> "$P/claude/skills/alpha/SKILL.md"
pcommit "$P" 'feat(skills): a bigger one'
pplan "$P" "$B"
want_has 'same skill twice: the higher level wins' '1.2.3     -> 1.3.0     minor' "$OUT"

P=$(mkpub b4); B=$(head_of "$P")
printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"
pcommit "$P" 'feat(skills): a bigger one'
printf 'y\n' >> "$P/claude/skills/alpha/SKILL.md"
pcommit "$P" 'fix(skills): a small one'
pplan "$P" "$B"
want_has 'same skill twice, other order: still the higher' '1.2.3     -> 1.3.0     minor' "$OUT"

# ── the publisher's own commits ────────────────────────────────────────────────
hd "the publisher skips its own commits"

# The loop guard normally exits before this matters. It matters anyway: without
# it, a chore(skills): subject maps to patch and the publisher bumps every skill
# its previous run touched a second time.
P=$(mkpub m1); B=$(head_of "$P")
printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"
pcommit "$P" 'chore(skills): allocate versions on main' 'Skill-Publish: true'
pplan "$P" "$B"
want_rc  'a marked commit: exit 0' 0 $RC "$OUT"
want_has 'a marked commit: reported as skipped' "this publisher's own commit, skipped" "$OUT"
want_has 'a marked commit: allocates nothing'   'No skill changed in this range' "$OUT"

# Only the marked one is skipped. A real merge sitting beside it still resolves.
P=$(mkpub m2); B=$(head_of "$P")
printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"
pcommit "$P" 'chore(skills): allocate versions on main' 'Skill-Publish: true'
printf 'x\n' >> "$P/claude/skills/beta/SKILL.md"
pcommit "$P" 'fix(skills): beta typo'
pplan "$P" "$B"
want_has 'a marked commit beside a real one: beta resolves' '2.0.0     -> 2.0.1     patch  title' "$OUT"
want_not 'a marked commit beside a real one: alpha does not appear' 'alpha  ' "$OUT"

# ── stray trailers ─────────────────────────────────────────────────────────────
hd 'a trailer naming a skill that commit never changed'

# The gate refuses this on the pull request. Arriving here means it was added
# afterwards, and a stale registry is a worse outcome than a trailer nobody
# acted on - so it is reported, not refused.
P=$(mkpub t1); B=$(head_of "$P")
printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"
pcommit "$P" 'chore(skills): tweak alpha' 'Bump: alpha=minor
Bump: beta=major'
pplan "$P" "$B"
want_rc  'stray trailer: exit 0' 0 $RC "$OUT"
want_has 'stray trailer: reported'  'ignored trailer' "$OUT"
want_has 'stray trailer: names it'  'Bump: beta=major' "$OUT"
want_has 'stray trailer: alpha still resolves' '-> 1.3.0     minor  trailer' "$OUT"
want_not 'stray trailer: beta is not in the table' 'beta   ' "$OUT"

# ── the range ──────────────────────────────────────────────────────────────────
hd '--before, and what happens when it is not a commit'

P=$(mkpub e1); B=$(head_of "$P")
printf 'x\n' >> "$P/claude/skills/alpha/SKILL.md"
pcommit "$P" 'fix(skills): alpha'
pplan "$P" '0000000000000000000000000000000000000000'
want_rc  'forty zeroes: falls back rather than failing' 0 $RC "$OUT"
want_has 'forty zeroes: says it fell back' 'fell back to HEAD~1..HEAD' "$OUT"
want_has 'forty zeroes: and still resolves the tip' '-> 1.2.4     patch  title' "$OUT"

pplan "$P" 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef'
want_rc  'an unknown sha: falls back' 0 $RC "$OUT"
want_has 'an unknown sha: says which one' 'is not a commit in this repository' "$OUT"

pplan "$P" "$B"
want_has 'a good --before: no fallback note' 'range   ' "$OUT"
want_not 'a good --before: says nothing about falling back' 'fell back' "$OUT"

# ── the interface ──────────────────────────────────────────────────────────────
hd "the publisher's interface"

bash "$PUB" --help >/dev/null 2>&1;  want_rc 'publish --help exits 0' 0 $?
bash "$PUB" >/dev/null 2>&1;         want_rc 'publish with no arguments exits 2' 2 $?
bash "$PUB" nonsense >/dev/null 2>&1; want_rc 'publish with an unknown command exits 2' 2 $?
bash "$PUB" plan --repo "$WORK" --before HEAD >/dev/null 2>&1
want_rc 'publish outside a repository exits 2' 2 $?
P=$(mkpub i1); rm -f "$P/$SVREL"
bash "$PUB" plan --repo "$P" --before HEAD >/dev/null 2>&1
want_rc 'publish where the repo has no skill-version.sh exits 2' 2 $?
bash "$PUB" plan --repo "$P" --nonsense x >/dev/null 2>&1
want_rc 'publish with an unknown option exits 2' 2 $?

# ── ─────────────────────────────────────────────────────────────────────────────
printf '\n%d passed, %d failed\n\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
