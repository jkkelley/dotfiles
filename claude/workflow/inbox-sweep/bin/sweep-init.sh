#!/usr/bin/env bash
# R1 init: validates the config, refuses without the owner's words, creates the run dir, run.json and one rendered
# brief per enabled seat, repoints `latest`, and prints the run id on stdout (nothing else goes to stdout).
#
#   sweep-init.sh --seats all|gmail|proton|linkedin
#
# Exit codes (spec codes/exit-codes): 0 run created; 1 failed, nothing usable left behind; 2 usage; 3 precondition
# refused (PF-NO-OWNER-WORDS), in which case nothing at all was written.
#
# Environment, all optional; tests set them so no real mailbox config or Windows home is read:
#   SWEEP_CONFIG       default ~/.config/zenith/inbox-sweep/config.json
#   SWEEP_OWNER_WORDS  default ~/.config/zenith/inbox-sweep/owner-words.md
#   SWEEP_RUNS_ROOT    default <win-home>/.local/state/zenith/inbox-sweep/runs
#   SWEEP_LATEST       default ~/.local/state/zenith/inbox-sweep/latest
#   SWEEP_WIN_HOME     see sweep-lib.sh
#
# Design: docs/design/inbox-sweep.md section 5 node R1 and spec node `scripts` / `sweep-init.sh`.
set -euo pipefail
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWEEP="$(cd "$BIN/.." && pwd)"
# shellcheck source=sweep-lib.sh
. "$BIN/sweep-lib.sh"

usage() { echo "usage: sweep-init.sh --seats all|gmail|proton|linkedin" >&2; exit 2; }
if [ $# -ne 2 ] || [ "$1" != "--seats" ]; then usage; fi
case "$2" in all | gmail | proton | linkedin) which="$2" ;; *) usage ;; esac

CONFIG="${SWEEP_CONFIG:-$HOME/.config/zenith/inbox-sweep/config.json}"
OWNER_FILE="${SWEEP_OWNER_WORDS:-$HOME/.config/zenith/inbox-sweep/owner-words.md}"
LATEST="${SWEEP_LATEST:-$HOME/.local/state/zenith/inbox-sweep/latest}"
SEAT_DEADLINE_MINUTES=40 # spec thresholds seat-deadline-minutes

# Owner words first. They gate everything, and a run that stops here must leave no run dir behind (F3: seats given
# no owner text improvised). `grep -q '[^[:space:]]'` treats a whitespace-only file as empty, which it is.
if [ ! -f "$OWNER_FILE" ] || ! grep -q '[^[:space:]]' "$OWNER_FILE"; then
  echo "PF-NO-OWNER-WORDS: $OWNER_FILE is missing or empty; no run created" >&2
  exit 3
fi

[ -f "$CONFIG" ] || { echo "sweep-init: no config at $CONFIG" >&2; exit 1; }
if ! verr="$("$SWEEP/../tools/validate-schema.sh" "$SWEEP/schemas/config.schema.json" "$CONFIG" 2>&1)"; then
  printf 'sweep-init: config does not validate against config.schema.json:\n%s\n' "$verr" >&2
  exit 1
fi

