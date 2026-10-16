#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# sweep-collect.sh - node R5 of the inbox sweep: turn the seats' results into one run summary and one run code.
#
#   sweep-collect.sh --run <run-id> [--controller-error]
#
# Input:  <run>/run.json (the seat list), <run>/results/*.json, <run>/preflight.json, <run>/proof/R7-verdict.json
# Output: <run>/summary.json {schema_version, run_id, status, seats:[{seat, status, before, after, processed, flagged}], finished_at}
#         <run>/summary.md      a contents list, a run section, then one table per source, newest item first
#         <run>/checklist.jsonl two R5 rows (status derived, every seat counted)
#
# Run status is derived exactly as spec codes/run/derive, first match wins:
#   controller error, PF-NO-HERDR or PF-NO-OWNER-WORDS      RUN-FAILED
#   every seat OK and the clean code is CLEAN-OK             RUN-OK
#   any seat OK                                              RUN-PARTIAL
#   any seat BLOCKED-* or SKIPPED                            RUN-BLOCKED
#   otherwise                                                RUN-FAILED
#
# Two inputs are not in the spec's input line and are worth knowing about:
#   * The clean code lives in proof/R7-verdict.json, which sweep-proof.sh writes AFTER collect (design section 5, R7).
#     So the first collect can never say RUN-OK: a missing verdict is "not CLEAN-OK", which is the safe answer, never
#     an assumption that the tabs are closed. The controller re-runs collect once R7 has a verdict; the script is
#     idempotent and rewrites both files. Rejected alternative: treating a missing verdict as clean, which would
#     report RUN-OK for a run whose tab bar was never checked.
#   * "controller error" has no run.json field in the spec, so the controller passes --controller-error. Rejected
#     alternative: inventing a run.json field the controller and this script would have to agree on out of band.
#
# Every seat in run.json .seats is accounted for. A seat with no readable result file takes the status run.json holds
# for it when that is a seat code (SKIPPED is written there by sweep.sh with no result file), else FAILED-SEAT: a
# seat that left nothing behind failed, and a summary that dropped it would count the run as better than it was.
# Text copied from a result is stripped of em dashes, so summary.md can never carry one (owner rule).
#
# Exit: 0 written; 2 usage error, bad run id or no run.json, nothing written.
# Environment: SWEEP_RUN_DIR overrides the run dir; SWEEP_WIN_HOME overrides the Windows home lookup (sweep-lib.sh).
# Spec: docs/design/inbox-sweep.spec.xml, script `sweep-collect.sh` and node B8.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sweep-lib.sh
. "$HERE/sweep-lib.sh"

