#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# dag-take.sh - taking work: nodes N1 claim, N2 worktree-branch, N3 start-ticket of the intake DAG.
#   name:       dag-take.sh
#   purpose:    N1 creates the run (state.json, nodes.lock/, run lock dir) and pins the design hash; N2 leases a worktree and
#               names the feature branch; N3 starts the ticket inside that worktree (spec dag-state-nodes.spec.xml N1 N2 N3)
#   inputs:     claim mode:  --ticket WO-ID [--slug S] [--config FILE]          (what `make dag-take TICKET=` calls)
#               node mode:   --run RUN --node N1|N2|N3 [--config FILE]          (what dag-apply.sh calls)
#               DAG_STATE_DIR, DAG_CONFIG (base_branch, state_dir), DAG_REPO_ROOT (the repo; default: the one this script is in),
#               DAG_NODES_DIR (declarations to pin, default <repo>/claude/workflow/dag/nodes), DAG_DESIGN_ID (default dag-state),
#               DAG_DESIGN_VERSION (default 1.0.0), DAG_WORK_ORDER (work-order.sh path), DAG_SLOT (slot.sh path),
#               DAG_WORKTREE_ROOT (fallback worktree parent, default <repo>/../wt-dag), DAG_BASE_REF (default origin/<base_branch>),
#               DAG_RETRY_WAITS / DAG_SLEEP as in dag-lib.sh
#   outputs:    claim mode prints the run id; node mode writes the node's output record (declared output.path, else
#               records/<node>.out.json) and proofs the checklist; exit 0 ok, 1 failed, 2 usage, 3 DG-SCHEMA, 4 DG-STATE-STALE, 5 DG-LOCK-HELD
#   writes-to:  <state_dir>/runs/<run-id>/ (outside the repository); the worktree and branch of the ticket; the ticket file by work-order.sh
#   cleanup:    a claim that fails after the run dir was made leaves a run that `recover` or `make dag-clean` removes; nothing else
# Spec: docs/design/dag-state.spec.xml rules R1 R5 R9; nodes N1 N2 N3.
#
# BREADCRUMB (WO-20261016-9464, dag-state T8). work-order.sh start runs `git checkout -b feat/<slug>` and refuses with branch_exists
# when that branch is already there (work-order.sh cmd_start), so N2 cannot create the branch and N3 then start the ticket.
# N2 therefore leases the worktree, checks it out detached at the base ref and records the branch NAME feat/<slug> in state;
# N3 runs start, which creates that branch, and only then proves HEAD equals the state branch. Rejected: N3 renaming a branch
# around start (a second hand-rolled step on a ticket verb). Cost: the N2 box "branch is a new feature branch" is proven in N3.
# Fallback (design principle 28): slot.sh acquire failing falls back to `git worktree add`, with its own test.

set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dag-lib.sh disable=SC1091
. "$DIR/dag-lib.sh"

ROOT="${DAG_REPO_ROOT:-$(cd "$DIR/../../../.." && pwd)}"
WO="${DAG_WORK_ORDER:-$ROOT/claude/skills/work-order/scripts/work-order.sh}"
SLOT="${DAG_SLOT:-$ROOT/claude/skills/hydration-prompt/scripts/slot.sh}"
USAGE="usage: dag-take.sh --ticket WO-ID [--slug S] | --run RUN --node N1|N2|N3 [--config FILE]"

TICKET=""; SLUG=""; RUN=""; NODE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ticket) TICKET="${2:-}"; shift 2 ;;
    --slug) SLUG="${2:-}"; shift 2 ;;
    --run) RUN="${2:-}"; shift 2 ;;
    --node) NODE="${2:-}"; shift 2 ;;
    --config) DAG_CONFIG="${2:-}"; export DAG_CONFIG; shift 2 ;;
    *) dag_err "$USAGE"; exit 2 ;;
  esac
done

