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

# The read-only notice is no longer verify's business. It is asserted present
# nowhere and absent nowhere, which is the only state that holds while the
# repository is mid-rollout and some SKILL.md files carry it and some do not.
# A skill stripped of its notice is therefore an ordinary edit, and the only
# thing verify has to say about it is that the registry went stale.
cp "$SKILLS/alpha/SKILL.md" "$WORK/alpha-ro.bak"
grep -v 'This copy is read-only.' "$WORK/alpha-ro.bak" > "$SKILLS/alpha/SKILL.md"
bash "$SV" verify > "$WORK/verify-noro.out" 2>&1
check "verify says nothing about a missing read-only notice" \
  "$(neg grep -qi 'read-only' "$WORK/verify-noro.out")"
check "a stripped notice is reported as ordinary drift" \
  "$(grep -q '^drifted .*alpha' "$WORK/verify-noro.out"; echo $?)"

cp "$WORK/alpha-ro.bak" "$SKILLS/alpha/SKILL.md"
expect_rc "verify passes once the file is restored" 0 bash "$SV" verify

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

# ── 5. verify --structure ──────────────────────────────────────────────────────
# The PR gate. Under merge-time allocation a skill PR edits a skill and leaves
# the registry alone, which plain verify calls drift and is right to. The whole
# point of the split is that one state, so it is tested as one pair: --structure
# exits 0 and plain verify exits non-zero on the same branch.
#
# The fixture is a real git repository with the skills under claude/, because
# every assertion here is about a diff, and because paths anchored to the repo
# root rather than to the skills directory is the way this silently reads the
# wrong files.
hd "verify --structure"
GITFIX="$WORK/gitrepo"
GSKILLS="$GITFIX/claude/skills"
rm -rf "$GITFIX"
mkdir -p "$GSKILLS"
git init -q -b main "$GITFIX"
git -C "$GITFIX" config user.email tester@example.com
git -C "$GITFIX" config user.name Tester
mkfixture "$GSKILLS"
gsv() { SKILL_VERSION_SKILLS_DIR="$GSKILLS" bash "$SV" "$@"; }
gsv init >/dev/null 2>&1
git -C "$GITFIX" add -A >/dev/null 2>&1
git -C "$GITFIX" commit -q -m "skills, versioned and in sync"

# An unknown flag that is silently ignored is the failure that looks like a
# passing gate: --structure does nothing, the strict path runs, and the exit
# code is right for the wrong reason. These three prove it is parsed at all.
expect_rc "verify --help"                    0 gsv verify --help
expect_rc "verify --structure --help"        0 gsv verify --structure --help
expect_rc "verify REJECTS an unknown flag"   1 gsv verify --frobnicate
expect_rc "--base without --structure rejected" 1 gsv verify --base main

expect_rc "--structure passes on a clean checkout" 0 gsv verify --structure
expect_rc "verify passes on the same checkout"     0 gsv verify

# The case that motivated the split.
git -C "$GITFIX" checkout -q -b feat/edit-a-skill
printf 'echo more\n' >> "$GSKILLS/alpha/scripts/run.sh"
git -C "$GITFIX" add -A >/dev/null 2>&1
git -C "$GITFIX" commit -q -m "edit a skill, leave the registry alone"
expect_rc "--structure PASSES with a skill edited and the registry untouched" 0 gsv verify --structure
expect_rc "plain verify FAILS on that same branch"                            1 gsv verify

expect_rc "--structure takes an explicit --base" 0 gsv verify --structure --base main
expect_rc "--base rejects a ref that does not exist" 1 gsv verify --structure --base no/such/ref

# A hand-edited version:, uncommitted. Uncommitted on purpose - the diff runs
# against the working tree, so the gate answers before the commit exists.
sed 's/^version: 2.3.4/version: 2.3.5/' "$GSKILLS/beta/SKILL.md" > "$WORK/beta.tmp"
cat "$WORK/beta.tmp" > "$GSKILLS/beta/SKILL.md"
expect_rc "--structure FAILS on a hand-edited version:" 1 gsv verify --structure
gsv verify --structure > "$WORK/structure-version.out" 2>&1
check "--structure names the file whose version: moved" \
  "$(grep -q '^version: edited in this diff .*beta/SKILL.md' "$WORK/structure-version.out"; echo $?)"
