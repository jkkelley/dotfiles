#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# dag-ship.sh - shipping work: nodes N6 open-pr, N7 close-out, N10 cleanup of the intake DAG, plus the archive step.
#   name:       dag-ship.sh
#   purpose:    N6 pushes the branch, opens the PR and submits the ticket; N7 closes the ticket out on the branch and pushes;
#               N10 removes the branch, lease and worktree after the merge and marks the run DG-COMPLETE (spec nodes N6 N7 N10)
#   inputs:     --run RUN --node N6|N7|N10 [--config FILE]   (what dag-apply.sh calls)
#               --run RUN --archive                          (moves a DG-COMPLETE run under <state_dir>/archive/)
#               DAG_STATE_DIR, DAG_CONFIG, DAG_REPO_ROOT, DAG_WORK_ORDER, DAG_SLOT as in dag-take.sh;
#               DAG_GH (gh command, default gh), DAG_PR_BODY_FILE (PR body; default a one-line body naming the ticket),
#               DAG_HYDRATION_BODY_FILE (hydration entry body for N7; unset skips the hydration add and says so in the output),
#               DAG_HYDRATION (hydration.sh path), DAG_BASE_REF is not used here
#   outputs:    node mode writes the node's output record (declared output.path, else records/<node>.out.json);
#               exit 0 ok, 1 failed, 2 usage, 3 DG-SCHEMA, 4 DG-STATE-STALE, 5 DG-LOCK-HELD
#   writes-to:  <state_dir>/runs/<run-id>/ and <state_dir>/archive/; the PR branch; the ticket by work-order.sh
#   cleanup:    N10 removes the local and remote branch, releases the lease, removes the worktree
# Spec: docs/design/dag-state.spec.xml rules R4 R9; nodes N6 N7 N10.
#
# BREADCRUMB (WO-20261016-9464, dag-state T8). N6 and N7 are not idempotent in the spec (retry 0), so each one asks the world
# first: N6 looks for an open PR on the branch before `gh pr create`, N7 reads the ticket status before `done`, which is what
# `recover` expects of a non-idempotent node. N10 must not move the run directory itself: dag-apply.sh writes the node result
# into that directory after this script returns, so a move here would make apply fail with the run gone. The move is the
# separate `--archive` verb, run after apply. Rejected: archiving inside N10. Cost: the N10 box "state archived" is proven by
# --archive, one call after apply.
# Fallback (design principle 28): `gh pr merge` is never used here; merging is N9's script.

set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dag-lib.sh disable=SC1091
. "$DIR/dag-lib.sh"

ROOT="${DAG_REPO_ROOT:-$(cd "$DIR/../../../.." && pwd)}"
WO="${DAG_WORK_ORDER:-$ROOT/claude/skills/work-order/scripts/work-order.sh}"
SLOT="${DAG_SLOT:-$ROOT/claude/skills/hydration-prompt/scripts/slot.sh}"
HYD="${DAG_HYDRATION:-$ROOT/claude/skills/hydration-prompt/scripts/hydration.sh}"
GH="${DAG_GH:-gh}"
USAGE="usage: dag-ship.sh --run RUN --node N6|N7|N10 | --run RUN --archive [--config FILE]"

RUN=""; NODE=""; ARCHIVE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --run) RUN="${2:-}"; shift 2 ;;
    --node) NODE="${2:-}"; shift 2 ;;
    --archive) ARCHIVE=1; shift ;;
    --config) DAG_CONFIG="${2:-}"; export DAG_CONFIG; shift 2 ;;
    *) dag_err "$USAGE"; exit 2 ;;
  esac
done
[ -n "$RUN" ] || { dag_err "$USAGE"; exit 2; }
DAG_STATE_DIR="$(dag_state_dir)" || exit 2; export DAG_STATE_DIR
RD="$(dag_run_dir "$RUN")" || exit 2

out_path() {
  local p; p="$(jq -r '.output.path // empty' "$RD/nodes.lock/$1.json" 2>/dev/null)"
  [ -n "$p" ] || p="records/$1.out.json"
  case "$p" in /*) printf '%s' "$p" ;; *) printf '%s/%s' "$RD" "$p" ;; esac
}
write_out() {
  local f tmp; f="$(out_path "$1")"; mkdir -p "$(dirname "$f")"
  tmp="$(mktemp "$f.XXXXXX")" || return 1
  printf '%s\n' "$2" >"$tmp" && mv "$tmp" "$f"
}
ticket_status() { bash "$WO" show --id "$1" --json --project "$2" 2>/dev/null | jq -r '.status // empty'; }

# --- N6: push, PR, submit. Asks the world for an existing PR first (non-idempotent node).
node_n6() {
  local st tid title wt branch pr url body footer
  st="$(dag_read "$RUN")" || return $?
  tid="$(jq -r '.ticket.id' <<<"$st")"; title="$(jq -r '.ticket.title' <<<"$st")"
  wt="$(jq -r '.worktree.path' <<<"$st")"; branch="$(jq -r '.worktree.branch' <<<"$st")"
  pr="$($GH pr list --head "$branch" --state open --json number,url --jq '.[0] | select(.) | "\(.number) \(.url)"' 2>/dev/null)"
  if [ -z "$pr" ]; then
    git -C "$wt" push -q -u origin "$branch" || { dag_err "N6: push of $branch failed"; return 1; }
    body="${DAG_PR_BODY_FILE:-}"
    if [ -z "$body" ]; then body="$RD/records/N6.pr-body.md"; printf '%s\n' "$title" >"$body"; fi
    url="$(cd "$wt" && $GH pr create --head "$branch" --title "$title" --body-file "$body")" || { dag_err "N6: gh pr create failed"; return 1; }
    pr="${url##*/} $url"
  fi
  local num="${pr%% *}" purl="${pr#* }"
  [[ $num =~ ^[0-9]+$ ]] || { dag_err "N6: no PR number in '$pr'"; return 1; }
  footer="$($GH pr view "$num" --json body --jq .body 2>/dev/null)"
  if grep -qiE 'generated with .*claude|co-authored-by: *claude' <<<"$footer"; then dag_err "N6: PR $num body carries an agent footer"; return 1; fi
  [ "$(ticket_status "$tid" "$wt")" = in-review ] || bash "$WO" submit --id "$tid" --pr "$num" --project "$wt" || { dag_err "N6: submit failed"; return 1; }
  dag_write "$RUN" '.pr = {number:($n|tonumber), url:$u}' --arg n "$num" --arg u "$purl" || return $?
  write_out N6 "$(jq -cn --argjson n "$num" --arg u "$purl" --arg t "$tid" '{pr:{number:$n, url:$u}, ticket:$t, status:"in-review"}')"
}

