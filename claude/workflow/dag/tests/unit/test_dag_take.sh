#!/usr/bin/env bash
# name: test_dag_take.sh
# purpose: proves bin/dag-take.sh keeps the N1 N2 N3 promises of dag-state-nodes.spec.xml: claim, worktree and lease, start ticket.
# inputs: none
# outputs: stdout (one ok/FAIL line per case, then the pass count), exit code
# writes-to: a mktemp scratch dir
# cleanup: removes its own temp dir on exit
# Each check names the failure it rules out:
#   - a second run for one ticket, or a claim with the title missing (N1)   - a design hash that is not the hash of nodes.lock/
#   - a worktree with no lease, or no fallback when slot.sh fails (N2)      - a ticket not in-progress, or HEAD not on the branch (N3)
#   - a node re-run that damages state (idempotent, spec N1 N2 N3)           - an output record missing where apply looks for it
# Hermetic: a temp git repo with a bare origin, stub work-order.sh and slot.sh; no network, no real lease pool, no real ticket.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0; n=0
ok()  { n=$((n+1)); printf 'ok  %s\n' "$1"; }
bad() { n=$((n+1)); fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
check() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3" "wanted [$1] got [$2]"; fi; }

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
git init -q --bare "$T/origin.git"
git init -q -b main "$T/repo"; git -C "$T/repo" remote add origin "$T/origin.git"
echo x >"$T/repo/f"; git -C "$T/repo" add f; git -C "$T/repo" commit -q -m base; git -C "$T/repo" push -q origin main
export DAG_REPO_ROOT="$T/repo" DAG_STATE_DIR="$T/state" DAG_SLEEP=true DAG_RETRY_WAITS="0 0 0"
export DAG_NODES_DIR="$T/nodes" DAG_WORK_ORDER="$T/wo.sh" DAG_SLOT="$T/slot.sh" DAG_BASE_REF=main
export DAG_CONFIG="$T/dag.json"; printf '{"base_branch":"main"}\n' >"$DAG_CONFIG"
mkdir -p "$T/nodes"; for i in N1 N2 N3; do echo "{\"id\":\"$i\"}" >"$T/nodes/$i.json"; done
export WO_STATUS="$T/status"; echo ready >"$WO_STATUS"
cat >"$T/wo.sh" <<'S'
#!/usr/bin/env bash
cmd="$1"; shift; id=""; proj="."
while [ $# -gt 0 ]; do case "$1" in --id) id="$2"; shift 2 ;; --project) proj="$2"; shift 2 ;; *) shift ;; esac; done
case "$cmd" in
  show) printf '{"id":"%s","title":"T8 take and ship","slug":"t8-take","status":"%s"}\n' "$id" "$(cat "$WO_STATUS")" ;;
  start) [ "$(cat "$WO_STATUS")" = ready ] || exit 3; git -C "$proj" checkout -q -b feat/t8-take || exit 3; echo in-progress >"$WO_STATUS"; echo started >>"$WO_STATUS.calls" ;;
  *) exit 2 ;;
esac
S
cat >"$T/slot.sh" <<'S'
#!/usr/bin/env bash
[ "$1" = acquire ] || exit 2
[ -z "${SLOT_FAIL:-}" ] || { echo "no slot" >&2; exit 5; }
p="$SLOT_ROOT/slot-$$"; git -C "$DAG_REPO_ROOT" worktree add -q --detach "$p" main && echo "$p" && echo acquire >>"$SLOT_ROOT/calls"
S
export SLOT_ROOT="$T/slots"; mkdir -p "$SLOT_ROOT"
TAKE="$R/bin/dag-take.sh"
TICKET=WO-20261016-9464