git -C "$GITFIX" checkout -q -- .

# A registry.json in the diff at all. CI writes it at merge; a branch never does.
printf '\n' >> "$GSKILLS/registry.json"
expect_rc "--structure FAILS when registry.json is in the diff" 1 gsv verify --structure
gsv verify --structure > "$WORK/structure-registry.out" 2>&1
check "--structure names registry.json" \
  "$(grep -q '^registry.json edited in this diff' "$WORK/structure-registry.out"; echo $?)"
git -C "$GITFIX" checkout -q -- .

# Everything plain verify asserts about versions, --structure asserts too - for
# a skill the registry already carries. Stripping beta's line is a hand-edit of
# a published skill twice over: the version is gone from the tree, and its
# removal is a - in the diff. The first of those is what answers, because the
# version loop runs before diff_check is reached.
grep -v '^version: 2.3.4' "$GSKILLS/beta/SKILL.md" > "$WORK/beta.tmp"
cat "$WORK/beta.tmp" > "$GSKILLS/beta/SKILL.md"
expect_rc "--structure FAILS when a registered skill loses its version" 1 gsv verify --structure
gsv verify --structure > "$WORK/structure-stripped.out" 2>&1
check "--structure names the registered skill it found unversioned" \
  "$(grep -qE '^unversioned +beta' "$WORK/structure-stripped.out"; echo $?)"
git -C "$GITFIX" checkout -q -- .
expect_rc "--structure passes again once the version is back" 0 gsv verify --structure

# Outside a repository there is no diff to take, and a gate with nothing to
# check must say so rather than exit 0 having checked nothing.
SKILL_VERSION_SKILLS_DIR="$SKILLS" bash "$SV" verify --structure > "$WORK/structure-nogit.out" 2>&1
STRUCT_NOGIT_RC=$?
check "--structure FAILS outside a git repository" "$([[ $STRUCT_NOGIT_RC -ne 0 ]]; echo $?)"
check "--structure says it is not a git repository" \
  "$(grep -q 'not a git repository' "$WORK/structure-nogit.out"; echo $?)"

# ── 5b. a skill the registry has never carried ─────────────────────────────────
# Under merge-time allocation a new skill arrives with no version: line, because
# the publisher stamps it at 1.0.0 with init after the merge. Both spellings of
# that change used to be refused: written without a line, the version loop
# reported it unversioned before diff_check was reached; written with one,
# diff_check read the + as a hand-edit. Adding a skill was the one change the
# pipeline could not land, so both spellings are asserted green here.
hd "verify --structure: a new skill"

mkdir -p "$GSKILLS/gamma"
printf -- '---\nname: gamma\ndescription: New on this branch, no version yet.\n---\n\n# Gamma\n' \
  > "$GSKILLS/gamma/SKILL.md"
git -C "$GITFIX" add -A >/dev/null 2>&1
git -C "$GITFIX" commit -q -m "add a brand new skill"

expect_rc "--structure PASSES on a new skill with no version:" 0 gsv verify --structure
gsv verify --structure > "$WORK/structure-new.out" 2>&1
check "--structure names it as new" \
  "$(grep -qE '^new +gamma' "$WORK/structure-new.out"; echo $?)"
check "--structure does not also call it unversioned" \
  "$(neg grep -qE '^unversioned +gamma' "$WORK/structure-new.out")"

# The non-goal, and the one a fix here can silently break. Plain verify runs on
# main after the publisher, where an unversioned skill means init did not run.
expect_rc "plain verify STILL FAILS on that same unversioned skill" 1 gsv verify
gsv verify > "$WORK/verify-new.out" 2>&1
check "plain verify still names it unversioned" \
  "$(grep -qE '^unversioned +gamma' "$WORK/verify-new.out"; echo $?)"