sha_dir() { (cd "$1" 2>/dev/null && find . -type f | LC_ALL=C sort | xargs -r sha256sum | sha256sum | cut -d' ' -f1); }
base_branch() { dag_cfg base_branch main; }

# out_path <node> - the declared output path of the node, absolute; default records/<node>.out.json.
out_path() {
  local p; p="$(jq -r '.output.path // empty' "$RD/nodes.lock/$1.json" 2>/dev/null)"
  [ -n "$p" ] || p="records/$1.out.json"
  case "$p" in /*) printf '%s' "$p" ;; *) printf '%s/%s' "$RD" "$p" ;; esac
}
# write_out <node> <json> - the node output record, atomically.
write_out() {
  local f tmp; f="$(out_path "$1")"; mkdir -p "$(dirname "$f")"
  tmp="$(mktemp "$f.XXXXXX")" || return 1
  printf '%s\n' "$2" >"$tmp" && mv "$tmp" "$f"
}
ticket_json() { bash "$WO" show --id "$1" --json; }

# --- claim mode (N1's first half): make the run dir, pin the design.
claim() {
  [[ $TICKET =~ ^WO-[0-9]{8}-[a-z0-9]+$ ]] || { dag_err "dag-take: bad ticket id '$TICKET'"; return 2; }
  local sd f existing tj title slug run nodes_src
  sd="$(dag_state_dir)" || return 2
  # idempotent: a live run for this ticket is returned, never a second one
  for f in "$sd"/runs/dagrun-*/state.json; do
    [ -f "$f" ] || continue
    if [ "$(jq -r '.ticket.id' "$f")" = "$TICKET" ]; then existing="$(jq -r '.run_id' "$f")"; printf '%s\n' "$existing"; return 0; fi
  done
  tj="$(ticket_json "$TICKET")" || { dag_err "dag-take: work-order.sh show failed for $TICKET"; return 1; }
  title="$(jq -r '.title // empty' <<<"$tj")"; [ -n "$title" ] || { dag_err "dag-take: ticket $TICKET has no title"; return 1; }
  slug="${SLUG:-$(jq -r '.slug // empty' <<<"$tj" | cut -c1-40 | sed 's/-*$//')}"
  [ -n "$slug" ] || slug="run"
  run="dagrun-$(date -u +%Y%m%dT%H%M%SZ)-$slug"
  nodes_src="${DAG_NODES_DIR:-$ROOT/claude/workflow/dag/nodes}"
  DAG_STATE_DIR="$sd"; export DAG_STATE_DIR
  RD="$(dag_run_dir "$run")" || return 2
  mkdir -p "$RD/nodes.lock" || return 1
  [ -d "$nodes_src" ] && cp -R "$nodes_src"/. "$RD/nodes.lock/"
  dag_init "$run" "$TICKET" "$title" "${DAG_DESIGN_ID:-dag-state}" "${DAG_DESIGN_VERSION:-1.0.0}" "$(sha_dir "$RD/nodes.lock")" \
    "$(dirname "$ROOT")/wt-dag/$TICKET" "feat/$(jq -r '.slug' <<<"$tj")" || return $?
  printf '%s\n' "$run"
}

# --- N1: validate the state, prove the three boxes, write the output record.
node_n1() {
  local st; st="$(dag_read "$RUN")" || return $?
  local want got title
  want="$(jq -r '.design.sha256' <<<"$st")"; got="$(sha_dir "$RD/nodes.lock")"
  [ "$want" = "$got" ] || { dag_err "N1: design.sha256 $want != nodes.lock $got"; return 1; }
  title="$(jq -r '.ticket.title' <<<"$st")"; [ -n "$title" ] || { dag_err "N1: ticket title empty"; return 1; }
  write_out N1 "$(jq -cn --arg run "$RUN" --arg t "$(jq -r '.ticket.id' <<<"$st")" --arg sha "$got" --arg at "$(dag_now)" \
    '{run_id:$run, ticket:$t, design_sha256:$sha, at:$at}')"
}