# --- N7: done on the branch, optional hydration entry, commit and push on the same PR.
node_n7() {
  local st tid wt branch hyd="skipped" head
  st="$(dag_read "$RUN")" || return $?
  tid="$(jq -r '.ticket.id' <<<"$st")"; wt="$(jq -r '.worktree.path' <<<"$st")"; branch="$(jq -r '.worktree.branch' <<<"$st")"
  [ "$(jq -r '.pr // empty' <<<"$st")" != "" ] || { dag_err "N7: no PR in state; N6 first"; return 1; }
  case "$(ticket_status "$tid" "$wt")" in
    in-review) bash "$WO" "done" --id "$tid" --project "$wt" || { dag_err "N7: done failed"; return 1; } ;;
    done) ;;
    *) dag_err "N7: ticket not in-review (submit must precede done)"; return 1 ;;
  esac
  if [ -n "${DAG_HYDRATION_BODY_FILE:-}" ]; then
    bash "$HYD" add --project "$wt" --title "$(jq -r '.ticket.title' <<<"$st")" --body-file "$DAG_HYDRATION_BODY_FILE" --id "$tid" || { dag_err "N7: hydration add failed"; return 1; }
    hyd="added"
  fi
  git -C "$wt" add -A || return 1
  git -C "$wt" diff --cached --quiet || git -C "$wt" commit -q -m "chore(work-orders): close out $tid" || return 1
  git -C "$wt" push -q origin "$branch" || { dag_err "N7: push failed"; return 1; }
  head="$(git -C "$wt" rev-parse HEAD)"
  write_out N7 "$(jq -cn --arg t "$tid" --arg h "$head" --arg y "$hyd" '{ticket:$t, status:"done", head:$h, hydration:$y}')"
}

# --- N10: after the merge, work-order.sh cleanup, release the lease, remove the worktree, row DG-COMPLETE.
node_n10() {
  local st tid wt branch slot
  st="$(dag_read "$RUN")" || return $?
  tid="$(jq -r '.ticket.id' <<<"$st")"; wt="$(jq -r '.worktree.path' <<<"$st")"; branch="$(jq -r '.worktree.branch' <<<"$st")"
  slot="$(jq -r '.worktree.slot // empty' <<<"$st")"
  # the branch is checked out in the worktree, so the worktree goes first; ask gh before destroying anything
  [ "$($GH pr view "$(jq -r '.pr.number' <<<"$st")" --json state --jq .state 2>/dev/null)" = MERGED ] || { dag_err "N10: PR is not MERGED"; return 1; }
  if [ -n "$slot" ]; then
    bash "$SLOT" release --holder "$slot" --path "$wt" --repo "$ROOT" || { dag_err "N10: slot release failed"; return 1; }
  elif [ -d "$wt" ]; then
    git -C "$ROOT" worktree remove --force "$wt" || return 1
  fi
  bash "$WO" cleanup --id "$tid" --project "$ROOT" || { dag_err "N10: work-order.sh cleanup refused"; return 1; }
  git -C "$ROOT" branch --list "$branch" | grep -q . && { dag_err "N10: branch $branch still local"; return 1; }
  [ ! -e "$wt" ] || [ -n "$slot" ] || { dag_err "N10: worktree $wt still present"; return 1; }
  dag_ledger "$RUN" apply DG-COMPLETE N10 "cleaned $tid" || return $?
  write_out N10 "$(jq -cn --arg t "$tid" --arg b "$branch" '{ticket:$t, branch_removed:$b, complete:true}')"
}

# --- archive: move a DG-COMPLETE run under archive/. Idempotent.
archive() {
  local dest; dest="$DAG_STATE_DIR/archive/$RUN"
  if [ ! -d "$RD" ] && [ -d "$dest" ]; then return 0; fi
  grep -q '"code":"DG-COMPLETE"' "$RD/ledger.jsonl" 2>/dev/null || { dag_err "archive: $RUN has no DG-COMPLETE row"; return 1; }
  mkdir -p "$DAG_STATE_DIR/archive" && rm -rf "$RD/lock" && mv "$RD" "$dest"
}

if [ "$ARCHIVE" = 1 ]; then archive; exit $?; fi
[ -n "$NODE" ] || { dag_err "$USAGE"; exit 2; }
mkdir -p "$RD/records"
case "$NODE" in
  N6) node_n6 ;;
  N7) node_n7 ;;
  N10) dag_retry 3 node_n10 ;;
  *) dag_err "dag-ship: node '$NODE' is not N6 N7 N10"; exit 2 ;;
esac
