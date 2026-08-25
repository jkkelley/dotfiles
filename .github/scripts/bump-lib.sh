#!/usr/bin/env bash
#
# bump-lib.sh - the resolution the two halves of the pipeline share.
#
# bump-gate.sh reads a pull request and refuses it. publish.sh reads the merge
# that pull request became and allocates the number. They have to reach the same
# answer about the same change, and the only way to guarantee that is for them
# to run the same code rather than two copies of it that agree today.
#
# What lives here is everything that is a pure function of a tree and a range:
#
#   skills_in        which skill directories a range touched
#   skill_exists     whether a name is a skill in this tree right now
#   registry_version what the registry currently claims for a skill
#   next_version     the arithmetic
#   title_level      the conventional-commit fallback, and its type map
#   level_rank       so two levels for one skill can be compared
#
# What does not live here is anything that decides *policy*: the gate's refusals
# and the publisher's per-commit attribution differ on purpose, because a pull
# request is one statement of intent and a range of merges is several.
#
# Sourced, never executed. It sets no shell options - bump-gate.sh deliberately
# runs without -e so it can collect every failure, and a library that turned it
# on would change the behaviour of the file that sourced it.

# Callers set REPO before calling anything here. resolve_repo fills it in from
# the working directory when it was not passed.
REPO=${REPO:-}

resolve_repo() {
  if [[ -z $REPO ]]; then
    REPO=$(git rev-parse --show-toplevel 2>/dev/null) \
      || die "not a git repository, and no --repo given"
  fi
  REPO=$(cd "$REPO" && pwd) || die "no such directory: $REPO"
  [[ -d $REPO/.git ]] || git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 \
    || die "not a git repository: $REPO"
}

# The range is passed in rather than assumed, because the two callers need
# different ones. The gate compares three dots against the merge base, so a skill
# someone else changed on main is not a skill that branch has to account for. The
# publisher compares two dots from the commit main was at before the push, so
# every commit the push actually delivered is in scope and nothing else is.
paths_in() {
  local range=$1
  shift
  git -C "$REPO" diff --name-only "$range" -- "$@"
}

# Every skill directory a range touched. registry.json sits directly under
# claude/skills/ and has no directory component, so the pattern excludes it
# without a special case.
skills_in() {
  local range=$1 p n
  while IFS= read -r p; do
    [[ $p == claude/skills/*/* ]] || continue
    n=${p#claude/skills/}
    n=${n%%/*}
    [[ -n $n ]] || continue
    printf '%s\n' "$n"
  done < <(paths_in "$range" claude/skills/) | sort -u
}

# A skill deleted by the change under inspection is not a skill that needs a
# bump: the publisher regenerates the registry from the tree, and a row with
# nothing behind it goes away on its own.
skill_exists() { [[ -f "$REPO/claude/skills/$1/SKILL.md" ]]; }

# The registry is one entry per line and the skills block ends before the tools
# block. Scoping the lookup to that range costs one sed and removes the only way
# a tool name could ever be mistaken for a skill's version.
registry_version() {
  local name=$1 line
  line=$(sed -n '/^  "skills": {/,/^  },/p' "$REPO/claude/skills/registry.json" 2>/dev/null \
         | grep -m1 -E "^[[:space:]]*\"$name\":") || return 1
  [[ $line =~ \"version\":[[:space:]]*\"([0-9]+\.[0-9]+\.[0-9]+)\" ]] || return 1
  printf '%s' "${BASH_REMATCH[1]}"
}

next_version() {
  local cur=$1 level=$2 ma mi pa
  IFS=. read -r ma mi pa <<< "$cur"
  case $level in
    major) ma=$((ma + 1)); mi=0; pa=0 ;;
    minor) mi=$((mi + 1)); pa=0 ;;
    patch) pa=$((pa + 1)) ;;
    *) return 1 ;;
  esac
  printf '%s.%s.%s' "$ma" "$mi" "$pa"
}

# So that two commits in one push, each asking for a different level on the same
# skill, resolve to the larger rather than to whichever landed last. Ordering by
# arrival would make the answer depend on the order two unrelated pull requests
# happened to be merged in, which is not a property anyone can reason about.
level_rank() {
  case $1 in
    major) printf '3' ;;
    minor) printf '2' ;;
    patch) printf '1' ;;
    *)     printf '0' ;;
  esac
}

# Trailers beat the title, always. The title is the fallback the spec describes
# for "anything changed but not listed", which makes it the implicit source and
# the trailer the explicit one, and an explicit statement that loses to an
# inferred one is not a statement. The case this gives up on is a breaking title
# with a patch trailer, and that is the case the printed table exists for: the
# override is visible in the check output before anyone reaches the merge button.
title_level() {
  local title=$1 body=$2 ttype bang breaking
  breaking=$(grep -cE '^BREAKING[ -]CHANGE:' <<< "$body")
  if [[ $title =~ ^([a-zA-Z]+)(\([^\)]*\))?(!)?:[[:space:]] ]]; then
    ttype=${BASH_REMATCH[1]}
    ttype=$(tr '[:upper:]' '[:lower:]' <<< "$ttype")
    bang=${BASH_REMATCH[3]}
  else
    return 1
  fi
  if [[ -n $bang || $breaking -gt 0 ]]; then printf 'major'; return 0; fi
  case $ttype in
    feat) printf 'minor' ;;
    # Rule 16's own table puts wording, script bugfixes, doc clarifications and
    # test-only changes at patch. These types are that list, so mapping them is
    # reading the rule rather than guessing at one. revert is deliberately
    # absent: reverting a feature is not a patch, and the level depends on what
    # was reverted, so it is left to a trailer.
    fix|docs|chore|refactor|test|style|perf|ci|build) printf 'patch' ;;
    *) return 1 ;;
  esac
}