# --- N1: claim makes one run with the full title and the pinned design hash.
RUN="$(bash "$TAKE" --ticket "$TICKET" 2>"$T/e")"; check 0 $? "claim exits 0"
RD="$DAG_STATE_DIR/runs/$RUN"
check "T8 take and ship" "$(jq -r '.ticket.title' "$RD/state.json")" "claim records the ticket title in full"
check "$(cd "$RD/nodes.lock" && find . -type f | LC_ALL=C sort | xargs sha256sum | sha256sum | cut -d' ' -f1)" "$(jq -r '.design.sha256' "$RD/state.json")" "design.sha256 equals the hash of nodes.lock/"
check "$RUN" "$(bash "$TAKE" --ticket "$TICKET")" "claiming the same ticket again returns the same run"
check 1 "$(ls "$DAG_STATE_DIR/runs" | wc -l)" "no second run directory"
bash "$TAKE" --ticket not-a-ticket >/dev/null 2>&1; check 2 $? "a bad ticket id is a usage error"
bash "$TAKE" --run "$RUN" --node N1; check 0 $? "N1 node mode exits 0"
[ -f "$RD/records/N1.out.json" ]; check 0 $? "N1 leaves its output record"
bash "$TAKE" --run "$RUN" --node N1; check 0 $? "N1 again exits 0 (idempotent)"
echo '{"id":"N9"}' >"$RD/nodes.lock/N9.json"
bash "$TAKE" --run "$RUN" --node N1 >/dev/null 2>&1; check 1 $? "N1 fails when nodes.lock drifted from the pinned hash"
rm -f "$RD/nodes.lock/N9.json"

# --- N2: a slot is leased and recorded; HEAD sits at base.
bash "$TAKE" --run "$RUN" --node N2; check 0 $? "N2 with a slot exits 0"
WT="$(jq -r '.worktree.path' "$RD/state.json")"
check "$SLOT_ROOT" "$(dirname "$WT")" "state worktree is the leased slot path"
check "$TICKET" "$(jq -r '.worktree.slot' "$RD/state.json")" "state records the lease holder"
check "$(git -C "$T/repo" rev-parse main)" "$(git -C "$WT" rev-parse HEAD)" "worktree is at the base ref"
check 1 "$(grep -c acquire "$SLOT_ROOT/calls")" "one lease taken"
bash "$TAKE" --run "$RUN" --node N2; check 0 $? "N2 again exits 0"
check 1 "$(grep -c acquire "$SLOT_ROOT/calls")" "N2 again takes no second lease (idempotent)"

# --- N2 fallback: slot.sh refuses, git worktree add is used (its own test, design principle 28).
RUN2="$(DAG_STATE_DIR="$T/state2" bash "$TAKE" --ticket WO-20261016-aaaa)"
SLOT_FAIL=1 DAG_STATE_DIR="$T/state2" bash "$TAKE" --run "$RUN2" --node N2 2>/dev/null; check 0 $? "N2 falls back when slot.sh fails"
WT2="$(jq -r '.worktree.path' "$T/state2/runs/$RUN2/state.json")"
[ -e "$WT2/.git" ]; check 0 $? "the fallback worktree exists"
check null "$(jq -r '.worktree.slot' "$T/state2/runs/$RUN2/state.json")" "the fallback records no slot"

# --- N3: the ticket starts inside the worktree and HEAD lands on the state branch.
bash "$TAKE" --run "$RUN" --node N3; check 0 $? "N3 exits 0"
check in-progress "$(sed -n 1p "$WO_STATUS")" "ticket status is in-progress"
check feat/t8-take "$(git -C "$WT" rev-parse --abbrev-ref HEAD)" "HEAD is the state branch"
bash "$TAKE" --run "$RUN" --node N3; check 0 $? "N3 again exits 0"
check 1 "$(wc -l <"$WO_STATUS.calls")" "N3 again does not start the ticket twice (idempotent)"
jq -e '.status=="in-progress"' "$RD/records/N3.out.json" >/dev/null; check 0 $? "N3 output record names the status"

# --- usage and lock.
bash "$TAKE" --run "$RUN" --node N4 >/dev/null 2>&1; check 2 $? "a node outside N1 N2 N3 is a usage error"
bash "$TAKE" >/dev/null 2>&1; check 2 $? "no arguments is a usage error"
[ ! -d "$RD/lock" ]; check 0 $? "no lock left behind"

printf 'pass=%s fail=%s\n' "$((n-fail))" "$fail"
[ "$fail" = 0 ]
