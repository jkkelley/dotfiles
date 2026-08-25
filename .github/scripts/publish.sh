#!/usr/bin/env bash
#
# publish.sh - the writing half of the pipeline, driven by
# .github/workflows/skill-publish.yml.
#
# A version is allocated here, on main, after the merge - at the first moment
# ordering is actually known. The pull request carried the intent and
# bump-gate.sh refused it if it did not hold up; this reads the same intent out
# of the commits that intent became, and turns it into a number.
#
#   plan    resolve every skill the push delivered to a level and print the
#           table. Writes nothing. Exit 1 if anything is unresolved
#   apply   plan, then init, then bump, then verify, then commit. The push
#           itself belongs to the workflow, because it is the only part that
#           needs a token
#
# It lives in a script rather than inside the YAML for the same reason the gate
# does: a shell block in a workflow can only be tested by pushing, and this one
# writes to main. .github/scripts/testing/run-tests.sh drives every branch below
# against a fixture repository in a container, including the refusals.
#
# ── the range, and why it is not the one the plan wrote down ───────────────────
#
# The implementation plan says `git diff <before>..<after>` and `git log -1`.
# Both are wrong once two pull requests merge back to back, and the reason is
# render_registry:
#
#   skill-version.sh bump <one skill>
#     -> writes that skill's version: line
#     -> regenerates the WHOLE registry from the tree
#
# The regeneration re-hashes every skill, including ones this run did not bump.
# So a run that checks out main carrying two unpublished skills and bumps only
# the one its own <before>..<after> covers writes the *other* skill's new content
# hash into the registry under its *old* version number. verify then passes, the
# next run finds nothing to do, and that skill's change ships to every consuming
# project as a version they already have. Silent, permanent, and invisible.
#
# So the range is <before>..HEAD, with HEAD being the checked-out main. It covers
# every commit the batch delivered, not only the push that triggered this run,
# and a run therefore bumps everything it is about to re-hash. Levels come from
# every commit in that range rather than from the last one, each commit
# attributed its own trailers and its own title.
#
# That leaves double-counting as the mirror risk - run 2 of a batch sees run 1's
# commits in its range too - and the loop guard is what answers it. verify green
# means the registry already matches the tree, which means the batch was already
# published, so there is nothing to do and the run exits 0 before it reads a
# single trailer. The guard is load-bearing for correctness, not only for cost.
#
# No -e. Every failure is collected and reported together, for the same reason
# the gate does it: a run that reports one problem, gets fixed, and then reports
# the next one has cost two merges to say what one could have said.
set -uo pipefail

SELF=$(basename "${BASH_SOURCE[0]}")
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

die() { printf '%s: %s\n' "$SELF" "$1" >&2; exit 2; }

# shellcheck source=.github/scripts/bump-lib.sh
. "$HERE/bump-lib.sh"

# The trailer this script stamps on its own commits, and the one it skips when
# it reads a range back. Without it, run 2 of a batch reads run 1's commit,
# finds a chore(skills): title, maps it to patch, and bumps every skill that
# commit touched a second time. The loop guard normally exits before that can
# happen; this is the belt to its braces, and it costs one line.
MARKER='Skill-Publish'

# E2.11 renames skill-versioning to skill-registry. This path moves with it.
SKILL_VERSION_REL='claude/skills/skill-versioning/scripts/skill-version.sh'

# Who the commit is by. Overridable so the fixture suite can commit as itself
# rather than inheriting a bot identity that means nothing in a scratch repo.
# The numeric local-part is GitHub's own published id for github-actions[bot];
# it is what attaches the commit to the bot account rather than to a person.
PUB_NAME=${SKILL_PUBLISH_NAME:-github-actions[bot]}
PUB_EMAIL=${SKILL_PUBLISH_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}

usage() {
  cat <<EOF
$SELF plan  --before <ref> [--repo <dir>]
$SELF apply --before <ref> [--repo <dir>]

  plan   Resolve every skill the range delivered to a level and print the
         table. Writes nothing. Exit 1 if any level is unresolvable.

  apply  The same resolution, then skill-version.sh init, then one bump per
         skill, then verify, then a commit. Exit 0 having done nothing when
         verify was already green. The push belongs to the workflow.

--before is github.event.before: the commit main was at before this push. The
range read is <before>..HEAD, so a batch of merges is published in one run.
EOF
}

BEFORE=""
RANGE=""
RANGE_NOTE=""

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --before)  BEFORE=${2:-}; shift 2 ;;
      --repo)    REPO=${2:-}; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *)         usage >&2; die "unknown option: $1" ;;
    esac
  done
  resolve_repo
  [[ -f "$REPO/$SKILL_VERSION_REL" ]] || die "no $SKILL_VERSION_REL in $REPO"
}