# Seat table: name, source, account text for the brief, account label for run.json, template. One TSV row per seat.
# A Proton seat's brief names the address because the seat must open that mailbox; the config schema notes addresses
# appear only in run dirs, which `make prune` removes.
seat_rows="$(jq -r --arg which "$which" '
  def want($s): $which == "all" or $which == $s;
  ( if .gmail.enabled and want("gmail") then ["gmail","gmail",(.gmail.account // "default"),(.gmail.account // "default"),"brief-gmail.md"] else empty end ),
  ( if .proton.enabled and want("proton") then (.proton.accounts[] | ["proton-" + .label,"proton",(.label + " (" + .address + ")"),.label,"brief-proton.md"]) else empty end ),
  ( if .linkedin.enabled and want("linkedin") then ["linkedin","linkedin","n/a","n/a","brief-linkedin.md"] else empty end )
  | @tsv' "$CONFIG")"
if [ -z "$seat_rows" ]; then
  echo "sweep-init: no enabled seat matches --seats $which; no run created" >&2
  exit 1
fi

RUNS_ROOT="${SWEEP_RUNS_ROOT:-}"
if [ -z "$RUNS_ROOT" ]; then
  win_home="$(sweep_win_home)" || { echo "PF-NO-CLAUDE-EXE: cannot resolve the Windows home" >&2; exit 1; }
  RUNS_ROOT="$win_home/.local/state/zenith/inbox-sweep/runs"
else
  win_home="${SWEEP_WIN_HOME:-}"
fi

# Checked before the run dir exists so a refusal leaves nothing behind. The copy itself happens after the mkdir below.
shopt -s nullglob
node_files=("$SWEEP"/nodes/*.node.json)
shopt -u nullglob
if [ ${#node_files[@]} -eq 0 ]; then
  echo "sweep-init: no node declarations in $SWEEP/nodes; refusing to start a run that pins nothing" >&2
  exit 1
fi

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$RUNS_ROOT/$RUN_ID"
mkdir -p "$RUNS_ROOT"
# No -p: two inits inside one second would share an id, and the second must fail loudly instead of writing into the first's dir.
mkdir "$RUN_DIR" || { echo "sweep-init: run dir $RUN_DIR already exists (two inits in one second)" >&2; exit 1; }
mkdir "$RUN_DIR/results" "$RUN_DIR/logs" "$RUN_DIR/briefs"
export SWEEP_RUN_DIR="$RUN_DIR"
# Pin the node declarations (design section 15.3): the run reads nodes.lock/ from here on, so editing nodes/ while it
# runs changes the next run and never this one. All declarations are copied, R, L and S, because a reply send started
# from this run's cards must finish on the versions the run began with; the spec says "the ones it needs" and the
# reply nodes are needed by the cards R6 raises. A run with no declarations is refused: an empty lock pins nothing.
mkdir "$RUN_DIR/nodes.lock"
cp "${node_files[@]}" "$RUN_DIR/nodes.lock/"
NODE_VERSIONS="$(jq -n '[inputs | {(.id): .version}] | add' "$RUN_DIR"/nodes.lock/*.node.json)"
LOG="$RUN_DIR/logs/init.log"

DEADLINE_AT="$(date -u -d "+${SEAT_DEADLINE_MINUTES} minutes" +%Y-%m-%dT%H:%M:%SZ)"
OWNER_SHA="$(sha256sum "$OWNER_FILE" | cut -d' ' -f1)"
# Not `.mark_read // true`: jq's // treats false as absent, so an owner who set mark_read false would get true, and
# marking read is the one mutation a seat may make (design D1).
MARK_READ="$(jq -r 'if has("mark_read") then .mark_read else true end | tostring' "$CONFIG")"

jq -n --arg id "$RUN_ID" --arg at "$(sweep_now)" --arg sha "$OWNER_SHA" --arg win "$win_home" --arg dl "$DEADLINE_AT" --argjson nv "$NODE_VERSIONS" \
  --rawfile rows <(printf '%s\n' "$seat_rows") '
  { schema_version: "1.0.0", run_id: $id, status: "RUN-RUNNING",
    seats: ($rows | split("\n") | map(select(length > 0) | split("\t")
      | {seat: .[0], source: .[1], account: .[3], status: "RUN-RUNNING", pane: null, deadline_at: $dl, attempts: 0})),
    win_home: $win, owner_words_sha256: $sha, node_versions: $nv, started_at: $at, finished_at: null, cleaned_at: null, steps: [] }' \
  >"$RUN_DIR/run.json"

{
  echo "init $RUN_ID at $(sweep_now)"
  echo "config $CONFIG validated by validate-schema.sh, exit 0"
  echo "nodes.lock holds ${#node_files[@]} declarations, versions in run.json node_versions"
} >"$LOG"
sweep_check R1 "config validates" "validator exit 0, see logs/init.log"
sweep_check R1 "owner words present" "run.json owner_words_sha256 $OWNER_SHA"

# The owner's words go in verbatim, led by the date of the file in UTC so a seat can tell how fresh the instruction is.
OWNER_WORDS="Dated (UTC): $(date -u -r "$OWNER_FILE" +%Y-%m-%dT%H:%M:%SZ)
$(cat "$OWNER_FILE")"
export RUN_ID DEADLINE_AT MARK_READ OWNER_WORDS
# Browser seats run in Windows claude.exe, which needs Windows paths; wslpath is absent off WSL, where the plain path is all there is.
to_seat_path() { if [ "$1" = browser ] && command -v wslpath >/dev/null 2>&1; then wslpath -w "$2"; else printf '%s\n' "$2"; fi; }
# shellcheck disable=SC2016 # envsubst wants the literal ${NAME} list, so that no other \$ in a template is touched
VARS='${RUN_ID} ${SEAT} ${ACCOUNT} ${DEADLINE_AT} ${RESULT_PATH} ${SCHEMA_PATH} ${MARK_READ} ${OWNER_WORDS}'

count=0
while IFS=$'\t' read -r seat source account _label template; do
  kind=wsl
  [ "$source" = gmail ] || kind=browser
  SEAT="$seat" ACCOUNT="$account" \
    RESULT_PATH="$(to_seat_path "$kind" "$RUN_DIR/results/$seat.json")" \
    SCHEMA_PATH="$(to_seat_path "$kind" "$SWEEP/schemas/result.schema.json")" \
    envsubst "$VARS" <"$SWEEP/templates/$template" >"$RUN_DIR/briefs/$seat.md"
  count=$((count + 1))
done <<<"$seat_rows"

# Proof for "one brief per enabled seat, each containing the owner words block": the opening-tag count over all briefs
# must equal the seat count, so a template that lost the block is caught here and not by a seat improvising.
tagged="$(cat "$RUN_DIR"/briefs/*.md | grep -c '^<owner-words>$' || true)"
if [ "$tagged" != "$count" ]; then
  echo "sweep-init: $tagged owner-words blocks in $count briefs; refusing to start" >&2
  echo "owner-words blocks $tagged != seats $count" >>"$LOG"
  exit 1
fi
echo "owner-words blocks $tagged equals seats $count" >>"$LOG"
sweep_check R1 "one brief per enabled seat with owner words" "grep -c owner-words equals seat count $count, see logs/init.log"

mkdir -p "$(dirname "$LATEST")"
ln -sfn "$RUN_DIR" "$LATEST"
printf '%s\n' "$RUN_ID"