# --- N2: lease a worktree off the base ref and record path, branch name, slot.
node_n2() {
  local st tid wt branch slot base ref
  st="$(dag_read "$RUN")" || return $?
  tid="$(jq -r '.ticket.id' <<<"$st")"; wt="$(jq -r '.worktree.path' <<<"$st")"; branch="$(jq -r '.worktree.branch' <<<"$st")"
  slot="$(jq -r '.worktree.slot // empty' <<<"$st")"
  base="$(base_branch)"; ref="${DAG_BASE_REF:-origin/$base}"
  if [ -d "$wt/.git" ] || [ -f "$wt/.git" ]; then
    : # idempotent: worktree already there
  else
    local out
    if out="$(bash "$SLOT" acquire --holder "$tid" --repo "$ROOT" 2>&1)" && wt="$(tail -n 1 <<<"$out")" && [ -n "$wt" ] && [ -d "$wt" ]; then
      slot="$tid"
      git -C "$wt" checkout -q --detach "$ref" || return 1
    else
      dag_err "N2: slot.sh acquire failed ($out); falling back to git worktree add"
      wt="$(jq -r '.worktree.path' <<<"$st")"
      mkdir -p "$(dirname "$wt")" && git -C "$ROOT" worktree add -q --detach "$wt" "$ref" || return 1
    fi
  fi
  dag_write "$RUN" '.worktree.path = $p | .worktree.slot = (if $s == "" then null else $s end)' --arg p "$wt" --arg s "$slot" || return $?
  write_out N2 "$(jq -cn --arg p "$wt" --arg b "$branch" --arg s "$slot" --arg r "$ref" '{worktree:$p, branch:$b, slot:$s, base_ref:$r}')"
}

# --- N3: work-order.sh start inside the worktree; the ticket must read in-progress.
node_n3() {
  local st tid wt branch status
  st="$(dag_read "$RUN")" || return $?
  tid="$(jq -r '.ticket.id' <<<"$st")"; wt="$(jq -r '.worktree.path' <<<"$st")"; branch="$(jq -r '.worktree.branch' <<<"$st")"
  [ -d "$wt" ] || { dag_err "N3: worktree $wt missing"; return 1; }
  status="$(bash "$WO" show --id "$tid" --json --project "$wt" 2>/dev/null | jq -r '.status // empty')"
  if [ "$status" != in-progress ]; then
    bash "$WO" start --id "$tid" --project "$wt" || { dag_err "N3: work-order.sh start failed for $tid"; return 1; }
    status="$(bash "$WO" show --id "$tid" --json --project "$wt" | jq -r '.status // empty')"
  fi
  [ "$status" = in-progress ] || { dag_err "N3: ticket status is '$status'"; return 1; }
  [ "$(git -C "$wt" rev-parse --abbrev-ref HEAD)" = "$branch" ] || { dag_err "N3: HEAD is not $branch"; return 1; }
  write_out N3 "$(jq -cn --arg t "$tid" --arg s "$status" --arg b "$branch" '{ticket:$t, status:$s, branch:$b}')"
}

if [ -n "$TICKET" ] && [ -z "$RUN" ]; then claim; exit $?; fi
[ -n "$RUN" ] && [ -n "$NODE" ] || { dag_err "$USAGE"; exit 2; }
DAG_STATE_DIR="$(dag_state_dir)" || exit 2; export DAG_STATE_DIR
RD="$(dag_run_dir "$RUN")" || exit 2
mkdir -p "$RD/records"
case "$NODE" in
  N1) dag_retry 3 node_n1 ;;
  N2) dag_retry 3 node_n2 ;;
  N3) dag_retry 3 node_n3 ;;
  *) dag_err "dag-take: node '$NODE' is not N1 N2 N3"; exit 2 ;;
esac