sv() { bash "$REPO/$SKILL_VERSION_REL" "$@"; }

# github.event.before is forty zeroes on a branch's first push, and it names a
# commit that no longer exists after a force-push. Neither is a state this
# repository's main is expected to reach, so the fallback is the narrowest one
# that is still correct - the single commit at the tip - and it says out loud
# that it took it.
determine_range() {
  if [[ -n $BEFORE && ! $BEFORE =~ ^0+$ ]]; then
    if git -C "$REPO" rev-parse --verify -q "$BEFORE^{commit}" >/dev/null; then
      RANGE="$BEFORE..HEAD"
      return 0
    fi
    RANGE_NOTE="--before ($BEFORE) is not a commit in this repository"
  else
    RANGE_NOTE="--before was empty or all zeroes"
  fi
  git -C "$REPO" rev-parse --verify -q 'HEAD~1^{commit}' >/dev/null \
    || die "$RANGE_NOTE, and HEAD has no parent to fall back to"
  RANGE='HEAD~1..HEAD'
  RANGE_NOTE="$RANGE_NOTE; fell back to HEAD~1..HEAD"
}

# ── resolution ─────────────────────────────────────────────────────────────────

declare -A LEVEL=()
declare -A SOURCE=()
declare -a EXISTING=()
declare -a FRESH=()
declare -a ERRORS=()
declare -a WARNINGS=()
declare -a SEEN=()

# A merge commit's diff is empty unless git is told which parent to compare
# against, and a root commit has none. This repository is squash-only so every
# commit on main has exactly one parent, but a publisher that silently sees no
# changed files is a publisher that silently bumps nothing.
commit_paths() {
  local c=$1 n
  n=$(git -C "$REPO" rev-list --parents -n1 "$c" | wc -w)
  if (( n <= 2 )); then
    git -C "$REPO" diff-tree -r --no-commit-id --name-only --root "$c"
  else
    git -C "$REPO" diff --name-only "$c^1" "$c"
  fi
}

