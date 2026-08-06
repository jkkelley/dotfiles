#!/usr/bin/env bash
#
# work-order.sh - deterministic ticketing for agent handoff.
#
# Every mutation refuses rather than guesses. The agent supplies an identifier;
# this script establishes the facts. That is the whole design: `close` calls gh
# to find out whether a PR merged instead of believing what it was told.
#
# work-order-version: 1

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/wo.sh
source "$SCRIPT_DIR/lib/wo.sh"

readonly TEMPLATE="$SKILL_DIR/references/ticket.tmpl"

usage() {
  cat <<'EOF'
work-order.sh - deterministic tickets for agent handoff

Usage:
  work-order.sh new     [--project DIR] --title T --type T --problem T --out T...
                        [--in T...] [--ac T...] [--test-plan T] [--surface T...]
                        [--priority p0|p1|p2|p3] [--assume T...] [--question T...]
                        [--from-figma DIR] [--frames GLOB] [--json]
  work-order.sh approve [--project DIR] --id WO-... [--no-lavish --reason T] [--json]
  work-order.sh start   [--project DIR] --id WO-... [--json]
  work-order.sh submit  [--project DIR] --id WO-... --pr N [--json]
  work-order.sh done    [--project DIR] --id WO-... [--json]
  work-order.sh close   [--project DIR] --id WO-... [--dry-run] [--json]
  work-order.sh reopen  [--project DIR] --id WO-... --reason T [--json]
  work-order.sh verify  [--project DIR] [--id WO-...] [--json]
  work-order.sh resync  [--project DIR] --id WO-... [--json]
  work-order.sh show    [--project DIR] --id WO-... [--json]
  work-order.sh list    [--project DIR] [--status S] [--json]

Lifecycle:
  draft --approve--> ready --start--> in-progress --submit--> in-review
        --done--> done --close--> done (archived, merge SHA recorded)
  Any of ready/in-progress/in-review may become `stale` via verify; resync returns it.

Authority:
  With wireframe evidence, build-plan.json leads and the frozen block is
  derived from it. Without, the ticket itself is the source of truth.

new:
  --title      one line
  --type       feature | bug | chore | spike
  --problem    what is broken or missing, and for whom
  --out        a non-goal. REQUIRED and repeatable - an empty Out list is what
               lets an agent wander, so it is a validation error, not a default.
  --in         an in-scope item, repeatable
  --ac         a human acceptance criterion, repeatable, phrased as a check
  --from-figma DIR containing wireframe-brief.json and build-plan.json. Both are
               snapshotted into work-orders/evidence/<ID>/ so a later wireframe
               run cannot destroy this ticket's evidence.
  --frames     glob over build_order, e.g. 'wf/checkout-cart/*'. Default: all.

close:
  --dry-run    print the phase plan and every assertion result, execute nothing.

Common:
  --project DIR   project directory (default: .)
  --json          machine-readable output on stdout
  --lock-timeout SECONDS
  --help

Exit codes: 0 ok, 2 usage, 3 validation/illegal-transition, 4 io/missing-dep,
            5 lock timeout, 6 id not found
EOF
}