usage() { echo "usage: sweep-collect.sh --run <run-id> [--controller-error]" >&2; exit 2; }
if [ $# -lt 2 ] || [ "$1" != "--run" ]; then usage; fi
run_id="$2"
shift 2
controller_error=0
if [ $# -eq 1 ] && [ "$1" = "--controller-error" ]; then controller_error=1; elif [ $# -ne 0 ]; then usage; fi
[[ $run_id =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || { echo "sweep-collect: bad run id '$run_id'" >&2; exit 2; }

if [ -z "${SWEEP_RUN_DIR:-}" ]; then
  win_home="$(sweep_win_home)" || { echo "sweep-collect: cannot resolve the Windows home" >&2; exit 2; }
  SWEEP_RUN_DIR="$win_home/.local/state/zenith/inbox-sweep/runs/$run_id"
fi
export SWEEP_RUN_DIR
RUN="$SWEEP_RUN_DIR"
[ -f "$RUN/run.json" ] || { echo "sweep-collect: no run.json in $RUN" >&2; exit 2; }

SEAT_CODES='OK PARTIAL BLOCKED-NO-BROWSER BLOCKED-SIGNED-OUT BLOCKED-CHALLENGE BLOCKED-CONNECTOR REFUSED TIMEOUT FAILED-SEAT FAILED-SCHEMA SKIPPED'
is_seat_code() { [[ " $SEAT_CODES " == *" $1 "* ]]; }

# --- one record per seat, in run.json order --------------------------------------------------------------------------
records=()
while IFS= read -r seat_row; do
  seat="$(jq -r .seat <<<"$seat_row")"
  source_name="$(jq -r '.source // empty' <<<"$seat_row")"
  account="$(jq -r '.account // empty' <<<"$seat_row")"
  file="$RUN/results/$seat.json"
  if [ -f "$file" ] && jq -e 'type=="object" and (.status|type=="string")' "$file" >/dev/null 2>&1; then
    rec="$(jq -c --arg seat "$seat" '{seat:$seat, source:.source, account:.account, status:.status,
      before:(.counts.before.unread // null), after:(.counts.after.unread // null), processed:(.counts.processed // 0),
      flagged:([.items[]? | select(.flag != "none")] | length), items:(.items // [])}' "$file")"
  else
    st="$(jq -r '.status // empty' <<<"$seat_row")"
    is_seat_code "$st" || st=FAILED-SEAT
    rec="$(jq -cn --arg seat "$seat" --arg src "$source_name" --arg acc "$account" --arg st "$st" \
      '{seat:$seat, source:$src, account:$acc, status:$st, before:null, after:null, processed:0, flagged:0, items:[]}')"
  fi
  records+=("$rec")
done < <(jq -c '.seats[]?' "$RUN/run.json")
if [ "${#records[@]}" -gt 0 ]; then recs="$(printf '%s\n' "${records[@]}" | jq -s .)"; else recs='[]'; fi

# --- derive the run code -----------------------------------------------------------------------------------------------
pf_stop=0
if [ -f "$RUN/preflight.json" ] && jq -e '[.checks[]?.code] | any(. == "PF-NO-HERDR" or . == "PF-NO-OWNER-WORDS")' "$RUN/preflight.json" >/dev/null 2>&1; then
  pf_stop=1
fi
clean_code=""
[ -f "$RUN/proof/R7-verdict.json" ] && clean_code="$(jq -r '.code // empty' "$RUN/proof/R7-verdict.json" 2>/dev/null || true)"

status="$(jq -r --argjson ce "$controller_error" --argjson pf "$pf_stop" --arg clean "$clean_code" '
  if $ce == 1 or $pf == 1 then "RUN-FAILED"
  elif length > 0 and all(.[]; .status == "OK") and $clean == "CLEAN-OK" then "RUN-OK"
  elif any(.[]; .status == "OK") then "RUN-PARTIAL"
  elif any(.[]; .status == "SKIPPED" or (.status | startswith("BLOCKED-"))) then "RUN-BLOCKED"
  else "RUN-FAILED" end' <<<"$recs")"

finished_at="$(sweep_now)"
mkdir -p "$RUN"

# --- summary.json ----------------------------------------------------------------------------------------------------
tmp="$(mktemp "$RUN/.summary.XXXXXX")"
jq --arg run "$run_id" --arg st "$status" --arg at "$finished_at" \
  '{schema_version:"1.0.0", run_id:$run, status:$st,
    seats:map({seat, status, before, after, processed, flagged}), finished_at:$at}' <<<"$recs" >"$tmp"
mv "$tmp" "$RUN/summary.json"

# --- summary.md ------------------------------------------------------------------------------------------------------
# cell: one table cell. Pipes and newlines would break the row, and an em dash is banned, so all three are replaced.
EMDASH=$'\xe2\x80\x94'
cell() { tr '\n\r' '  ' | sed "s/|/\\\\|/g; s/$EMDASH/-/g"; }
sources="$(jq -r '[.[].source | select(. != "")] | unique | .[]' <<<"$recs")"
tmp="$(mktemp "$RUN/.summary.XXXXXX")"
{
  printf '# Inbox sweep %s\n\n' "$run_id"
  printf '## Contents\n\n- Run\n'
  for s in $sources; do printf -- '- %s\n' "$s"; done
  printf '\n## Run\n\n'
  printf 'Status: %s\n\n' "$status"
  printf 'Finished: %s\n\n' "$finished_at"
  printf '| Seat | Status | Before | After | Processed | Flagged |\n| --- | --- | --- | --- | --- | --- |\n'
  jq -r '.[] | "| \(.seat) | \(.status) | \(.before // "n/a") | \(.after // "n/a") | \(.processed) | \(.flagged) |"' <<<"$recs"
  for s in $sources; do
    printf '\n## %s\n\n' "$s"
    jq -r --arg s "$s" '.[] | select(.source == $s) | "- \(.seat) (\(.account)): \(.status)"' <<<"$recs" | sed "s/$EMDASH/-/g"
    printf '\n| Received | Seat | From | Subject | Flag | Gist |\n| --- | --- | --- | --- | --- | --- |\n'
    jq -r --arg s "$s" '[.[] | select(.source == $s) | .seat as $seat | .items[] | . + {seat:$seat}]
      | sort_by(.received_at) | reverse | .[]
      | [.received_at, .seat, .from, .subject, .flag, .gist] | @tsv' <<<"$recs" |
      while IFS=$'\t' read -r r seat from subj flag gist; do
        printf '| %s | %s | %s | %s | %s | %s |\n' "$r" "$seat" "$(cell <<<"$from")" "$(cell <<<"$subj")" "$flag" "$(cell <<<"$gist")"
      done
  done
} >"$tmp"
mv "$tmp" "$RUN/summary.md"

# --- checklist (design section 5, R5) ----------------------------------------------------------------------------------
sweep_check R5 "run status derived" "summary.json .status = $status"
n_sum="$(jq '.seats | length' "$RUN/summary.json")"
n_run="$(jq '.seats | length' "$RUN/run.json")"
sweep_check R5 "every seat counted" "summary.json seats $n_sum, run.json seats $n_run"
[ "$n_sum" = "$n_run" ] || { echo "sweep-collect: seat count differs: summary $n_sum, run.json $n_run" >&2; exit 1; }
printf '%s\n' "$status"