commit_skills() {
  local c=$1 p n
  while IFS= read -r p; do
    [[ $p == claude/skills/*/* ]] || continue
    n=${p#claude/skills/}
    n=${n%%/*}
    [[ -n $n ]] || continue
    printf '%s\n' "$n"
  done < <(commit_paths "$c") | sort -u
}

in_list() { # needle, then the list
  local needle=$1 x
  shift
  for x in "$@"; do [[ $x == "$needle" ]] && return 0; done
  return 1
}

record() { # skill level source - highest level wins
  local s=$1 level=$2 src=$3
  if [[ -z ${LEVEL[$s]:-} ]] || (( $(level_rank "$level") > $(level_rank "${LEVEL[$s]}") )); then
    LEVEL[$s]=$level
    SOURCE[$s]=$src
  fi
}

note() { # a skill this range touched, filed by whether the registry knows it
  local s=$1
  if registry_version "$s" >/dev/null 2>&1; then
    in_list "$s" ${EXISTING[@]+"${EXISTING[@]}"} || EXISTING+=("$s")
    return 0
  fi
  # Absence from the registry is unambiguous, so a new skill needs no trailer
  # and no title type: init stamps it at 1.0.0. Reported so the table still
  # accounts for it.
  in_list "$s" ${FRESH[@]+"${FRESH[@]}"} || FRESH+=("$s")
  return 1
}

# Attribution is per commit, not per range. A commit's own trailers and its own
# subject are what speak for the skills that commit changed, so a push carrying
# two merges resolves each of them the way the gate resolved it on its own pull
# request. Reading only the tip commit's message - which is what the plan
# described - would apply one pull request's level to another's change.
#
# It also means a commit this publisher wrote is skipped whole: its versions are
# already allocated, and its chore(skills): subject would otherwise map to patch
# and bump every skill it touched a second time.
collect() {
  local s c msg subject trailers line tmap tlev level src short mine

  for c in $(git -C "$REPO" rev-list --reverse "$RANGE"); do
    short=$(git -C "$REPO" rev-parse --short "$c")
    msg=$(git -C "$REPO" log -1 --format=%B "$c")
    subject=$(git -C "$REPO" log -1 --format=%s "$c")
    trailers=$(printf '%s\n' "$msg" | git -C "$REPO" interpret-trailers --parse 2>/dev/null)

    if grep -qE "^$MARKER:" <<< "$trailers"; then
      SEEN+=("$short  (this publisher's own commit, skipped)  $subject")
      continue
    fi
    SEEN+=("$short  $subject")

    # A flat string rather than an associative array, so the map is rebuilt per
    # commit without the scoping games a local -A inside a loop needs. Skill
    # names are [A-Za-z0-9._-]+, so a space is an unambiguous separator.
    tmap=' '
    while IFS= read -r line; do
      [[ $line == Bump:* ]] || continue
      line=${line#Bump:}
      line=${line# }
      if [[ ! $line =~ ^([A-Za-z0-9._-]+)=(major|minor|patch)$ ]]; then
        ERRORS+=("malformed trailer   $short   Bump: $line   (want Bump: <skill>=<major|minor|patch>)")
        continue
      fi
      tmap+="${BASH_REMATCH[1]}=${BASH_REMATCH[2]} "
    done <<< "$trailers"

    tlev=$(title_level "$subject" "$msg") || tlev=""

    # This commit's own skills, once, as a space-delimited set. Both the level
    # loop and the stray-trailer check read it, and a deleted skill is dropped
    # here: the registry is regenerated from the tree, so a row with nothing
    # behind it goes away without anyone bumping it.
    mine=' '
    while IFS= read -r s; do
      skill_exists "$s" || continue
      mine+="$s "
      note "$s" || continue
      if [[ $tmap == *" $s="* ]]; then
        level=${tmap#*" $s="}
        level=${level%% *}
        src=trailer
      elif [[ -n $tlev ]]; then
        level=$tlev
        src=title
      else
        ERRORS+=("unresolved          $s   in $short   \"$subject\"")
        ERRORS+=("                    no Bump: trailer for it, and no conventional type in that subject")
        continue
      fi
      record "$s" "$level" "$src"
    done < <(commit_skills "$c")

    # The gate refuses a trailer naming a skill the branch never touched, so one
    # arriving here means it was added after the gate ran, or pushed straight to
    # main. Reported rather than refused: the registry going stale is a worse
    # outcome than a trailer nobody acted on, and the line says which commit.
    local -a pairs=()
    read -ra pairs <<< "$tmap"
    for line in ${pairs[@]+"${pairs[@]}"}; do
      s=${line%%=*}
      [[ -n $s && $mine != *" $s "* ]] || continue
      WARNINGS+=("ignored trailer     $short   Bump: $line   (that commit changed no such skill)")
    done
  done
}

report() {
  local s cur next
  printf 'range   %s\n' "$RANGE"
  [[ -z $RANGE_NOTE ]] || printf 'note    %s\n' "$RANGE_NOTE"
  printf '\ncommits\n'
  if [[ ${#SEEN[@]} -eq 0 ]]; then
    printf '  none\n'
  else
    printf '  %s\n' "${SEEN[@]}"
  fi

  if [[ ${#EXISTING[@]} -eq 0 && ${#FRESH[@]} -eq 0 ]]; then
    printf '\nNo skill changed in this range. Nothing to allocate.\n'
  else
    printf '\n%-26s %-9s    %-9s %-6s %s\n' "skill" "current" "next" "level" "source"
    printf '%s\n' "$(printf '%.0s-' {1..78})"
    for s in ${EXISTING[@]+"${EXISTING[@]}"}; do
      cur=$(registry_version "$s")
      next=$(next_version "$cur" "${LEVEL[$s]:-}") || next="?"
      printf '%-26s %-9s -> %-9s %-6s %s\n' "$s" "$cur" "$next" "${LEVEL[$s]:-?}" "${SOURCE[$s]:-unresolved}"
    done
    for s in ${FRESH[@]+"${FRESH[@]}"}; do
      printf '%-26s %-9s -> %-9s %-6s %s\n' "$s" "-" "1.0.0" "new" "absent from the registry"
    done
  fi

  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    printf '\n'
    printf '%s\n' "${WARNINGS[@]}"
  fi
}

refuse() {
  printf '\n' >&2
  printf '%s\n' "${ERRORS[@]}" >&2
  cat >&2 <<EOF

Refusing, and nothing has been bumped.

A missing bump leaves the registry naming the version projects already have, so
they keep the skill they already had - stale, safe, and verify stays red on main
until someone fixes it. A guessed bump ships a breaking change to every project
as a patch. One of those is visible and harmless.

Fix it with a commit on main that states the level, or by reverting the merge:

  Bump: <skill>=major|minor|patch
EOF
}

# ── plan ───────────────────────────────────────────────────────────────────────

cmd_plan() {
  parse_args "$@"
  determine_range
  collect
  report
  if [[ ${#ERRORS[@]} -gt 0 ]]; then refuse; return 1; fi
  printf '\nNothing is written by plan. apply is what allocates these.\n'
  return 0
}

# ── apply ──────────────────────────────────────────────────────────────────────

cmd_apply() {
  parse_args "$@"

  # The loop guard, and it is free because verify is a pure check. Green means
  # the registry already matches every skill on disk, which means there is
  # nothing unpublished in the tree no matter what the range says. It is also
  # what stops the second run of a batch re-bumping what the first one already
  # did, so it comes before anything reads a trailer.
  local guard
  if guard=$(sv verify 2>&1); then
    printf '%s\n' "$guard"
    printf '\nverify is green on this tree: every skill is versioned and the registry\nmatches. Nothing to allocate.\n'
    return 0
  fi
  printf 'verify is red, so there is something to allocate:\n\n%s\n\n' "$guard"

  determine_range
  collect
  report
  if [[ ${#ERRORS[@]} -gt 0 ]]; then refuse; return 1; fi

  printf '\n── allocating ─────────────────────────────────────────────────────────────\n\n'

  # init before the bumps, always, and not only when a new skill arrived. It
  # stamps anything unversioned at 1.0.0 and regenerates the registry, which is
  # also the whole job when a push only deleted a skill: there is no version to
  # raise, and the stale row still has to go.
  sv init || { printf '%s: skill-version.sh init failed\n' "$SELF" >&2; return 1; }

  local s want got
  for s in ${EXISTING[@]+"${EXISTING[@]}"}; do
    want=$(next_version "$(registry_version "$s")" "${LEVEL[$s]}") \
      || { printf '%s: cannot compute the next version for %s\n' "$SELF" "$s" >&2; return 1; }
    sv bump "$s" "--${LEVEL[$s]}" \
      || { printf '%s: skill-version.sh bump %s failed\n' "$SELF" "$s" >&2; return 1; }
    # A command that reports success and did nothing is the failure this line
    # exists for. The version in the registry is read back rather than $? being
    # trusted, because $? is what a no-op also returns.
    got=$(registry_version "$s")
    [[ $got == "$want" ]] || {
      printf '%s: %s should be at %s and the registry says %s\n' "$SELF" "$s" "$want" "$got" >&2
      return 1
    }
  done

  printf '\n── verifying ──────────────────────────────────────────────────────────────\n\n'
  if ! sv verify; then
    cat >&2 <<EOF

verify is still red after allocating everything this range asked for. Something
on main changed a skill outside <before>..HEAD - a run that failed earlier, or a
push whose event this workflow never saw.

Nothing is committed. Fix it on main with an explicit bump; the next push will
find verify green and do nothing.
EOF
    return 1
  fi

  # Scoped to the skills tree on purpose. The publisher writes version: lines
  # and registry.json and nothing else, and a scoped add is the assertion of
  # that rather than a comment claiming it.
  git -C "$REPO" add -A -- claude/skills/ || return 1
  if git -C "$REPO" diff --cached --quiet; then
    printf '\nverify was red but no version moved. Nothing to commit.\n'
    return 0
  fi

  commit_message | git -C "$REPO" \
    -c "user.name=$PUB_NAME" -c "user.email=$PUB_EMAIL" \
    commit -q -F - || return 1

  printf '\n'
  git -C "$REPO" --no-pager log -1 --stat
  return 0
}

# Called after the bumps, so registry_version reads the number that was just
# allocated rather than the one it replaced.
commit_message() {
  local s now
  printf 'chore(skills): allocate versions on main\n\n'
  for s in ${EXISTING[@]+"${EXISTING[@]}"}; do
    now=$(registry_version "$s")
    printf -- '- %s -> %s (%s, from the %s)\n' "$s" "$now" "${LEVEL[$s]}" "${SOURCE[$s]}"
  done
  for s in ${FRESH[@]+"${FRESH[@]}"}; do
    printf -- '- %s -> 1.0.0 (new, absent from the registry)\n' "$s"
  done
  printf '\nAllocated by .github/workflows/skill-publish.yml over %s.\n' "$RANGE"
  printf 'skill-version.sh owns both formats; nothing here was written by hand.\n'
  printf '\n%s: true\n' "$MARKER"
}

# ── dispatch ───────────────────────────────────────────────────────────────────

(($#)) || { usage >&2; exit 2; }
case ${1-} in -h|--help) usage; exit 0 ;; esac
cmd=$1; shift
case $cmd in
  plan)  cmd_plan  "$@" ;;
  apply) cmd_apply "$@" ;;
  *)     usage >&2; die "unknown command: $cmd" ;;
esac