# The other spelling: the author wrote the line by hand. Uncommitted, so the
# assertion covers the working tree the gate actually reads.
sed 's/^description: .*/&\nversion: 1.0.0/' "$GSKILLS/gamma/SKILL.md" > "$WORK/gamma.tmp"
cat "$WORK/gamma.tmp" > "$GSKILLS/gamma/SKILL.md"
check "the hand-written version: really is a + in the diff" \
  "$(git -C "$GITFIX" diff -U0 main -- claude/skills/gamma/SKILL.md | grep -q '^+version:'; echo $?)"
expect_rc "--structure PASSES on a new skill carrying a hand-written version:" 0 \
  gsv verify --structure

# The exemption is per skill and not a switch the branch flips: a registered
# skill is still held to the rule on the same tree that carries an exempt one.
sed 's/^version: 2.3.4/version: 9.9.9/' "$GSKILLS/beta/SKILL.md" > "$WORK/beta.tmp"
cat "$WORK/beta.tmp" > "$GSKILLS/beta/SKILL.md"
expect_rc "--structure still FAILS on a registered skill's version, beside a new one" 1 \
  gsv verify --structure
gsv verify --structure > "$WORK/structure-mixed.out" 2>&1
check "the refusal names beta" \
  "$(grep -q '^version: edited in this diff .*beta/SKILL.md' "$WORK/structure-mixed.out"; echo $?)"
check "the refusal says nothing about gamma" \
  "$(neg grep -q 'gamma' "$WORK/structure-mixed.out")"
git -C "$GITFIX" checkout -q -- .

# ── 5c. a renamed, and a deleted, skill directory ──────────────────────────────
# Why this is p1 rather than a backlog item: WO-20260824-238b renames
# skill-versioning to skill-registry. A rename has two halves and git pairs them
# only when it can - how much else the commit changed decides that - so both are
# exercised rather than one and an assumption.
hd "verify --structure: a renamed skill"

rm -rf "$GSKILLS/gamma"
git -C "$GITFIX" add -A >/dev/null 2>&1
git -C "$GITFIX" commit -q -m "drop the new skill again"
expect_rc "--structure passes on the restored tree" 0 gsv verify --structure

# The new half. beta-renamed is a name main has never seen, so every line of its
# SKILL.md including version: 2.3.4 arrives as a +.
git -C "$GITFIX" mv claude/skills/beta claude/skills/beta-renamed >/dev/null 2>&1
git -C "$GITFIX" commit -q -m "rename a skill directory"
expect_rc "--structure PASSES on a renamed skill directory" 0 gsv verify --structure
gsv verify --structure > "$WORK/structure-rename.out" 2>&1
check "the renamed directory reads as new" \
  "$(grep -qE '^new +beta-renamed' "$WORK/structure-rename.out"; echo $?)"

# The old half, on its own, where there is nothing for git to pair it with: the
# registered skill beta is simply gone, and its version: line leaves as a -.
git -C "$GITFIX" rm -rq claude/skills/beta-renamed
git -C "$GITFIX" commit -q -m "delete the skill outright"
check "the deleted SKILL.md is in the diff under its registered name" \
  "$(git -C "$GITFIX" diff --name-only main -- claude/skills/ \
     | grep -qx 'claude/skills/beta/SKILL.md'; echo $?)"
check "and it takes a -version: into that diff" \
  "$(git -C "$GITFIX" diff -U0 main -- claude/skills/beta/SKILL.md | grep -q '^-version:'; echo $?)"
expect_rc "--structure PASSES when a registered skill is deleted" 0 gsv verify --structure

# ── 6. registry schema 2 ───────────────────────────────────────────────────────
# type, requires, the tools block, and a schema mismatch reported as its own
# failure. None of this needs git or a network - it is a pure function of a
# directory - so the plain fixture is used rather than section 5's git repo.
hd "registry schema 2"
mkfixture "$SKILLS"
export SKILL_VERSION_SKILLS_DIR="$SKILLS"
bash "$SV" init >/dev/null 2>&1

