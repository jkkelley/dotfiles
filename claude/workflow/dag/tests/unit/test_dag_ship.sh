#!/usr/bin/env bash
# name: test_dag_ship.sh
# purpose: proves bin/dag-ship.sh keeps the N6 N7 N10 promises of dag-state-nodes.spec.xml: open PR, close-out, cleanup, archive.
# inputs: none
# outputs: stdout (one ok/FAIL line per case, then the pass count), exit code
# writes-to: a mktemp scratch dir
# cleanup: removes its own temp dir on exit
# Each check names the failure it rules out:
#   - a second PR opened by a re-run of N6 (not idempotent in the spec)      - a PR body with an agent footer let through
#   - done before submit, or a close-out that is not pushed (N7)             - a cleanup that runs before the PR is MERGED (N10)
#   - a lease or worktree left behind, or a branch left local (N10)          - a run archived without DG-COMPLETE, or archived twice
# Hermetic: a temp git repo with a bare origin, stub gh, work-order.sh and slot.sh; no network and no real ticket.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0; n=0
ok()  { n=$((n+1)); printf 'ok  %s\n' "$1"; }
bad() { n=$((n+1)); fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
check() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3" "wanted [$1] got [$2]"; fi; }
# shellcheck source=../../bin/dag-lib.sh disable=SC1091
. "$R/bin/dag-lib.sh"

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
git init -q --bare "$T/origin.git"
git init -q -b main "$T/repo"; git -C "$T/repo" remote add origin "$T/origin.git"
echo x >"$T/repo/f"; git -C "$T/repo" add f; git -C "$T/repo" commit -q -m base; git -C "$T/repo" push -q origin main
export DAG_REPO_ROOT="$T/repo" DAG_STATE_DIR="$T/state" DAG_SLEEP=true DAG_RETRY_WAITS="0 0 0"
export DAG_WORK_ORDER="$T/wo.sh" DAG_SLOT="$T/slot.sh" DAG_GH="$T/gh.sh"
export WO_STATUS="$T/status" GH_DIR="$T/gh" SLOT_LOG="$T/slot.log"; mkdir -p "$GH_DIR"
cat >"$T/wo.sh" <<'S'
#!/usr/bin/env bash
cmd="$1"; shift; id=""; proj="."
while [ $# -gt 0 ]; do case "$1" in --id) id="$2"; shift 2 ;; --project) proj="$2"; shift 2 ;; *) shift ;; esac; done
echo "$cmd" >>"$WO_STATUS.calls"
case "$cmd" in
  show) printf '{"id":"%s","status":"%s"}\n' "$id" "$(cat "$WO_STATUS")" ;;
  submit) [ "$(cat "$WO_STATUS")" = in-progress ] || exit 3; echo in-review >"$WO_STATUS" ;;
  done) [ "$(cat "$WO_STATUS")" = in-review ] || exit 3; echo done >"$WO_STATUS"; echo closed >"$proj/closeout.txt" ;;
  cleanup) [ "$(cat "$GH_DIR/state" 2>/dev/null)" = MERGED ] || exit 3; git -C "$proj" branch -D feat/t8-ship >/dev/null 2>&1; true ;;
esac
S
cat >"$T/gh.sh" <<'S'
#!/usr/bin/env bash
# stub gh: pr list / pr create / pr view
case "$1 $2" in
  "pr list") [ -f "$GH_DIR/pr" ] && printf '%s' "$(cat "$GH_DIR/pr")" || true ;;
  "pr create") echo "$*" >>"$GH_DIR/creates"; echo "https://example.invalid/pull/7" >"$GH_DIR/url"; echo "7 https://example.invalid/pull/7" >"$GH_DIR/pr"; cat "$GH_DIR/url" ;;
  "pr view") case "$*" in *state*) cat "$GH_DIR/state" ;; *) cat "$GH_DIR/body" ;; esac ;;