(($#)) || { usage; exit "$PS_USAGE"; }
case ${1-} in --help | -h) usage; exit "$PS_OK" ;; esac

command="$1"; shift

title=""; type=""; problem=""; test_plan=""; priority="p2"
id=""; pr=""; reason=""; status_filter=""; from_figma=""; frames_glob="*"
no_lavish=0; dry_run=0
declare -a in_items=() out_items=() ac_items=() surfaces=() assumptions=() questions=()

while (($#)); do
  case $1 in
    --project) PS_PROJECT="${2-}"; shift 2 ;;
    --json) PS_JSON=1; shift ;;
    --lock-timeout) PS_LOCK_TIMEOUT="${2-}"; shift 2 ;;
    --title) title="${2-}"; shift 2 ;;
    --type) type="${2-}"; shift 2 ;;
    --problem) problem="${2-}"; shift 2 ;;
    --priority) priority="${2-}"; shift 2 ;;
    --test-plan) test_plan="${2-}"; shift 2 ;;
    --in) in_items+=("${2-}"); shift 2 ;;
    --out) out_items+=("${2-}"); shift 2 ;;
    --ac) ac_items+=("${2-}"); shift 2 ;;
    --surface) surfaces+=("${2-}"); shift 2 ;;
    --assume) assumptions+=("${2-}"); shift 2 ;;
    --question) questions+=("${2-}"); shift 2 ;;
    --from-figma) from_figma="${2-}"; shift 2 ;;
    --frames) frames_glob="${2-}"; shift 2 ;;
    --id) id="${2-}"; shift 2 ;;
    --pr) pr="${2-}"; shift 2 ;;
    --reason) reason="${2-}"; shift 2 ;;
    --status) status_filter="${2-}"; shift 2 ;;
    --no-lavish) no_lavish=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    --help | -h) usage; exit "$PS_OK" ;;
    *) PS_JSON=0; ps_die "$PS_USAGE" "unknown_flag" "unknown flag: $1 (try --help)" ;;
  esac
done

[[ $PS_LOCK_TIMEOUT =~ ^[0-9]+$ ]] || \
  ps_die "$PS_USAGE" "bad_lock_timeout" "--lock-timeout must be a whole number of seconds"

project=$(ps_resolve_project "${PS_PROJECT:-.}")
root=$(wo_root "$project")

require_id() {
  ps_require_value id "$id"
  wo_id_valid "$id" || ps_die "$PS_USAGE" "bad_id_format" \
    "--id must look like WO-20260805-3f2a (got: $id)"
}

# ---------------------------------------------------------------------------
# Rendering. The template owns the section skeleton; the script fills the
# lists. An agent hand-writing ticket markdown is the failure this removes.
# ---------------------------------------------------------------------------

bullets() {
  local prefix="$1"; shift
  if (($# == 0)); then printf '%s\n' "_none_"; return; fi
  local x
  for x in "$@"; do printf '%s%s\n' "$prefix" "$(ps_sanitize_line "$x")"; done
}

render_body() {
  local criteria="$1" outcome="$2"
  local line token
  while IFS= read -r line; do
    case $line in
      '%%'*'%%')
        token="${line//%/}"
        case $token in
          ID) printf '%s\n' "$id" ;;
          TITLE) printf '%s\n' "$(ps_sanitize_line "$title")" ;;
          PROBLEM) printf '%s\n' "$(ps_sanitize_line "$problem")" ;;
          IN) bullets "- " "${in_items[@]+"${in_items[@]}"}" ;;
          OUT) bullets "- " "${out_items[@]+"${out_items[@]}"}" ;;
          CRITERIA) printf '%s\n' "$criteria" ;;
          TEST_PLAN)
            if [[ -n $test_plan ]]; then
              printf '```sh\n%s\n```\n' "$(ps_sanitize_line "$test_plan")"
            else
              printf '%s\n' "_none recorded - Rule 14 says this runs in a container_"
            fi ;;
          ASSUMPTIONS) bullets "1. " "${assumptions[@]+"${assumptions[@]}"}" ;;
          OPEN_QUESTIONS) bullets "- [ ] " "${questions[@]+"${questions[@]}"}" ;;
          OUTCOME) printf '%s\n' "$outcome" ;;
          *) printf '%s\n' "$line" ;;
        esac ;;
      *) printf '%s\n' "$line" ;;
    esac
  done <"$TEMPLATE"
}

# ---------------------------------------------------------------------------
# new
# ---------------------------------------------------------------------------