check "the registry declares schema 2" \
  "$(grep -q '"schema": 2,' "$SKILLS/registry.json"; echo $?)"
check "every entry carries a derived type" \
  "$(grep -q '"alpha": {.*"type": "skill"' "$SKILLS/registry.json"; echo $?)"
check "a skill with no requires: renders an empty array" \
  "$(grep -q '"alpha": {.*"requires": \[\] }' "$SKILLS/registry.json"; echo $?)"
check "the registry is still valid JSON to a line-wise reader (one entry per line)" \
  "$([[ "$(grep -c '^    "' "$SKILLS/registry.json")" -eq 2 ]]; echo $?)"

# requires is read from the leading fenced block only, exactly as version: is.
# The prose case is the reason read_version was written that way and it has to
# hold here too, or a SKILL.md documenting the key acquires a dependency on it.
sed 's/^version: 2.3.4/version: 2.3.4\nrequires: alpha/' "$SKILLS/beta/SKILL.md" > "$WORK/beta.tmp"
cat "$WORK/beta.tmp" > "$SKILLS/beta/SKILL.md"
bash "$SV" bump beta --patch >/dev/null 2>&1
check "requires: in frontmatter reaches the registry" \
  "$(grep -q '"beta": {.*"requires": \["alpha"\] }' "$SKILLS/registry.json"; echo $?)"
expect_rc "verify passes when a requires: resolves" 0 bash "$SV" verify

printf '\nrequires: not-a-real-skill\n' >> "$SKILLS/beta/SKILL.md"
bash "$SV" bump beta --patch >/dev/null 2>&1
check "a requires: in the body is prose and is ignored" \
  "$(neg grep -q 'not-a-real-skill' "$SKILLS/registry.json")"
expect_rc "verify still passes with a requires: in the body" 0 bash "$SV" verify

# The typo. This is what earns the key its keep: caught at the gate rather than
# on some project's first sync.
mkfixture "$SKILLS"
sed 's/^version: 2.3.4/version: 2.3.4\nrequires: work-ordr/' "$SKILLS/beta/SKILL.md" > "$WORK/beta.tmp"
cat "$WORK/beta.tmp" > "$SKILLS/beta/SKILL.md"
bash "$SV" init >/dev/null 2>&1
expect_rc "verify FAILS on a requires: that resolves to nothing" 1 bash "$SV" verify
bash "$SV" verify > "$WORK/verify-req.out" 2>&1
check "verify names both the skill and the missing dependency" \
  "$(grep -q '^unresolved requires   beta -> work-ordr' "$WORK/verify-req.out"; echo $?)"
check "an unresolved requires: does not tell you to run init" \
  "$(neg grep -q "run '.*' init" "$WORK/verify-req.out")"

# --structure asserts it too. A typo'd dependency is a property of the tree, not
# of the registry, so the PR gate is the right place to reject it.
expect_rc "--structure FAILS on a requires: that resolves to nothing" 1 \
  bash "$SV" verify --structure

# A comma-separated list, which is the whole reason it is not a YAML list.
mkfixture "$SKILLS"
mkdir -p "$SKILLS/delta"
printf -- '---\nname: delta\ndescription: Fixture.\nversion: 1.0.0\n---\n\n# Delta\n' > "$SKILLS/delta/SKILL.md"
sed 's/^version: 2.3.4/version: 2.3.4\nrequires: alpha, delta/' "$SKILLS/beta/SKILL.md" > "$WORK/beta.tmp"
cat "$WORK/beta.tmp" > "$SKILLS/beta/SKILL.md"
bash "$SV" init >/dev/null 2>&1
check "a comma-separated requires: renders both names, in declared order" \
  "$(grep -q '"beta": {.*"requires": \["alpha", "delta"\] }' "$SKILLS/registry.json"; echo $?)"
