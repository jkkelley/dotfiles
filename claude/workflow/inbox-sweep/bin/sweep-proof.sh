#!/usr/bin/env bash
# Tab bar proof for the inbox sweep (design section 5 R2 and R7, spec script `sweep-proof.sh`, node B13).
#
#   sweep-proof.sh baseline --run <run-id>   R2: screenshot the tab bar before any seat starts
#   sweep-proof.sh verify   --run <run-id>   R7: screenshot again, compare with the baseline, write proof/R7-verdict.json
#
# Why: a browser seat's own "tab closed" is not proof (F7); the Windows screen is. screen.ps1 takes the screenshot and
# `claude -p --model haiku` reads the two images, the one judgment call in the controller (Rule 5).
#
# Verdict codes (spec codes/clean): CLEAN-OK, CLEAN-TABS-LEFT, CLEAN-ORPHAN-TAB, CLEAN-NO-PROOF.
#   - A capture that fails 3 times, a missing baseline, or a verdict that is not valid JSON after 3 reads is
#     CLEAN-NO-PROOF: the sweep says it cannot prove completion rather than guess.
#   - CLEAN-TABS-LEFT prompts every still-alive browser seat pane to close its group, anchor last, then recaptures and
#     re-reads. At most 3 rounds, so a seat is prompted at most 3 times; after that the code stays CLEAN-TABS-LEFT.
#   - CLEAN-ORPHAN-TAB adds ONE card to questions.json (the owner closes the tab by hand; no tool can, F6).
# The script exits 0 whenever it wrote a verdict, whatever the code: the controller reads proof/R7-verdict.json, and a
# non-zero exit would abort a `set -e` controller before sweep-cards.sh and sweep-clean.sh ran. 2 is a usage error.
#
# Environment:
#   SWEEP_RUN_DIR      the run directory; default <win-home>/.local/state/zenith/inbox-sweep/runs/<run-id>
#   SWEEP_POWERSHELL   default powershell.exe      SWEEP_CLAUDE  default claude
#   SWEEP_CARDS_FILE   default ~/.bearings/inbox-sweep/questions.json
#   SWEEP_RETRY_WAITS / SWEEP_SLEEP: see sweep-lib.sh
# shellcheck disable=SC2317,SC2016 # SC2317: capture_once and read_verdict_once run indirectly through sweep_retry; SC2016: jq filters use $var
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sweep-lib.sh
. "$HERE/sweep-lib.sh"

PS="${SWEEP_POWERSHELL:-powershell.exe}"
CLAUDE="${SWEEP_CLAUDE:-claude}"
CARDS="${SWEEP_CARDS_FILE:-$HOME/.bearings/inbox-sweep/questions.json}"
PROMPT_TEXT="Close your tab group now, anchor last, then exit"
usage() { echo "usage: sweep-proof.sh baseline|verify --run <run-id>" >&2; exit 2; }

if [ $# -ne 3 ] || [ "$2" != "--run" ]; then usage; fi
verb="$1" run="$3"
[[ $run =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || { echo "sweep-proof.sh: bad run id '$run'" >&2; exit 2; }
case "$verb" in baseline | verify) ;; *) usage ;; esac

if [ -z "${SWEEP_RUN_DIR:-}" ]; then
  SWEEP_RUN_DIR="$(sweep_win_home)/.local/state/zenith/inbox-sweep/runs/$run"
fi
export SWEEP_RUN_DIR
PROOF="$SWEEP_RUN_DIR/proof"
mkdir -p "$PROOF" "$SWEEP_RUN_DIR/logs"
LOG="$SWEEP_RUN_DIR/logs/proof.log"
log() { printf '%s %s\n' "$(sweep_now)" "$*" >>"$LOG"; }

# Windows path of a WSL path; hosts without wslpath (the test container) pass the path through.
winpath() { if command -v wslpath >/dev/null 2>&1; then wslpath -w "$1"; else printf '%s\n' "$1"; fi; }

# capture_once <png>: one screen.ps1 run, then the spec's pass check: non-empty and the 8 byte PNG signature.
capture_once() {
  local png="$1"
  rm -f "$png"
  "$PS" -NoProfile -ExecutionPolicy Bypass -File "$(winpath "$HERE/screen.ps1")" -Out "$(winpath "$png")" >>"$LOG" 2>&1 || return 1
  [ -s "$png" ] || return 1
  [ "$(head -c 8 "$png" | od -An -tx1 | tr -d ' \n')" = "89504e470d0a1a0a" ]
}

# capture <node> prints the PNG path on success; 3 attempts through sweep_retry, nothing left behind on failure.
capture() {
  local node="$1" stamp png n=1
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  png="$PROOF/$node-tabbar-$stamp.png"
  # Recaptures can land in the same second; a suffix keeps the earlier proof instead of overwriting it.
  while [ -e "$png" ]; do n=$((n + 1)); png="$PROOF/$node-tabbar-$stamp-$n.png"; done
  if sweep_retry 3 "proof-capture-$node" capture_once "$png"; then
    printf '%s\n' "$png"
  else
    rm -f "$png"
    return 1
  fi
}

# read_verdict <baseline> <final> prints the verdict JSON; 3 attempts, each must parse and carry a known code.
read_verdict_once() {
  local base="$1" final="$2" raw v
  raw="$("$CLAUDE" -p --model haiku --output-format json "Compare the Chrome tab bars in $base and $final. Output only JSON {code, claude_groups_open, tabs_beyond_baseline, orphan_tabs:[title]} with code one of CLEAN-OK, CLEAN-TABS-LEFT, CLEAN-ORPHAN-TAB.")" || return 1
  # The reply may wrap the JSON in prose or a code fence; take from the first { to the last }.
  v="$(printf '%s' "$raw" | jq -c '(.result // .) | if type=="string" then (sub("^[^{]*";"") | sub("[^}]*$";"") | fromjson) else . end' 2>/dev/null)" || return 1
  printf '%s' "$v" | jq -e '.code | IN("CLEAN-OK","CLEAN-TABS-LEFT","CLEAN-ORPHAN-TAB")' >/dev/null || return 1
  printf '%s\n' "$v" >"$VERDICT_TMP"
}
read_verdict() {
  VERDICT_TMP="$(mktemp "$PROOF/.verdict.XXXXXX")"
  if sweep_retry 3 "proof-verdict" read_verdict_once "$1" "$2"; then
    cat "$VERDICT_TMP"
    rm -f "$VERDICT_TMP"
  else
    rm -f "$VERDICT_TMP"
    return 1
  fi
}

# Panes of browser seats that are still alive. Gmail seats use the connector, not the browser (spec: gmail needs no
# browser), so every other source with a recorded pane counts. Alive means herdr still knows the agent, the same test
# seat-watch.sh uses.
live_browser_panes() {
  local pane
  [ -f "$SWEEP_RUN_DIR/run.json" ] || return 0
  jq -r '.seats[]? | select(.source != "gmail" and (.pane // "") != "") | .pane' "$SWEEP_RUN_DIR/run.json" |
    while IFS= read -r pane; do
      herdr agent get "$pane" >/dev/null 2>&1 && printf '%s\n' "$pane"
    done
}

# One card per run for orphan tabs; merge by id so a rerun adds nothing (spec sweep-cards.sh merge).
orphan_card() {
  local verdict="$1" id titles
  id="IS-$run-sweep-B-CLEAN-ORPHAN-TAB"
  titles="$(printf '%s' "$verdict" | jq -r '(.orphan_tabs // []) | map(tostring) | join("; ")')"
  if [ -f "$CARDS" ] && jq -e --arg id "$id" '.items | any(.id == $id)' "$CARDS" >/dev/null; then
    log "orphan card $id already present"
    return 0
  fi
  # sweep-cards.sh owns questions.json (B21e); add merges by id, so a rerun adds nothing.
  jq -cn --arg id "$id" --arg run "$run" --arg t "${titles:-none read}" '{id:$id, about:("Inbox sweep " + $run + ": CLEAN-ORPHAN-TAB"),
      decide:("A seat tab is open in Chrome outside any Claude group, so no tool can close it. Close it yourself. Tab titles: " + $t),
      options:[{label:"Closed it",then:"Orchestrator reruns sweep-proof.sh verify"},{label:"Leave it",then:"The tab stays open and the run stays not clean"}],
      rec:0}' | SWEEP_CARDS_FILE="$CARDS" bash "$HERE/sweep-cards.sh" add >/dev/null
  log "orphan card $id written"
}