cmd_new() {
  wo_require_jq
  ps_require_value title "$title"
  ps_require_value type "$type"
  ps_require_enum type "$type" "${WO_TYPES[@]}"
  ps_require_enum priority "$priority" "${WO_PRIORITIES[@]}"
  ps_require_value problem "$problem"
  ((${#out_items[@]})) || ps_die "$PS_VALIDATION" "no_non_goals" \
    "at least one --out is required: a work-order with no non-goals lets an agent wander"

  [[ -w $project ]] || ps_die "$PS_IO" "dir_not_writable" "not writable: $project"

  local stamp today slug
  stamp=$(ps_now); today=$(ps_today)
  id=$(wo_mint_id "$title" "$stamp")
  slug=$(wo_slug "$title")
  [[ -n $slug ]] || ps_die "$PS_VALIDATION" "empty_slug" "--title produced an empty slug"

  # Everything that can refuse must refuse before the first mkdir. A rejected run
  # leaves no trace - not even an empty work-orders/ directory.
  local ev_source="human" ev_json='null' criteria="" frozen_frames=""
  local brief="" plan=""
  if [[ -n $from_figma ]]; then
    brief="$from_figma/wireframe-brief.json"; plan="$from_figma/build-plan.json"
    [[ -r $brief ]] || ps_die "$PS_IO" "brief_missing" "no wireframe-brief.json in $from_figma"
    [[ -r $plan ]] || ps_die "$PS_IO" "plan_missing" "no build-plan.json in $from_figma"
    jq -e . "$plan" >/dev/null 2>&1 || ps_die "$PS_VALIDATION" "plan_invalid" "build-plan.json is not valid JSON"

    frozen_frames=$(wo_plan_frames "$plan" "$frames_glob")
    [[ -n $frozen_frames ]] || ps_die "$PS_VALIDATION" "no_frames_matched" \
      "--frames '$frames_glob' matched nothing in build_order"
  fi

  mkdir -p "$root" || ps_die "$PS_IO" "mkdir_failed" "cannot create $root"
  local file="$root/${id}-${slug}.md"
  [[ -e $file ]] && ps_die "$PS_VALIDATION" "id_collision" "$file already exists"

  # --- evidence -----------------------------------------------------------
  if [[ -n $from_figma ]]; then
    # Snapshot, so a later wireframe run cannot destroy this ticket's evidence.
    local evdir="$root/evidence/$id"
    mkdir -p "$evdir" || ps_die "$PS_IO" "mkdir_failed" "cannot create $evdir"
    cp -- "$brief" "$evdir/wireframe-brief.json"
    cp -- "$plan" "$evdir/build-plan.json"

    ev_source="wireframe"
    local checksum identity
    checksum=$(wo_plan_checksum "$evdir/build-plan.json" "$frames_glob")
    identity=$(wo_plan_identity "$evdir/build-plan.json")
    ev_json=$(jq -n \
      --arg src "$from_figma" --arg ck "$checksum" --arg idn "$identity" \
      --arg glob "$frames_glob" \
      --argjson frames "$(printf '%s\n' "$frozen_frames" | jq -R . | jq -s .)" \
      --argjson dw "$(jq '.done_when // null' "$evdir/build-plan.json")" \
      --argjson ng "$(jq '.non_goals // []' "$evdir/build-plan.json")" \
      '{source:"wireframe", origin:$src, snapshot:("evidence/" + "'"$id"'"),
        frame_checksum:$ck, identity:$idn, frames_glob:$glob, frames:$frames,
        done_when:$dw, non_goals:$ng}')

    # Frozen block: wireframe-derived criteria, checksummed. Nothing between the
    # markers may be edited by hand - verify recomputes it.
    criteria=$(
      printf '%s %s -->\n' "$WO_FROZEN_START" "checksum=$checksum"
      local f n=0
      while IFS= read -r f; do
        n=$((n + 1))
        printf -- '- [ ] `AC-%d` *(wireframe)* frame `%s` renders as planned\n' "$n" "$f"
      done <<<"$frozen_frames"
      local dw
      dw=$(jq -r '.done_when // empty' "$evdir/build-plan.json")
      if [[ -n $dw ]]; then
        n=$((n + 1))
        printf -- '- [ ] `AC-%d` *(wireframe)* %s\n' "$n" "$dw"
      fi
      printf '%s\n' "$WO_FROZEN_END"
    )
    # Wireframe non_goals are authoritative, so they join the Out list.
    local ng
    while IFS= read -r ng; do [[ -n $ng ]] && out_items+=("$ng"); done < <(
      jq -r '.non_goals[]? // empty' "$evdir/build-plan.json")
  fi

  local hn=0 a
  for a in "${ac_items[@]+"${ac_items[@]}"}"; do
    hn=$((hn + 1))
    criteria+=$'\n'"- [ ] \`AC-H${hn}\` *(human)* $(ps_sanitize_line "$a")"
  done
  [[ -n $criteria ]] || criteria="_none - approve will refuse until at least one exists_"

  # --- assemble -----------------------------------------------------------
  local fm tmp
  fm=$(jq -n \
    --arg id "$id" --arg slug "$slug" --arg title "$title" --arg type "$type" \
    --arg pri "$priority" --arg now "$stamp" --arg today "$today" \
    --argjson ev "$ev_json" \
    --argjson surfaces "$(printf '%s\n' "${surfaces[@]+"${surfaces[@]}"}" | grep -v '^$' | jq -R . | jq -s .)" \
    '{id:$id, slug:$slug, title:$title, type:$type, status:"draft", priority:$pri,
      created:$today, updated:$today, created_at:$now,
      branch:null, pr:null, merge_sha:null, closed:null,
      approval:null, evidence:$ev, surfaces:$surfaces, depends_on:[], blocks:[]}')

  tmp=$(ps_tempfile)
  {
    printf -- '---\n%s\n---\n\n' "$fm"
    render_body "$criteria" "_Written by \`work-order close\`. Empty until then._"
  } >"$tmp"
  ps_atomic_install "$tmp" "$file"
  reindex

  if ((PS_JSON)); then
    printf '{"ok":true,"id":"%s","file":%s,"status":"draft","evidence":"%s"}\n' \
      "$id" "$(ps_json_string "$file")" "$ev_source"
  else
    ps_info "created $file (status: draft, evidence: $ev_source)"
    printf '%s\n' "$id"
  fi
}

# ---------------------------------------------------------------------------
# transitions
# ---------------------------------------------------------------------------

cmd_approve() {
  wo_require_jq; require_id
  local file; file=$(wo_find "$project" "$id")
  wo_require_status "$file" draft

  local body; body=$(wo_body "$file")
  if printf '%s' "$body" | grep -q '^- \[ \] '; then
    if printf '%s' "$body" | awk '/^## Open questions/{f=1;next} /^## /{f=0} f' | grep -q '^- \[ \] '; then
      ps_die "$PS_VALIDATION" "open_questions" \
        "unchecked Open questions block approval - resolve them or delete them"
    fi
  fi
  printf '%s' "$body" | grep -q '`AC-' || ps_die "$PS_VALIDATION" "no_criteria" \
    "ticket has no acceptance criteria"

  local approval
  if ((no_lavish)); then
    ps_require_value reason "$reason"
    approval=$(jq -n --arg r "$reason" --arg d "$(ps_today)" \
      '{via:"override", reason:$r, at:$d}')
    ps_warn "approved without Lavish review: $reason"
  else
    command -v lavish-axi >/dev/null 2>&1 || ps_die "$PS_IO" "lavish_missing" \
      "lavish-axi not found. Review in Lavish, or pass --no-lavish --reason '...' to record the exception."
    approval=$(jq -n --arg d "$(ps_today)" '{via:"lavish", at:$d}')
  fi

  wo_fm_set "$file" \
    '.status="ready" | .updated=$d | .approval=$a' \
    --arg d "$(ps_today)" --argjson a "$approval"
  reindex
  emit_ok "$id" ready "$file"
}

cmd_start() {
  wo_require_jq; require_id
  local file; file=$(wo_find "$project" "$id")
  # Ticket state before environment: telling someone "not a git repo" when the
  # real problem is "this is still a draft" sends them down the wrong path.
  wo_require_status "$file" ready
  wo_require_git "$project"

  git -C "$project" diff --quiet && git -C "$project" diff --cached --quiet \
    || ps_die "$PS_VALIDATION" "dirty_tree" "working tree is dirty - commit or stash first"

  local slug branch; slug=$(wo_field "$file" '.slug')
  branch="feat/${slug}"
  git -C "$project" rev-parse --verify "$branch" >/dev/null 2>&1 \
    && ps_die "$PS_VALIDATION" "branch_exists" "branch $branch already exists"

  git -C "$project" checkout -b "$branch" >/dev/null 2>&1 \
    || ps_die "$PS_IO" "checkout_failed" "could not create branch $branch"

  wo_fm_set "$file" '.status="in-progress" | .branch=$b | .updated=$d' \
    --arg b "$branch" --arg d "$(ps_today)"
  reindex
  emit_ok "$id" in-progress "$file"
}

cmd_submit() {
  wo_require_jq; wo_require_gh; require_id
  ps_require_value pr "$pr"
  [[ $pr =~ ^[0-9]+$ ]] || ps_die "$PS_USAGE" "bad_pr" "--pr must be a number (got: $pr)"
  local file; file=$(wo_find "$project" "$id")
  wo_require_status "$file" in-progress

  gh pr view "$pr" --json number >/dev/null 2>&1 \
    || ps_die "$PS_NOTFOUND" "pr_not_found" "gh cannot see PR #$pr"

  wo_fm_set "$file" '.status="in-review" | .pr=($p|tonumber) | .updated=$d' \
    --arg p "$pr" --arg d "$(ps_today)"
  reindex
  emit_ok "$id" in-review "$file"
}

# `done` is written on the feature branch at context-compaction time, before the
# PR lands. That is a deliberate call: it means a rejected PR leaves a ticket
# claiming done, which is what `reopen` exists to correct.
cmd_done() {
  wo_require_jq; require_id
  local file; file=$(wo_find "$project" "$id")
  wo_require_status "$file" in-review

  local body; body=$(wo_body "$file")
  printf '%s' "$body" | awk '/^## Acceptance criteria/{f=1;next} /^## /{f=0} f' \
    | grep -q '^- \[ \] ' && ps_die "$PS_VALIDATION" "unchecked_criteria" \
    "acceptance criteria still unchecked - tick them or say why in Outcome"

  wo_fm_set "$file" '.status="done" | .updated=$d' --arg d "$(ps_today)"
  reindex
  ps_info "status: done. CONTEXT_STATE.md should be updated in this same commit."
  emit_ok "$id" done "$file"
}

cmd_reopen() {
  wo_require_jq; require_id
  ps_require_value reason "$reason"
  local file; file=$(wo_find "$project" "$id")
  wo_require_status "$file" done
  wo_is_archived "$file" && ps_die "$PS_VALIDATION" "already_archived" \
    "$id is archived; reopening a closed-out ticket is a new work-order"

  wo_fm_set "$file" \
    '.status="in-progress" | .merge_sha=null | .closed=null | .updated=$d
     | .reopened=((.reopened // []) + [{at:$d, reason:$r}])' \
    --arg d "$(ps_today)" --arg r "$reason"
  reindex
  emit_ok "$id" in-progress "$file"
}

# ---------------------------------------------------------------------------
# close - the only command that touches git history. Every fact is discovered,
# never accepted from the caller.
# ---------------------------------------------------------------------------

cmd_close() {
  wo_require_jq; wo_require_git "$project"; wo_require_gh; require_id
  local file; file=$(wo_find "$project" "$id")
  wo_require_status "$file" done
  wo_is_archived "$file" && ps_die "$PS_VALIDATION" "already_archived" "$id is already archived"

  local branch pr_num state sha
  branch=$(wo_field "$file" '.branch')
  pr_num=$(wo_field "$file" '.pr')
  [[ -n $pr_num ]] || ps_die "$PS_VALIDATION" "no_pr" "$id has no PR recorded - run submit first"

  state=$(gh pr view "$pr_num" --json state -q .state 2>/dev/null) \
    || ps_die "$PS_IO" "gh_failed" "gh could not read PR #$pr_num"
  sha=$(gh pr view "$pr_num" --json mergeCommit -q '.mergeCommit.oid // ""' 2>/dev/null)

  # The whole point of this command.
  [[ $state == MERGED ]] || ps_die "$PS_VALIDATION" "pr_not_merged" \
    "PR #$pr_num reports state=$state, not MERGED - refusing to delete anything"
  [[ -n $sha ]] || ps_die "$PS_VALIDATION" "no_merge_commit" \
    "PR #$pr_num is MERGED but has no merge commit - refusing"

  local year archive_dir dest
  year=$(ps_today); year="${year%%-*}"
  archive_dir="$root/archive/$year"
  dest="$archive_dir/$(basename -- "$file")"

  if ((dry_run)); then
    cat <<EOF
DRY RUN - nothing will be executed

  ticket    $id  ($file)
  branch    ${branch:-<none recorded>}
  PR        #$pr_num
  gh state  $state          <- must be MERGED
  merge sha $sha

  phase 1   git fetch --prune; checkout main; merge --ff-only origin/main
            git branch -D ${branch:-<none>}; git push origin --delete ${branch:-<none>}
  phase 2   branch close-out/$id from main
            backfill merge_sha + closed; archive to ${archive_dir#"$project"/}/
            commit; push; open PR; merge
  phase 3   repeat phase 1 for close-out/$id

  assertions passed: status=done, not archived, PR MERGED, merge commit present
EOF
    exit "$PS_OK"
  fi

  git -C "$project" diff --quiet && git -C "$project" diff --cached --quiet \
    || ps_die "$PS_VALIDATION" "dirty_tree" "working tree is dirty - refusing"

  # phase 1
  git -C "$project" fetch origin --prune >/dev/null 2>&1
  git -C "$project" checkout main >/dev/null 2>&1 \
    || ps_die "$PS_IO" "checkout_failed" "cannot check out main"
  git -C "$project" merge --ff-only origin/main >/dev/null 2>&1 \
    || ps_die "$PS_VALIDATION" "main_diverged" "main cannot fast-forward to origin/main"

  # Checking out main swapped the ticket for main's copy of it. The status
  # verified before the checkout says nothing about the file we now hold, and a
  # PR that gh calls MERGED whose ticket never reached done on main means the
  # two disagree. Refuse rather than stamp a merge SHA onto the wrong state.
  file=$(wo_find "$project" "$id")
  wo_require_status "$file" done
  if [[ -n $branch ]]; then
    git -C "$project" branch -D "$branch" >/dev/null 2>&1 || true
    git -C "$project" push origin --delete "$branch" >/dev/null 2>&1 || true
  fi

  # phase 2
  local cob="close-out/$id"
  git -C "$project" checkout -b "$cob" >/dev/null 2>&1 \
    || ps_die "$PS_IO" "checkout_failed" "cannot create $cob"
  mkdir -p "$archive_dir"
  wo_fm_set "$file" '.merge_sha=$s | .closed=$d | .updated=$d' \
    --arg s "$sha" --arg d "$(ps_today)"
  git -C "$project" mv "$file" "$dest" >/dev/null 2>&1 || mv -- "$file" "$dest"
  reindex
  git -C "$project" add -A "$root" >/dev/null 2>&1
  git -C "$project" commit -m "chore($id): close out and archive" >/dev/null 2>&1 \
    || ps_die "$PS_IO" "commit_failed" "nothing to commit for $id"
  git -C "$project" push -u origin "$cob" >/dev/null 2>&1 \
    || ps_die "$PS_IO" "push_failed" "cannot push $cob"

  emit_ok "$id" done "$dest"
}

# ---------------------------------------------------------------------------
# verify / resync
# ---------------------------------------------------------------------------

verify_one() {
  local file="$1" src ck idn snap cur_ck cur_idn glob
  src=$(wo_field "$file" '.evidence.source')
  [[ $src == wireframe ]] || { printf 'ok       %s (no wireframe evidence)\n' "$(basename "$file")"; return 0; }

  ck=$(wo_field "$file" '.evidence.frame_checksum')
  idn=$(wo_field "$file" '.evidence.identity')
  glob=$(wo_field "$file" '.evidence.frames_glob')
  snap="$root/$(wo_field "$file" '.evidence.snapshot')/build-plan.json"
  [[ -r $snap ]] || { printf 'MISSING  %s (snapshot gone: %s)\n' "$(basename "$file")" "$snap"; return 1; }

  cur_ck=$(wo_plan_checksum "$snap" "$glob")
  [[ $cur_ck == "$ck" ]] || { printf 'TAMPERED %s (snapshot no longer matches recorded checksum)\n' "$(basename "$file")"; return 1; }

  # Compare against the live brief only if it is still the same feature.
  local origin; origin=$(wo_field "$file" '.evidence.origin')
  local live="$origin/build-plan.json"
  if [[ -r $live ]]; then
    cur_idn=$(wo_plan_identity "$live")
    if [[ $cur_idn != "$idn" ]]; then
      printf 'REPLACED %s (%s now holds a different brief: %s)\n' "$(basename "$file")" "$origin" "$cur_idn"
      return 2
    fi
    if [[ "$(wo_plan_checksum "$live" "$glob")" != "$ck" ]]; then
      printf 'STALE    %s (wireframe rebuilt)\n' "$(basename "$file")"
      return 3
    fi
  fi
  printf 'ok       %s\n' "$(basename "$file")"
}

cmd_verify() {
  wo_require_jq
  [[ -d $root ]] || ps_die "$PS_NOTFOUND" "no_work_orders" "no $WO_DIR_NAME/ in $project"
  local rc=0 f
  if [[ -n $id ]]; then
    require_id
    f=$(wo_find "$project" "$id")
    verify_one "$f" || rc=$?
    if ((rc == 3)); then
      wo_fm_set "$f" '.status="stale" | .updated=$d' --arg d "$(ps_today)"
      reindex
    fi
    exit $((rc ? PS_VALIDATION : PS_OK))
  fi
  while IFS= read -r f; do
    verify_one "$f" || rc=$PS_VALIDATION
  done < <(find "$root" -type f -name 'WO-*.md' | sort)
  exit "$rc"
}

cmd_resync() {
  wo_require_jq; require_id
  local file; file=$(wo_find "$project" "$id")
  wo_require_status "$file" stale

  local origin glob snap idn
  origin=$(wo_field "$file" '.evidence.origin')
  glob=$(wo_field "$file" '.evidence.frames_glob')
  idn=$(wo_field "$file" '.evidence.identity')
  local live="$origin/build-plan.json"
  [[ -r $live ]] || ps_die "$PS_IO" "plan_missing" "cannot re-read $live"
  [[ "$(wo_plan_identity "$live")" == "$idn" ]] || ps_die "$PS_VALIDATION" "identity_changed" \
    "$origin now holds a different brief - that is a replacement, not a resync"

  snap="$root/$(wo_field "$file" '.evidence.snapshot')"
  cp -- "$live" "$snap/build-plan.json"
  [[ -r "$origin/wireframe-brief.json" ]] && cp -- "$origin/wireframe-brief.json" "$snap/wireframe-brief.json"

  local ck; ck=$(wo_plan_checksum "$snap/build-plan.json" "$glob")
  wo_fm_set "$file" \
    '.status="ready" | .updated=$d | .evidence.frame_checksum=$c
     | .evidence.frames=($f|split("\n")|map(select(length>0)))' \
    --arg d "$(ps_today)" --arg c "$ck" --arg f "$(wo_plan_frames "$snap/build-plan.json" "$glob")"
  reindex
  ps_warn "frozen block regenerated - re-read the acceptance criteria before working"
  emit_ok "$id" ready "$file"
}

# ---------------------------------------------------------------------------
# read-only
# ---------------------------------------------------------------------------

cmd_show() {
  wo_require_jq; require_id
  local file; file=$(wo_find "$project" "$id")
  if ((PS_JSON)); then wo_fm "$file"; else cat -- "$file"; fi
}

cmd_list() {
  wo_require_jq
  [[ -d $root ]] || ps_die "$PS_NOTFOUND" "no_work_orders" "no $WO_DIR_NAME/ in $project"
  [[ -n $status_filter ]] && ps_require_enum status "$status_filter" "${WO_STATUSES[@]}"
  local f rows=()
  while IFS= read -r f; do
    local s; s=$(wo_field "$f" '.status')
    [[ -n $status_filter && $s != "$status_filter" ]] && continue
    rows+=("$f")
  done < <(find "$root" -type f -name 'WO-*.md' | sort)

  if ((PS_JSON)); then
    printf '['
    local first=1
    for f in "${rows[@]+"${rows[@]}"}"; do
      ((first)) || printf ','
      first=0
      wo_fm "$f" | jq -c '{id,title,status,type,priority,pr,merge_sha}'
    done
    printf ']\n'
  else
    for f in "${rows[@]+"${rows[@]}"}"; do
      printf '%-24s %-12s %s\n' "$(wo_field "$f" '.id')" "$(wo_field "$f" '.status')" "$(wo_field "$f" '.title')"
    done
  fi
}

# INDEX.md is generated, never edited. It is what keeps an archived ticket
# findable after close moves it out of the active directory.
reindex() {
  [[ -d $root ]] || return 0
  local tmp f; tmp=$(ps_tempfile)
  {
    printf '# Work orders\n\nGenerated by `work-order.sh`. Do not edit.\n\n'
    printf '| ID | status | type | title | path |\n|---|---|---|---|---|\n'
    while IFS= read -r f; do
      printf '| %s | %s | %s | %s | %s |\n' \
        "$(wo_field "$f" '.id')" "$(wo_field "$f" '.status')" \
        "$(wo_field "$f" '.type')" "$(wo_field "$f" '.title')" "${f#"$root"/}"
    done < <(find "$root" -type f -name 'WO-*.md' | sort)
  } >"$tmp"
  ps_atomic_install "$tmp" "$root/INDEX.md"
}

emit_ok() {
  if ((PS_JSON)); then
    printf '{"ok":true,"id":"%s","status":"%s","file":%s}\n' "$1" "$2" "$(ps_json_string "$3")"
  else
    ps_info "$1 -> $2"
  fi
}

case $command in
  new) cmd_new ;;
  approve) cmd_approve ;;
  start) cmd_start ;;
  submit) cmd_submit ;;
  done) cmd_done ;;
  close) cmd_close ;;
  reopen) cmd_reopen ;;
  verify) cmd_verify ;;
  resync) cmd_resync ;;
  show) cmd_show ;;
  list) cmd_list ;;
  *) ps_die "$PS_USAGE" "unknown_command" \
       "unknown command: $command (new|approve|start|submit|done|close|reopen|verify|resync|show|list)" ;;
esac
