#!/usr/bin/env bash
# name: merge.sh
# purpose: pr-flow node N4 backstop - squash-merge a PR whose head is green, post merged 200 once, 409 on conflict, clean up
# inputs: --pr N | --all, --repo DIR, --slug OWNER/NAME; env PR_FLOW_* (state, hold, line, ticket pattern, required check, slots)
# outputs: one outcome line per PR on stdout; records through records.sh
# writes-to: GitHub (merge, branch delete), the bus or records tree through records.sh, local branches of --repo
# cleanup: none of its own; the hold file is verify-main's, PR_FLOW_STATE is removed by make pr-flow-clean
#
# Ported from ~/projects/coq-jev-herdr-plugin line/bin/merge.sh at 4f7f44c (pr-process.md section 7, rule R1). The coq text below is
# kept; the PORT breadcrumb right after it lists every change, and every changed line carries "# port:".
#
# merge.sh (coq) - the merge as code (SPEC-17 s-inventory H11; ticket WO-20261013-f6ae). It squash-merges a pull request whose newest head has a
# test.passed 201 and a review.passed 201 on it, posts merged 200 with the merge sha so the merger seat can verify main, and posts
# merge.conflict 409 to the worker lane when the branch no longer merges cleanly. The decision is a function of records and the head,
# so no seat makes it.
#
#   merge.sh --pr N [--repo DIR] [--json]    one pull request
#   merge.sh --all  [--repo DIR] [--json]    one pass over every open pull request, lowest number first
# --repo DIR is the git checkout gate.sh compares heads in and gh runs from (default: the checkout this script is in).
# One line per pull request on stdout (--json: one JSON object per line: pr, ticket, outcome, detail).
#
# Outcomes and exit codes (--all exits 0 unless a gh call failed for good or the merge hold is on when the pass starts; a held or a conflicting
# pull request is a normal state in a pass):
#   merged           0  squash-merged; exactly one merged 200 posted, sha = the merge commit, pr, ticket, to merger. Then the cleanup, in this
#                       order: git push origin --delete BRANCH, treehouse return of the slot leased to the ticket (only when no live process
#                       but this script's is in it), git branch -D BRANCH from a detached HEAD. No checkout of main, no work-order.sh cleanup.
#                       A step that fails after three attempts, or a slot left leased for a foreign process, is named on the line and in ONE
#                       blocked 423 to the orchestrator; the exit stays 0, the merge stands (see post_merge_clean)
#   already-merged   0  the pull request is already merged; nothing posted, nothing merged
#   held             3  nothing is merged or posted: no review.passed 201, or the 201s name an older head, or gate.sh heads_match
#                       holds, or the pull request is closed, or its title names no ticket
#   held (merge hold) 3 the merge hold file exists (see "The merge hold" below): nothing is merged, whatever the pull request, and ONE
#                       blocked 423 to the orchestrator lane names the hold's reason (once per hold, not once per pass or per PR).
#                       --all prints one line, with PR 0, and exits 3 (the other held outcomes keep --all at 0)
#   conflict         5  merge.conflict 409 posted to the worker lane with the pull request and head (once per head; a rerun on
#                       the same head posts nothing)
#   failed           4  a gh call (or gate.sh) failed three times; ONE blocked 423 to the orchestrator lane, then the run stops
#   usage            2
# Records are read from the records tree under the state root (bin/state-root.sh), the tree gate.sh reads, and written through
# events/bin/event.sh. Knobs, for tests and a slow network: MERGE_RETRIES (attempts per gh call, default 3), MERGE_BACKOFF_SECONDS
# (sleep after attempt n is n times this, default 2).
#
# BREADCRUMB 2026-10-13 - WO-20261013-f6ae. What broke: factory/config/routes.json:12 hands every review.passed 201 to the merger seat
#   (roles/merger.json, a Haiku seat), and that seat ran `gh pr merge --squash` for one pull request at a time, about fifteen minutes
#   each on 2026-10-13 (owner 03:02Z, "I hate bottlenecks"), though the merge is mechanical: the heads either match the records or they
#   do not. Why this fix: the whole gate is already code (factory/bin/gate.sh heads_match and same-head), so this script is that gate
#   plus one gh call plus two records; the merger seat is left with the verify of main and with conflicts. Rejected: teaching route.sh
#   to merge (its header caps it at applying the table, and a merge is a side effect on GitHub, not a route) and a GitHub auto-merge
#   setting (it knows nothing of test.passed and review.passed records, which live in the state root and not in GitHub).
#   Choices that look arbitrary:
#   1. The decision reads the NEWEST review.passed 201 of the ticket, asks gate.sh same-head whether it names the head gh reports now,
#      and only then asks gate.sh when heads_match, which finds the test.passed. A head pushed after the review is therefore held, and
#      --match-head-commit makes GitHub refuse a head that moves between our read and the merge. Cost: a worker's closing commit that
#      changes a file outside events/ puts the pull request back through the tester, as gate.sh already documents.
#   2. A conflict is decided by gh's own `mergeable` field (CONFLICTING), read before the merge and again after a refused merge, never
#      by matching the refusal text: GitHub also refuses a clean branch for a branch rule, and that is a block for the orchestrator,
#      not a rebase for the worker. Cost: UNKNOWN (GitHub still computing) is tried, and a refusal with UNKNOWN is retried with backoff.
#   3. A merge refused because the pull request meanwhile became MERGED (a lost reply, or a second run) is a success: the merge sha is
#      read back and merged 200 is posted unless one already names this pull request and ticket. Cost: a second run racing the first
#      between its own merge and its own post can still post twice; there is no lock file, because a lock directory would be a new
#      artifact tree that needs its own README (AGENTS.md, Law: tooling in the repository). The dedupe read narrows the window to
#      milliseconds.
#   4. merge.conflict is posted once per (pull request, head): the patrol tick runs --all every minute and a conflicting pull request
#      would otherwise post a record a minute until the worker rebases. The rebase changes the head, which re-arms the post.
#   5. An already merged pull request posts nothing, even when no merged record exists for it (a crash between the merge and the post,
#      or a merge by hand). The ticket says "posts nothing twice" and healing from here would post for pull requests merged long
#      before this script. Cost: a failed post of merged 200 leaves no verify; the script then exits 4 and prints the exact merge sha
#      and the command to post it again, rather than staying silent.
#   6. --all stops at the first pull request whose gh call fails for good: a gh outage would otherwise post one blocked 423 per open
#      pull request. The next pass starts again from the lowest number; the outcome lines already printed stand.
# The merge hold (WO-20261013-2d35, cause l). What broke: on 2026-10-13 PR 94 was merged onto a red main because the hold on merges
#   was a ruling in prose, which no script read (record gsp29). verify-main.sh (WO-20261013-9bdd, cause j) now writes the hold as a
#   file, <run tree>/merge-hold.json, and removes it on a green verify of that sha or a later one; this script is the reader. Why this
#   fix: the file is the only thing every merge path shares, so refusing here stops the merger seat, the patrol tick and a hand run
#   alike, and nobody has to remember a sentence. Choices that look arbitrary:
#   1. The file existing is the hold, whatever it holds: a file jq cannot read still holds, with the reason "unreadable". Fail closed;
#      lifting is verify-main.sh's job and a hand `rm` of the file.
#   2. The hold is checked before any gh call (a held pass costs no API calls) and again right before `gh pr merge`, because a verify
#      can write the hold while a long --all pass is under way. Cost: the second check is a stat; there is still a window of
#      milliseconds between it and GitHub taking the merge, which only GitHub-side branch protection could close.
#   3. The 423 is deduped on its note (which carries the hold's sha) because the patrol tick runs --all every minute and a hold lasts
#      until main is green again; one 423 per minute would bury the orchestrator. Cost: a hold rewritten for the same sha with the same
#      reason posts nothing new, which is right: the orchestrator has that 423 already.
#   4. --all exits 3 under a hold, unlike every other held outcome: the ticket says the refusal is exit 3, and a pass that merged
#      nothing because main is red is not a normal state the patrol should read as success.
# BREADCRUMB 2026-10-16 - PORT, BR-20261016-merge-port, WO-20261016-a29e. What changed from coq, and why:
#   1. The gate is gate.sh ci-green (every check on the head green, the required one present) instead of review.passed 201 plus
#      heads_match. Owner, 2026-10-16 UTC: "automate that process, we dont need gates we need speed". No review record is read.
#   2. Records go through pr-flow/bin/records.sh (bus or coq's tree), and post-once is its --key ledger instead of a jq read of the
#      whole log: keys are 200/<slug>/<pr>, 409/<slug>/<pr>/<head>, 423/hold/<note>. Same once-per rules as coq choices 3, 4 and hold 3.
#   3. A title with no ticket is not held: the ticket is the first match of PR_FLOW_TICKET_RE in the title, then the body, else
#      PR-<n>. coq held it because the review record was keyed by ticket; with no review there is nothing to key, and holding would
#      park every dotfiles PR (conventional-commit titles).
#   4. --slug OWNER/NAME sets GH_REPO, so gh needs no cwd in a clone of that repository; the hold file and state live under
#      PR_FLOW_STATE (default ~/.local/state/zenith/pr-flow) instead of coq's state root; PR_FLOW_SLOTS=0 skips the treehouse return
#      for repositories with no slots (config cleanup.slots).
#   The merge-on-green Action is the primary merge (rule R6); this script is the sweep's backstop and merge-train's per-PR merge.
set -uo pipefail
export LC_ALL=C
HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
GIT_REPO=$(pwd); PR=""; ALL_FLAG=0; JSON=0; SLUG=""   # port: --repo defaults to the cwd, the script no longer lives in the repo it merges
SEAT=merge-script; RETRIES=${MERGE_RETRIES:-3}; BACKOFF=${MERGE_BACKOFF_SECONDS:-2}
die() { local c=$1; shift; printf 'merge: %s\n' "$*" >&2; exit "$c"; }
command -v jq >/dev/null || die 4 "jq is required"
command -v gh >/dev/null || die 4 "gh is required"
while [ $# -gt 0 ]; do case $1 in
  --pr) PR=${2:-}; shift 2 || die 2 "--pr needs a number";; --all) ALL_FLAG=1; shift;; --json) JSON=1; shift;;
  --repo) GIT_REPO=$(cd "${2:?--repo needs a directory}" && pwd) || die 4 "no such --repo"; shift 2;;
  --slug) SLUG=${2:?--slug needs OWNER/NAME}; shift 2;;   # port: gh's GH_REPO
  *) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2;; esac; done