esac
S
cat >"$T/slot.sh" <<'S'
#!/usr/bin/env bash
echo "$*" >>"$SLOT_LOG"
if [ "$1" = release ]; then while [ $# -gt 0 ]; do [ "$1" = --path ] && git -C "$DAG_REPO_ROOT" worktree remove --force "$2"; shift; done; fi
S
chmod +x "$T/gh.sh"
echo "T8 take and ship" >"$GH_DIR/body"
SHIP="$R/bin/dag-ship.sh"; TICKET=WO-20261016-9464; RUN=dagrun-20261016T041500Z-t8
RD="$DAG_STATE_DIR/runs/$RUN"; SHA="$(printf 'x' | sha256sum | cut -d' ' -f1)"
git -C "$T/repo" worktree add -q -b feat/t8-ship "$T/wt" main
echo OPEN >"$GH_DIR/state"
echo in-progress >"$WO_STATUS"
dag_init "$RUN" "$TICKET" "T8 take and ship" dag-state 1.0.0 "$SHA" "$T/wt" feat/t8-ship "$TICKET"
mkdir -p "$RD/nodes.lock"

# --- N6
bash "$SHIP" --run "$RUN" --node N6 >/dev/null 2>"$T/e"; check 0 $? "N6 exits 0"
check 7 "$(jq -r '.pr.number' "$RD/state.json")" "state records the PR number"
check in-review "$(cat "$WO_STATUS")" "ticket is in-review after submit"
check 1 "$(wc -l <"$GH_DIR/creates")" "one PR created"
git -C "$T/repo" rev-parse --verify -q refs/heads/feat/t8-ship >/dev/null && git --git-dir="$T/origin.git" rev-parse --verify -q feat/t8-ship >/dev/null
check 0 $? "the branch was pushed"
bash "$SHIP" --run "$RUN" --node N6 >/dev/null 2>&1; check 0 $? "N6 again exits 0"
check 1 "$(wc -l <"$GH_DIR/creates")" "N6 again opens no second PR (asks the world first)"
check 1 "$(grep -c '^submit$' "$WO_STATUS.calls")" "N6 again does not submit twice"
jq -e '.pr.number==7' "$RD/records/N6.out.json" >/dev/null; check 0 $? "N6 output record carries the PR"
printf 'body\n\nGenerated with Claude Code\n' >"$GH_DIR/body"
bash "$SHIP" --run "$RUN" --node N6 >/dev/null 2>&1; check 1 $? "N6 refuses a PR body with an agent footer"
chmod +x "$T/gh.sh"
echo "T8 take and ship" >"$GH_DIR/body"

# --- N7: done must follow submit
echo in-progress >"$WO_STATUS"
bash "$SHIP" --run "$RUN" --node N7 >/dev/null 2>&1; check 1 $? "N7 refuses when the ticket was not submitted"
echo in-review >"$WO_STATUS"
bash "$SHIP" --run "$RUN" --node N7 >/dev/null 2>"$T/e"; check 0 $? "N7 exits 0"
check done "$(cat "$WO_STATUS")" "ticket is done"
check "$(git -C "$T/wt" rev-parse HEAD)" "$(git --git-dir="$T/origin.git" rev-parse feat/t8-ship)" "the close-out is pushed to the PR branch"
bash "$SHIP" --run "$RUN" --node N7 >/dev/null 2>&1; check 0 $? "N7 again exits 0"
check 1 "$(grep -c '^done$' "$WO_STATUS.calls")" "N7 again does not run done twice"

# --- N10: refused until MERGED, then everything goes
echo OPEN >"$GH_DIR/state"
bash "$SHIP" --run "$RUN" --node N10 >/dev/null 2>&1; check 1 $? "N10 refuses while the PR is not MERGED"
echo MERGED >"$GH_DIR/state"
bash "$SHIP" --run "$RUN" --node N10 >/dev/null 2>"$T/e"; check 0 $? "N10 exits 0 once MERGED"
check "" "$(git -C "$T/repo" branch --list feat/t8-ship)" "the local branch is gone"
grep -q "^release --holder $TICKET" "$SLOT_LOG"; check 0 $? "the lease was released"
grep -q '^cleanup$' "$WO_STATUS.calls"; check 0 $? "work-order.sh cleanup ran"
grep -q DG-COMPLETE "$RD/ledger.jsonl"; check 0 $? "ledger holds DG-COMPLETE"

# --- archive
bash "$SHIP" --run "$RUN" --archive; check 0 $? "archive exits 0"
[ -d "$DAG_STATE_DIR/archive/$RUN" ] && [ ! -d "$RD" ]; check 0 $? "the run moved under archive/"
bash "$SHIP" --run "$RUN" --archive; check 0 $? "archive again exits 0"
RUN2=dagrun-20261016T041600Z-t8b
dag_init "$RUN2" WO-20261016-bbbb "Other" dag-state 1.0.0 "$SHA" "$T/wt2" feat/x
bash "$SHIP" --run "$RUN2" --archive >/dev/null 2>&1; check 1 $? "archive refuses a run without DG-COMPLETE"

# --- usage
bash "$SHIP" --run "$RUN2" --node N4 >/dev/null 2>&1; check 2 $? "a node outside N6 N7 N10 is a usage error"
bash "$SHIP" >/dev/null 2>&1; check 2 $? "no arguments is a usage error"

printf 'pass=%s fail=%s\n' "$((n-fail))" "$fail"
[ "$fail" = 0 ]