expect_rc "verify passes when every name in the list resolves" 0 bash "$SV" verify

# ── 6b. the tools block ────────────────────────────────────────────────────────
# Option A: an entry is rendered only for a registered tool that exists. The
# empty case is the one that ships today, so it is asserted first and by name -
# an empty block that quietly became a missing key would break every consumer.
hd "registry tools block"
mkfixture "$SKILLS"
rm -rf "$WORK/tools"
bash "$SV" init >/dev/null 2>&1
check "an absent claude/tools/ renders an empty tools block, not a missing key" \
  "$(grep -qx '  "tools": {}' "$SKILLS/registry.json"; echo $?)"
check "no tool is invented when none is on disk" \
  "$(neg grep -q 'skill-sync' "$SKILLS/registry.json")"

# The populated case. Proved against a fixture tool rather than the real one,
# because the real one does not exist yet and hashing a placeholder is precisely
# what this design refuses to do.
mkdir -p "$WORK/tools/partials"
printf '<!-- skill-tool-version: 2.1.0 -->\nnotice for {{SKILL_NAME}}\n' \
  > "$WORK/tools/partials/read-only-notice.md.tmpl"
bash "$SV" init >/dev/null 2>&1
check "a tool that exists gets an entry with its marker version" \
  "$(grep -q '"read-only-notice": { "version": "2.1.0"' "$SKILLS/registry.json"; echo $?)"
check "the entry carries the file's own sha256" \
  "$(grep -q "\"read-only-notice\": {.*\"sha256\": \"$(sha256sum "$WORK/tools/partials/read-only-notice.md.tmpl" | cut -d' ' -f1)\"" "$SKILLS/registry.json"; echo $?)"
check "a registered tool still absent is skipped rather than stubbed" \
  "$(neg grep -q 'skill-sync' "$SKILLS/registry.json")"
expect_rc "verify passes with a populated tools block" 0 bash "$SV" verify

# A tool present but unversioned is a hard failure. Rendering it without a
# version would put an entry in the registry that no consumer could compare.
printf 'no marker here\n' > "$WORK/tools/skill-sync.sh"
expect_rc "verify FAILS when a tool carries no version marker" 1 bash "$SV" verify
bash "$SV" verify > "$WORK/verify-tool.out" 2>&1
check "the failure names the tool and the marker it wants" \
  "$(grep -q 'skill-sync.sh has no skill-tool-version: marker' "$WORK/verify-tool.out"; echo $?)"
rm -rf "$WORK/tools"

# The tools block is not the skills block, and the drift report's two loops must
# not confuse them. Both walk lines beginning with four spaces and a quote, and
# render_tools writes its entries at exactly that indent - so unscoped, every
# registered tool was named as a skill that does not exist, on every failing run.
hd "the drift report reads the skills block only"
mkdir -p "$WORK/tools/partials"
printf '<!-- skill-tool-version: 2.1.0 -->\nnotice for {{SKILL_NAME}}\n' \
  > "$WORK/tools/partials/read-only-notice.md.tmpl"
mkfixture "$SKILLS"
bash "$SV" init >/dev/null 2>&1
check "the fixture registry really does carry a populated tools block" \
  "$(grep -q '"read-only-notice": {' "$SKILLS/registry.json"; echo $?)"

# A genuine skill drift, with that tools block sitting on the same registry.
printf 'echo drift\n' >> "$SKILLS/alpha/scripts/run.sh"
expect_rc "verify FAILS on a skill drift beside a populated tools block" 1 bash "$SV" verify
bash "$SV" verify > "$WORK/verify-tools-scope.out" 2>&1
check "the drifted skill is still named" \
  "$(grep -q '^drifted .*alpha' "$WORK/verify-tools-scope.out"; echo $?)"
check "no tool is reported as a stale entry" \
  "$(neg grep -qE '^stale entry .*read-only-notice' "$WORK/verify-tools-scope.out")"
