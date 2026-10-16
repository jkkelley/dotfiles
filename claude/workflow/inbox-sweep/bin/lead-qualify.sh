#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# node: S2
# lead-qualify.sh - S2 (qualify) of the lead stage, build node B22.
#
#   lead-qualify.sh --run <run-id>
#
# Moves every LD-NEW row in <run dir>/leads.jsonl to LD-QUALIFIED or LD-NOT-A-FIT, with a reason, by the owner's rubric.
# The rubric is NOT in this script and is not invented here (design 17): it is read at run time from owner-words.md, from
# the section headed "Lead rubric" (any heading level), until the next heading. In it, one rule per line, optional `- `:
#   fit: <phrase>        the thread text contains the phrase (case-insensitive, literal)
#   not-a-fit: <phrase>  likewise; any not-a-fit phrase rejects the thread, whatever else it says
# A thread is LD-QUALIFIED when no not-a-fit phrase matches and, if the rubric lists any fit phrases, at least one matches.
# Otherwise LD-NOT-A-FIT. The reason names the rule that decided, or says none matched. The rubric file's sha256 goes in the
# row, so a row can be traced to the exact words it was judged by.
# No rubric section, or a section with no rules: exit 3, every row left LD-NEW. Guessing a rubric would qualify or reject
# real people by a rule the owner never gave (Bearings card D-03 is where the owner sets it).
#
# The thread text is data. It is matched against the phrases and never run, expanded or followed as an instruction.
# A LD-NOT-A-FIT lead gets no draft and no card: this script writes neither, and `lead-ledger.sh gate` refuses it to the
# drafting step. Only LD-NEW rows are touched, so a terminal or later lead is never re-judged when the rubric changes.
# Rejected: a model call per thread. Substring rules are deterministic and testable (dotfiles Rule 5); a judgment the rules
# cannot express is for the owner to put in the rubric.
#
# Output, one line per lead moved:  <lead-id> <code>
# Exit: 0 done; 2 usage; 3 precondition (no run, no leads.jsonl, no rubric).
#
# Every record written carries an integer schema_version (design 15.2); leads.jsonl rows are version 1.
# Environment: SWEEP_RUNS_ROOT as lead-ledger.sh; SWEEP_OWNER_WORDS default ~/.config/zenith/inbox-sweep/owner-words.md
# Design: docs/design/inbox-sweep.md section 17, spec lead-stage S2 and build node B22.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sweep-lib.sh
. "$HERE/sweep-lib.sh"

if [ $# -ne 2 ] || [ "$1" != --run ]; then echo "usage: lead-qualify.sh --run <run-id>" >&2; exit 2; fi
run="$2"
[[ $run =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || { echo "lead-qualify: bad run id '$run'" >&2; exit 2; }
root="${SWEEP_RUNS_ROOT:-$(sweep_win_home)/.local/state/zenith/inbox-sweep/runs}"
RUN_DIR="$root/$run"
LEADS="$RUN_DIR/leads.jsonl"
OWNER_FILE="${SWEEP_OWNER_WORDS:-$HOME/.config/zenith/inbox-sweep/owner-words.md}"
[ -f "$LEADS" ] || { echo "lead-qualify: no leads.jsonl in $RUN_DIR" >&2; exit 3; }
[ -s "$OWNER_FILE" ] || { echo "lead-qualify: $OWNER_FILE is missing or empty" >&2; exit 3; }
export SWEEP_RUN_DIR="$RUN_DIR"
mkdir -p "$RUN_DIR/logs"
log() { printf '%s %s\n' "$(sweep_now)" "$*" >>"$RUN_DIR/logs/lead-qualify.log"; }
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# The rubric section: from a heading containing "Lead rubric" to the next heading.
awk 'tolower($0) ~ /^#+[[:space:]]*lead rubric/ { on = 1; next } /^#/ { on = 0 } on' "$OWNER_FILE" \
  | sed -nE 's/^[-*]?[[:space:]]*(not-a-fit|fit)[[:space:]]*:[[:space:]]*(.*[^[:space:]])[[:space:]]*$/\1\t\2/p' >"$SCRATCH/rules.tsv"
if [ ! -s "$SCRATCH/rules.tsv" ]; then
  echo "lead-qualify: no 'Lead rubric' rules in $OWNER_FILE; leads stay LD-NEW until the owner sets one (Bearings card D-03)" >&2
  log "no rubric in $OWNER_FILE; nothing qualified"
  exit 3
fi
rubric_sha="$(sha256sum "$OWNER_FILE" | cut -d' ' -f1)"
has_fit="$(awk -F'\t' '$1 == "fit" { print "y"; exit }' "$SCRATCH/rules.tsv")"

# decide <text file>: prints "<code>\t<reason>"
decide() {
  local kind phrase
  while IFS=$'\t' read -r kind phrase; do
    [ "$kind" = not-a-fit ] || continue
    if grep -qiF -- "$phrase" "$1"; then printf 'LD-NOT-A-FIT\tmatched rubric not-a-fit rule: %s\n' "$phrase"; return; fi
  done <"$SCRATCH/rules.tsv"
  if [ -n "$has_fit" ]; then
    while IFS=$'\t' read -r kind phrase; do
      [ "$kind" = fit ] || continue
      if grep -qiF -- "$phrase" "$1"; then printf 'LD-QUALIFIED\tmatched rubric fit rule: %s\n' "$phrase"; return; fi
    done <"$SCRATCH/rules.tsv"
    printf 'LD-NOT-A-FIT\tno rubric fit rule matched\n'
  else
    printf 'LD-QUALIFIED\tno rubric not-a-fit rule matched\n'
  fi
}

: >"$SCRATCH/out.jsonl"
: >"$SCRATCH/moved.txt"
while IFS= read -r row; do
  [ -n "$row" ] || continue
  if [ "$(jq -r .code <<<"$row")" = LD-NEW ]; then
    id="$(jq -r .lead_id <<<"$row")"
    jq -j .text <<<"$row" >"$SCRATCH/text"
    IFS=$'\t' read -r code reason < <(decide "$SCRATCH/text")
    row="$(jq -c --arg c "$code" --arg r "$reason" --arg s "$rubric_sha" --arg at "$(sweep_now)" \
      '.code = $c | .reason = $r | .rubric_sha256 = $s | .updated_at = $at' <<<"$row")"
    printf '%s %s\n' "$id" "$code" >>"$SCRATCH/moved.txt"
    log "$id: $code ($reason)"
  fi
  printf '%s\n' "$row" >>"$SCRATCH/out.jsonl"
done <"$LEADS"

# leads.jsonl has one writer (design 18, R3, node B21d): lead-ledger.sh. Unchanged rows are no-ops there.
bash "$HERE/lead-ledger.sh" append --run "$run" <"$SCRATCH/out.jsonl"
cat "$SCRATCH/moved.txt"
sweep_check S2 "Rubric read from the owner's file, never inlined" "rubric sha256 $rubric_sha from $(basename "$OWNER_FILE")"
sweep_check S2 "A reason recorded for every outcome" "$(jq -s '[.[] | select(.code == "LD-QUALIFIED" or .code == "LD-NOT-A-FIT") | select((.reason // "") == "")] | length' "$LEADS") rows without a reason"