if [ "$ALL_FLAG" = 1 ]; then [ -z "$PR" ] || die 2 "--pr and --all are exclusive"
else [[ $PR =~ ^[1-9][0-9]*$ ]] || die 2 "give --pr N (a pull request number) or --all"; fi
[[ $RETRIES =~ ^[1-9][0-9]*$ ]] || die 2 "MERGE_RETRIES must be a positive integer"; [[ $BACKOFF =~ ^[0-9]+$ ]] || die 2 "MERGE_BACKOFF_SECONDS must be a whole number"
EVENT=$HERE/records.sh; GATE=$HERE/gate.sh   # port: pr-flow's records writer and gate
[ -x "$EVENT" ] && [ -x "$GATE" ] || die 4 "records.sh or gate.sh is missing beside merge.sh"
[ -z "$SLUG" ] || export GH_REPO=$SLUG   # port
SLUG=${SLUG:-${GH_REPO:-}}; [ -n "$SLUG" ] || SLUG=$(cd "$GIT_REPO" && gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) || true
[[ $SLUG =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die 2 "give --slug OWNER/NAME (gh could not name the repository of --repo)"
STATE=${PR_FLOW_STATE:-$HOME/.local/state/zenith/pr-flow}; export PR_FLOW_STATE=$STATE   # port: state root
HOLD=${PR_FLOW_HOLD:-$STATE/merge-hold.json}
LINE=${PR_FLOW_LINE:-pr-flow}; TICKET_RE=${PR_FLOW_TICKET_RE:-'(WO-[0-9]{8}-[0-9a-f]{4})'}; REQUIRED=${PR_FLOW_REQUIRED_CHECK:-ci-ok}
ERRF=$(mktemp "${TMPDIR:-/tmp}/merge-err.XXXXXX") || die 4 "cannot make a temp file"; trap 'rm -f "$ERRF"' EXIT
BLOCKED_POSTED=0; GH_OUT=""; GH_ERR=""

# ---- output: one line per pull request ----
say() { # say PR TICKET OUTCOME DETAIL
  if [ "$JSON" = 1 ]; then jq -nc --argjson pr "$1" --arg t "$2" --arg o "$3" --arg d "$4" '{pr:$pr, ticket:(if $t=="" then null else $t end), outcome:$o, detail:$d}'
  else printf 'PR %s %s %s: %s\n' "$1" "${2:--}" "$3" "$4"; fi
}

# ---- gh with retries: GH_OUT is the last attempt's stdout, GH_ERR the tail of its stderr ----
nap() { sleep $(( BACKOFF * $1 )); }
gh_retry() { # gh_retry ARGS...: up to RETRIES attempts; 0 when one worked
  local n=1 rc
  while :; do
    GH_OUT=$(cd "$GIT_REPO" && gh "$@" 2>"$ERRF"); rc=$?; GH_ERR=$(tail -c 300 "$ERRF" | tr '\n' ' ')
    [ "$rc" -ne 0 ] || return 0
    [ "$n" -lt "$RETRIES" ] || return "$rc"
    nap "$n"; n=$((n + 1))
  done
}

# ---- records ----
post() { # post ARGS...: records.sh post, retried; 0 when written. port: --to is coq routing and is dropped; --line and --repo are added
  local n=1 rc a=()
  while [ $# -gt 0 ]; do case $1 in --to) shift 2;; *) a+=("$1"); shift;; esac; done
  while :; do
    "$EVENT" post --seat "$SEAT" --line "$LINE" --repo "$SLUG" "${a[@]}" >/dev/null 2>"$ERRF"; rc=$?
    [ "$rc" -ne 0 ] || return 0
    [ "$n" -lt "$RETRIES" ] || { GH_ERR=$(tail -c 300 "$ERRF" | tr '\n' ' '); return "$rc"; }
    nap "$n"; n=$((n + 1))
  done
}
# fail_io PR TICKET WHAT: three attempts are spent. One blocked 423 per run, to the orchestrator, then exit 4 with the reason on stderr.
fail_io() {
  local note="merge.sh gave up on PR $1: $3 ${GH_ERR}"; note=${note:0:240}
  if [ "$BLOCKED_POSTED" = 0 ]; then
    BLOCKED_POSTED=1
    local t=(--ticket "${2:-none}"); [ "$1" = 0 ] || t+=(--pr "$1")   # port: the record schema requires a ticket   # a failed `gh pr list` has no pull request
    post --code 423 --kind blocked --to orchestrator "${t[@]}" --note "$note" || printf 'merge: the blocked 423 for PR %s could not be posted either: %s\n' "$1" "$GH_ERR" >&2
  fi
  say "$1" "$2" failed "$3 ${GH_ERR}"; return 4
}

# ---- the merge hold ----
# hold_reason: while the hold file exists, sets HOLD_REASON and HOLD_SHA and returns 0; returns 1 when there is no hold. It sets globals
# and prints nothing, because a $(...) caller would lose HOLD_SHA to the subshell (found by merge-hold.sh: the 423 carried no sha).
hold_reason() {
  [ -e "$HOLD" ] || return 1
  HOLD_SHA=$(jq -r '.sha // empty' "$HOLD" 2>/dev/null)
  HOLD_REASON=$(jq -r '.reason // empty' "$HOLD" 2>/dev/null)
  : "${HOLD_REASON:=the merge hold file $HOLD exists and names no reason (unreadable or empty)}"
}
# post_hold REASON: the one blocked 423 per hold. REASON is trimmed so the note fits event.sh's 240 characters; the note is the dedupe key.
post_hold() {
  local note="merge.sh refuses to merge: $1"; note=${note:0:240}
  local s=(); [[ ${HOLD_SHA:-} =~ ^[0-9a-f]{7,40}$ ]] && s=(--sha "$HOLD_SHA")
  post --code 423 --kind blocked --to orchestrator --ticket hold "${s[@]}" --note "$note" --key "423/hold/$note" \
    || printf 'merge: the blocked 423 for the merge hold could not be posted: %s\n' "$GH_ERR" >&2
}
# refuse_on_hold PR TICKET: 0 when there is no hold; with a hold, posts the 423, says held and returns 3
refuse_on_hold() {
  hold_reason || return 0
  post_hold "$HOLD_REASON"
  say "$1" "$2" held "the merge hold is on: $HOLD_REASON"; return 3
}

# ---- one pull request: returns 0 merged or already merged, 3 held, 4 failed, 5 conflict ----
merge_sha() { # merge_sha PR: the merge commit of a merged pull request (waits for GitHub to fill it in), in MERGE_SHA
  local n=1
  MERGE_SHA=""
  while :; do
    if gh_retry pr view "$1" --json state,mergeCommit; then
      MERGE_SHA=$(jq -r 'select(.state == "MERGED") | .mergeCommit.oid // empty' <<<"$GH_OUT" 2>/dev/null)
      [[ $MERGE_SHA =~ ^[0-9a-f]{40}$ ]] && return 0
    else return 4; fi
    [ "$n" -lt "$RETRIES" ] || { GH_ERR="the merge commit of PR $1 never appeared"; return 4; }
    nap "$n"; n=$((n + 1))
  done
}
post_merged() { # post_merged PR TICKET HEAD MERGE_SHA: merged 200 once; MERGED_DETAIL is the words for the outcome line (do_pr says it, after the cleanup)
  if "$EVENT" seen --key "200/$SLUG/$1"; then   # port: the posted ledger, not a read of the log
    MERGED_DETAIL="merged 200 already posted; merge commit ${4:0:12}"; return 0
  fi
  if ! post --code 200 --kind merged --to merger --ticket "$2" --pr "$1" --sha "$4" --key "200/$SLUG/$1" --note "squash-merged PR $1 at head ${3:0:12}, merge commit ${4:0:12}"; then
    printf 'merge: PR %s IS MERGED (merge commit %s) but merged 200 could not be posted: %s\n  post it again: records.sh post --seat %s --line %s --repo %s --code 200 --kind merged --ticket %s --pr %s --sha %s --key 200/%s/%s\n' \
      "$1" "$4" "$GH_ERR" "$SEAT" "$LINE" "$SLUG" "$2" "$1" "$4" "$SLUG" "$1" >&2
    GH_ERR="PR merged as $4 but merged 200 was not posted"; fail_io "$1" "$2" "post"; return 4
  fi
  MERGED_DETAIL="merge commit ${4:0:12}, head ${3:0:12}"; return 0
}
post_conflict() { # post_conflict PR TICKET HEAD
  if "$EVENT" seen --key "409/$SLUG/$1/$3"; then   # port: the posted ledger
    say "$1" "$2" conflict "merge.conflict 409 already posted for head ${3:0:12}"; return 5
  fi
  post --code 409 --kind merge.conflict --to worker --ticket "$2" --pr "$1" --sha "$3" --key "409/$SLUG/$1/$3" --note "PR $1 no longer merges cleanly at head ${3:0:12}; merge main into the branch" \
    || { fail_io "$1" "$2" "post"; return 4; }
  say "$1" "$2" conflict "merge.conflict 409 posted to the worker lane for head ${3:0:12}"; return 5
}

# ---- the post-merge cleanup (WO-20261013-a18c, cause ag) ----
# retry_cmd CMD...: up to RETRIES attempts with the same backoff as gh; 0 when one worked, else GH_ERR holds the tail of the last stderr
retry_cmd() {
  local n=1 rc
  while :; do
    "$@" >/dev/null 2>"$ERRF"; rc=$?; GH_ERR=$(tail -c 300 "$ERRF" | tr '\n' ' ')
    [ "$rc" -ne 0 ] || return 0
    [ "$n" -ge "$RETRIES" ] && return "$rc"
    nap "$n"; n=$((n + 1))
  done
}
# safe_branch BRANCH: 0 when BRANCH may be deleted; never the default branch, main, master, HEAD, or a name git refuses
safe_branch() {
  local def; def=$(git -C "$GIT_REPO" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null); def=${def#origin/}
  case $1 in main|master|HEAD|"$def") return 1;; esac
  git -C "$GIT_REPO" check-ref-format --branch "$1" >/dev/null 2>&1
}
# delete_remote BRANCH: 0 when origin no longer has the branch (a branch already gone counts; ls-remote --exit-code answers 2 for no match)
delete_remote() {
  git -C "$GIT_REPO" push origin --delete "$1" && return 0
  git -C "$GIT_REPO" ls-remote --exit-code --heads origin "refs/heads/$1" >/dev/null 2>&1; [ $? -eq 2 ]
}
# delete_local BRANCH: from a detached HEAD; when --repo's own HEAD is the branch it is detached first (the branch is merged), main is never checked out
delete_local() {
  git -C "$GIT_REPO" show-ref --verify --quiet "refs/heads/$1" || return 0
  if [ "$(git -C "$GIT_REPO" symbolic-ref -q HEAD)" = "refs/heads/$1" ]; then git -C "$GIT_REPO" switch -q --detach || return 1; fi
  git -C "$GIT_REPO" branch -D "$1"
}
# own_pids: this script and everything under it, space padded; the processes treehouse lists for a slot are the seat's, never these
own_pids() { ps -eo pid=,ppid= 2>/dev/null | awk -v root=$$ '{p[$1]=$2} END {for (i in p) {j=i; while (j+0 > 1 && j != root) j=p[j]; if (j == root) printf " %s", i} printf " "}'; }
th_status() { # TH_OUT = treehouse status --json, retried; 0 when it parsed as a list
  local n=1
  while :; do
    TH_OUT=$(treehouse status --json 2>"$ERRF"); GH_ERR=$(tail -c 300 "$ERRF" | tr '\n' ' ')
    jq -e 'type == "array"' <<<"$TH_OUT" >/dev/null 2>&1 && return 0
    [ "$n" -lt "$RETRIES" ] || return 1
    nap "$n"; n=$((n + 1))
  done
}
# pid_alive PID: 0 when PID is a running process (a zombie is not)
pid_alive() { kill -0 "$1" 2>/dev/null && [ "$(ps -o stat= -p "$1" 2>/dev/null | cut -c1)" != Z ]; }
# idle_spare PID SLOTPATH: 0 when PID is a `claude bg-spare` or `claude bg-pty-host` whose cwd is in the slot, an idle Claude spare
# (architect ruling 2026-10-14 00:34Z): it belongs to no seat, so it is reaped and never counted as a foreign process. Any other claude,
# or a spare with its cwd elsewhere, is not one.
idle_spare() {
  local cmd; cmd=$(tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null) || return 1
  [[ $cmd =~ (^|[\ /])claude\ (bg-spare|bg-pty-host)( |$) ]] || return 1
  case "$(readlink "/proc/$1/cwd" 2>/dev/null)/" in "$2"/*) return 0;; esac
  return 1
}
# reap PID: SIGTERM, up to two seconds for it to go, then SIGKILL; 0 when it is gone
reap() {
  local tries=20; kill "$1" 2>/dev/null
  while [ "$tries" -gt 0 ]; do pid_alive "$1" || return 0; sleep 0.1; tries=$((tries - 1)); done
  kill -9 "$1" 2>/dev/null; sleep 0.1; ! pid_alive "$1"
}
# return_slot TICKET: gives back the slot leased to TICKET. Sets SLOT_NOTE. Returns 0 when it is back or there was none, 1 when treehouse failed,
# 3 when it was refused: a live process that is not this script's and is not an idle Claude spare is in the slot, or this script's own
# directory is (treehouse return --force ends every process there, the ruling of the architect 2026-10-14 00:30Z and the pane lost to it in
# WO-20261011-36d7). Idle Claude spares in the slot are reaped first and named in SLOT_NOTE.
return_slot() {
  local row path name pid nm live="" nlive=0 reaped=0 own cwd_in=0 g
  command -v treehouse >/dev/null || { GH_ERR="treehouse is not on PATH"; SLOT_NOTE="slot not checked"; return 1; }
  th_status || { SLOT_NOTE="slot not checked"; return 1; }
  row=$(jq -c --arg t "$1" '[.[] | select(.lease_holder == $t)] | last // empty' <<<"$TH_OUT")
  [ -n "$row" ] || { SLOT_NOTE="no slot is leased to $1"; return 0; }
  path=$(jq -r '.path // empty' <<<"$row"); name=$(jq -r '.name // "?"' <<<"$row")
  [ -n "$path" ] || { GH_ERR="treehouse lists the slot with no path"; SLOT_NOTE="slot $name not returned"; return 1; }
  own=$(own_pids)
  while IFS=$'\t' read -r pid nm; do
    [[ $pid =~ ^[0-9]+$ ]] && pid_alive "$pid" || continue   # a pid that has exited is not a process
    case "$own" in *" $pid "*) continue;; esac
    if idle_spare "$pid" "$path" && reap "$pid"; then reaped=$((reaped + 1)); continue; fi
    nlive=$((nlive + 1)); [ "$nlive" -gt 6 ] || live="$live $pid $nm;"   # the 423 note holds 240 characters: name the first six
  done < <(jq -r '(.processes // [])[] | [.pid, .name] | @tsv' <<<"$row")
  for g in "$PWD" "$GIT_REPO"; do case "$g/" in "$path"/*) cwd_in=1;; esac; done
  if [ -n "$live" ]; then GH_ERR="processes not belonging to the downed seat:${live%;}$([ "$nlive" -le 6 ] || printf ' and %s more' $((nlive - 6)))"; SLOT_NOTE="slot $name left leased"; return 3; fi
  if [ "$cwd_in" = 1 ]; then GH_ERR="merge.sh working directory or --repo is inside it"; SLOT_NOTE="slot $name left leased"; return 3; fi
  retry_cmd treehouse return "$path" --if-lease-holder "$1" --force || { SLOT_NOTE="slot $name not returned"; return 1; }
  th_status && jq -e --arg t "$1" 'any(.[]; .lease_holder == $t)' <<<"$TH_OUT" >/dev/null 2>&1 \
    && { GH_ERR="treehouse return exited 0 but slot $name is still leased to $1"; SLOT_NOTE="slot $name not returned"; return 1; }
  SLOT_NOTE="slot $name returned"; [ "$reaped" = 0 ] || SLOT_NOTE="$SLOT_NOTE after reaping $reaped idle claude spare(s)"; return 0
}
# post_merge_clean PR TICKET BRANCH: after the squash merge, in this order: the remote branch, the slot, the local branch. Each step is
# retried; a step that fails or is refused does not stop the next, and ONE blocked 423 to the orchestrator names every one that did.
# Sets CLEAN_DETAIL, the words appended to the merged line. The merge stands whatever happens here: exit stays 0.
#
# BREADCRUMB 2026-10-14 - WO-20261013-a18c, cause ag. What broke: after PR 136 merged, the merger ran work-order.sh cleanup, which
#   checks out main, and failed "cannot check out main" because main is checked out in another worktree (record vn435); the branch and
#   the slot were left for hand cleanup and the treehouse pool filled with leased slots. Why this fix: the merge is code (this file) and
#   so is its aftermath; git push origin --delete, git branch -D from a detached HEAD and treehouse return need no checkout at all, so
#   nothing here can hit that refusal, and merge.sh never calls work-order.sh cleanup. The slot is returned only when treehouse lists no
#   live process in it besides this script's own (architect ruling 2026-10-14 00:30Z): `treehouse return --force` ends every process in
#   the slot, it killed the architect's test pane twice (WO-20261011-36d7), so a foreign process leaves the slot leased and the 423
#   names it for the orchestrator, who owns agent health. Order is remote, slot, local: the slot's checkout may hold the branch, and
#   `git branch -D` refuses a branch checked out in a worktree, so the slot goes first. Rejected: --force without the check (the two
#   kills), waiting for the process to exit (a merge pass must not block on a seat) and ending it from here (it is somebody's shell).
#   Never deleted: the default branch, main, master. Cost: a branch whose slot cannot be returned stays local until the slot is; the 423
#   says so. Tests: line/tests/cases/merge-cleanup.test.sh. Not here: the gate, start and pr worktrees under the cache (WO-20261013-43ea).
post_merge_clean() {
  local br=$3 ok=() bad=() note
  CLEAN_DETAIL=""
  if [ -z "$br" ]; then CLEAN_DETAIL="; cleanup skipped: gh gave no head branch"; return 0; fi
  if ! safe_branch "$br"; then CLEAN_DETAIL="; cleanup skipped: refuses to delete branch $br"; return 0; fi
  if retry_cmd delete_remote "$br"; then ok+=("remote branch deleted"); else bad+=("remote branch $br: ${GH_ERR}"); fi
  if [ "${PR_FLOW_SLOTS:-1}" = 0 ]; then SLOT_NOTE="slots off"; true; else return_slot "$2"; fi; case $? in   # port: cleanup.slots
    0) ok+=("$SLOT_NOTE");;
    *) bad+=("$SLOT_NOTE: ${GH_ERR}");;
  esac
  if retry_cmd delete_local "$br"; then ok+=("local branch deleted"); else bad+=("local branch $br: ${GH_ERR}"); fi
  CLEAN_DETAIL="; cleanup: $(IFS=,; printf '%s' "${ok[*]}" | sed 's/,/, /g')"
  [ "${#bad[@]}" -gt 0 ] || return 0
  CLEAN_DETAIL="$CLEAN_DETAIL; NOT DONE: $(printf '%s | ' "${bad[@]}" | sed 's/ | $//')"
  note="merge.sh merged PR $1 but cleanup is not done: $(printf '%s | ' "${bad[@]}" | sed 's/ | $//')"; note=${note:0:240}
  post --code 423 --kind blocked --to orchestrator --ticket "$2" --pr "$1" --note "$note" \
    || printf 'merge: the blocked 423 for the cleanup of PR %s could not be posted: %s\n' "$1" "$GH_ERR" >&2
  return 0
}

do_pr() { # do_pr PR
  local pr=$1 view state title head branch mergeable ticket rc n=1 out mstate
  gh_retry pr view "$pr" --json number,state,title,body,headRefOid,headRefName,baseRefName,mergeable || { fail_io "$pr" "" "gh pr view"; return 4; }
  view=$GH_OUT
  state=$(jq -r '.state // empty' <<<"$view" 2>/dev/null); title=$(jq -r '.title // empty' <<<"$view"); head=$(jq -r '.headRefOid // empty' <<<"$view")
  branch=$(jq -r '.headRefName // empty' <<<"$view")
  mergeable=$(jq -r '.mergeable // "UNKNOWN"' <<<"$view")
  # port: the ticket from the title, else the body, else PR-<n> (PORT breadcrumb 3)
  if [[ $title =~ $TICKET_RE ]] || [[ $(jq -r '.body // empty' <<<"$view") =~ $TICKET_RE ]]; then ticket=${BASH_REMATCH[1]}; else ticket="PR-$pr"; fi
  case $state in
    MERGED) say "$pr" "$ticket" already-merged "nothing to do"; return 0;;
    OPEN) ;;
    *) say "$pr" "$ticket" held "the pull request is ${state:-in an unknown state}, not open"; return 3;;
  esac
  [[ $head =~ ^[0-9a-f]{40}$ ]] || { GH_ERR="gh reported no head commit"; fail_io "$pr" "$ticket" "gh pr view"; return 4; }
  # a conflict first: CI does not run on a PR GitHub cannot merge, so it would hold forever on pending checks (port)
  [ "$mergeable" != CONFLICTING ] || { post_conflict "$pr" "$ticket" "$head"; return $?; }

  # the gate (port): CI green on the head GitHub reports now, the required check among the checks; no review record
  out=$("$GATE" ci-green --slug "$SLUG" --pr "$pr" --sha "$head" --required "$REQUIRED" 2>"$ERRF"); rc=$?
  case $rc in
    0) ;;
    1) say "$pr" "$ticket" held "$out"; return 3;;
    *) GH_ERR=$(tail -c 300 "$ERRF" | tr '\n' ' '); fail_io "$pr" "$ticket" "gate.sh ci-green"; return 4;;
  esac
  # WO-20261016-0233 (F36): a head that still carries an in-progress or in-review work-order is held, never merged ahead of its close-out
  out=$("$GATE" ticket-open --repo "$GIT_REPO" --base "origin/$(jq -r '.baseRefName // "main"' <<<"$view")" --sha "$head" 2>"$ERRF"); rc=$?
  case $rc in
    0) ;;
    1) say "$pr" "$ticket" held "$(printf '%s' "$out" | tr '\n' ' ')"; return 3;;
    *) GH_ERR=$(tail -c 300 "$ERRF" | tr '\n' ' '); fail_io "$pr" "$ticket" "gate.sh ticket-open"; return 4;;
  esac

  # the merge: GitHub refuses it if the head moved since we read it; a hold written since the pass began refuses it here
  refuse_on_hold "$pr" "$ticket" || return 3
  while :; do
    out=$(cd "$GIT_REPO" && gh pr merge "$pr" --squash --match-head-commit "$head" 2>&1); rc=$?
    [ "$rc" -ne 0 ] || break
    GH_ERR=$(printf '%s' "$out" | tail -c 300 | tr '\n' ' ')
    gh_retry pr view "$pr" --json state,headRefOid,mergeable || { fail_io "$pr" "$ticket" "gh pr view after a refused merge"; return 4; }
    mstate=$(jq -r '.state // empty' <<<"$GH_OUT"); mergeable=$(jq -r '.mergeable // "UNKNOWN"' <<<"$GH_OUT")
    [ "$mstate" = MERGED ] && break
    if [ "$(jq -r '.headRefOid // empty' <<<"$GH_OUT")" != "$head" ]; then
      say "$pr" "$ticket" held "the head moved from ${head:0:12} while merging; the next pass checks the new head"; return 3
    fi
    if [ "$mergeable" = CONFLICTING ]; then post_conflict "$pr" "$ticket" "$head"; return $?; fi
    if [ "$n" -ge "$RETRIES" ]; then fail_io "$pr" "$ticket" "gh pr merge"; return 4; fi
    nap "$n"; n=$((n + 1))
  done
  merge_sha "$pr" || { fail_io "$pr" "$ticket" "gh pr view for the merge commit"; return 4; }
  post_merged "$pr" "$ticket" "$head" "$MERGE_SHA" || return $?
  post_merge_clean "$pr" "$ticket" "$branch"
  say "$pr" "$ticket" merged "$MERGED_DETAIL$CLEAN_DETAIL"; return 0
}

# a hold on merges: nothing is merged and no gh call is made (--all names no pull request, so its line says PR 0)
if [ "$ALL_FLAG" = 0 ]; then refuse_on_hold "$PR" "" || exit 3; else refuse_on_hold 0 "" || exit 3; fi
if [ "$ALL_FLAG" = 0 ]; then do_pr "$PR"; exit $?; fi
gh_retry pr list --state open --limit 200 --json number || { fail_io 0 "" "gh pr list"; exit 4; }
mapfile -t NUMS < <(jq -r 'map(.number) | sort | .[]' <<<"$GH_OUT" 2>/dev/null)
for p in "${NUMS[@]}"; do
  do_pr "$p"; rc=$?
  [ "$rc" -ne 4 ] || exit 4
done
exit 0