check "no tool is named anywhere in the failure" \
  "$(neg grep -q 'read-only-notice' "$WORK/verify-tools-scope.out")"

# The narrowing must not become a silencing. This is the assertion a careless
# fix breaks: a registry row whose skill directory is gone is still reported.
rm -rf "$SKILLS/beta"
bash "$SV" verify > "$WORK/verify-tools-stale.out" 2>&1
check "a genuinely stale skill entry is still named" \
  "$(grep -q '^stale entry .*beta' "$WORK/verify-tools-stale.out"; echo $?)"
check "and still no tool is named beside it" \
  "$(neg grep -q 'read-only-notice' "$WORK/verify-tools-stale.out")"

# A changed tool. It still fails verify, because the registry genuinely is
# stale - but it is not attributed to a skill, and no skill is blamed for it.
mkfixture "$SKILLS"
bash "$SV" init >/dev/null 2>&1
expect_rc "verify passes with every skill and the tool in sync" 0 bash "$SV" verify
printf 'a line the committed registry has not hashed\n' \
  >> "$WORK/tools/partials/read-only-notice.md.tmpl"
expect_rc "verify FAILS when a tool changes without its marker moving" 1 bash "$SV" verify
bash "$SV" verify > "$WORK/verify-tool-drift.out" 2>&1
check "a changed tool is NOT reported as a drifted skill" \
  "$(neg grep -qE '^drifted .*read-only-notice' "$WORK/verify-tool-drift.out")"
check "and no skill is falsely blamed for it" \
  "$(neg grep -qE '^(drifted|stale entry|not in registry)' "$WORK/verify-tool-drift.out")"
rm -rf "$WORK/tools"

# ── 6c. schema mismatch is not drift ───────────────────────────────────────────
# The failure this exists to prevent: a registry from an older generator reads as
# every skill having drifted at once, which names them all and explains none.
hd "schema mismatch"
mkfixture "$SKILLS"
bash "$SV" init >/dev/null 2>&1
expect_rc "verify passes before the schema is touched" 0 bash "$SV" verify

sed 's/"schema": 2,/"schema": 1,/' "$SKILLS/registry.json" > "$WORK/reg-old.json"
cat "$WORK/reg-old.json" > "$SKILLS/registry.json"
expect_rc "verify FAILS on a registry written to another schema" 1 bash "$SV" verify
bash "$SV" verify > "$WORK/verify-schema.out" 2>&1
check "verify reports it as a schema mismatch" \
  "$(grep -q '^schema mismatch: registry is schema 1, this generator writes schema 2' "$WORK/verify-schema.out"; echo $?)"
check "a schema mismatch does NOT report any skill as drifted" \
  "$(neg grep -q '^drifted' "$WORK/verify-schema.out")"
check "a schema mismatch does NOT report a stale entry" \
  "$(neg grep -q '^stale entry' "$WORK/verify-schema.out")"
check "the schema failure says how to rewrite the registry" \
  "$(grep -q "init    rewrite the registry" "$WORK/verify-schema.out"; echo $?)"

# A registry with no schema key at all is the same failure, not a crash.
grep -v '"schema"' "$SKILLS/registry.json" > "$WORK/reg-noschema.json"
cat "$WORK/reg-noschema.json" > "$SKILLS/registry.json"
expect_rc "verify FAILS on a registry with no schema key" 1 bash "$SV" verify
bash "$SV" verify > "$WORK/verify-noschema.out" 2>&1
check "a missing schema key is reported as a mismatch, not as a crash" \
  "$(grep -q '^schema mismatch: registry is schema <none>' "$WORK/verify-noschema.out"; echo $?)"

bash "$SV" init >/dev/null 2>&1
expect_rc "init rewrites the registry to the current schema" 0 bash "$SV" verify

# ── 7. skill-update, inline ────────────────────────────────────────────────────
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

# ── 8. skill-update, standalone ────────────────────────────────────────────────
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

# ── 9. failure reporting ───────────────────────────────────────────────────────
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