write_verdict() { # <code> <json fields object> <baseline> <final> <prompts>
  local out="$PROOF/R7-verdict.json" tmp
  tmp="$(mktemp "$PROOF/.r7.XXXXXX")"
  printf '%s' "$2" | jq --arg code "$1" --arg run "$run" --arg base "$3" --arg final "$4" --argjson prompts "$5" --arg at "$(sweep_now)" \
    '. + {code:$code, run_id:$run, baseline:$base, final:$final, tabs_left_prompts:$prompts, at:$at}' >"$tmp"
  mv "$tmp" "$out"
  log "R7 verdict $1"
  printf '%s\n' "$1"
}

if [ "$verb" = baseline ]; then
  if png="$(capture R2)"; then
    log "R2 baseline $png"
    sweep_check R2 "baseline tab bar captured" "$png" || true
  else
    # The run continues without a baseline; verify then can only reach CLEAN-NO-PROOF (spec).
    log "R2 baseline capture failed 3 times"
  fi
  exit 0
fi

# verify
base="$(find "$PROOF" -maxdepth 1 -name 'R2-tabbar-*.png' | sort | tail -n 1)"
if [ -z "$base" ]; then
  write_verdict CLEAN-NO-PROOF '{"reason":"no R2 baseline"}' "" "" 0
  log "no baseline, CLEAN-NO-PROOF"
  exit 0
fi
final=""
if ! final="$(capture R7)"; then
  write_verdict CLEAN-NO-PROOF '{"reason":"screen.ps1 failed 3 times"}' "$base" "" 0
  exit 0
fi
prompts=0 round=0
while :; do
  if ! verdict="$(read_verdict "$base" "$final")"; then
    write_verdict CLEAN-NO-PROOF '{"reason":"verdict unreadable 3 times"}' "$base" "$final" "$prompts"
    exit 0
  fi
  code="$(printf '%s' "$verdict" | jq -r .code)"
  if [ "$code" = CLEAN-TABS-LEFT ] && [ "$round" -lt 3 ]; then
    round=$((round + 1))
    while IFS= read -r pane; do
      herdr agent prompt "$pane" "$PROMPT_TEXT" >/dev/null 2>&1 || true
    done < <(live_browser_panes)
    prompts=$((prompts + 1))
    # Give the seats time to close; SWEEP_SLEEP lets tests skip the wait.
    "${SWEEP_SLEEP:-sleep}" "${SWEEP_CLOSE_WAIT:-20}"
    if ! final="$(capture R7)"; then
      write_verdict CLEAN-NO-PROOF '{"reason":"recapture failed 3 times"}' "$base" "" "$prompts"
      exit 0
    fi
    continue
  fi
  break
done
[ "$code" != CLEAN-ORPHAN-TAB ] || orphan_card "$verdict"
write_verdict "$code" "$verdict" "$base" "$final" "$prompts"
sweep_check R7 "tab bar verdict" "$PROOF/R7-verdict.json $code" || true
exit 0
