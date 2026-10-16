#!/usr/bin/env bash
# Proves bin/herdr-grid.sh places, labels and cleans seats on the 3x3 grid, against a stub herdr and fixture layouts.
#
# Each check names the failure it rules out:
#   - a line-up that does not give the architect the whole left column, or builds fewer than 2x3 labelled free slots
#   - a seat landing out of slot order (middle top to bottom, then right), or taking a slot a seat already holds
#   - a full tab squeezing a seventh seat in instead of opening "<line> 2"
#   - seat-down closing a seat that is still working, or ever closing the architect pane
#   - line-clean leaving an emptied overflow tab open, or touching a seat of another line
#   - a herdr failure that loops forever or passes silently instead of retrying 3 times and reporting
# Hermetic: herdr is a stub on PATH. Fixtures live in $T/fx: panes.json, tabs.json, layout-<tab>.json, read-<pane>.txt.
# A && ok || bad is the house check idiom here: ok only prints, so C cannot run after a true A (SC2015 is noise).
# shellcheck disable=SC2015
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
ok()  { printf 'ok  %s\n' "$1"; }
bad() { fail=1; printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
has() { if grep -qF -- "$2" "$T/log"; then ok "$1"; else bad "$1" "missing: $2"; fi; }
hasnt() { if grep -qF -- "$2" "$T/log"; then bad "$1" "unexpected: $2"; else ok "$1"; fi; }

mkdir -p "$T/bin" "$T/fx"
cat > "$T/bin/herdr" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$T/log"
fx="$T/fx"
[ -f "$fx/fail" ] && { echo '{"error":"boom"}' >&2; exit 1; }
n=$(cat "$fx/next" 2>/dev/null || echo 100)
case "$1 $2" in
  "tab list") cat "$fx/tabs.json" ;;
  "pane list") cat "$fx/panes.json" ;;
  "pane layout")
    t=$(jq -r --arg p "$4" '.result.panes[]|select(.pane_id==$p)|.tab_id' "$fx/panes.json"); cat "$fx/layout-${t//:/_}.json" ;;
  "pane split") echo $((n+1)) > "$fx/next"; echo "{\"result\":{\"pane\":{\"pane_id\":\"wT:p$n\"}}}" ;;
  "tab create") echo $((n+2)) > "$fx/next"; echo "{\"result\":{\"tab\":{\"tab_id\":\"wT:t$n\"},\"root_pane\":{\"pane_id\":\"wT:p$((n+1))\"}}}" ;;
  "pane read") cat "$fx/read-${3//:/_}.txt" 2>/dev/null ;;
  *) echo '{"result":{"type":"ok"}}' ;;
esac
STUB
chmod +x "$T/bin/herdr"
export PATH="$T/bin:$PATH" T HERDR_ENV=1 WS=wT GRID_STATE="$T/state" GRID_RETRY_SLEEP=0 WORKFLOW_CONFIG="$R/config/project.json"
G="bash $R/bin/herdr-grid.sh"

# fixture builders: layout of tab 1 = architect | 3 | 3, with the given labels on the six seat slots
mk_tab1() { # mk_tab1 l1 l2 l3 l4 l5 l6 [agent-for-slot1]
  jq -n --args '
    ([{pane_id:"wT:pA",x:0,y:0}] + [ range(0;6) | {pane_id:"wT:p\(.+1)", x:(if . < 3 then 110 else 217 end), y:((.%3)*20)} ]) as $p
    | {result:{layout:{panes:[$p[]|{pane_id,rect:{x,y,width:100,height:20}}]}}}' > "$T/fx/layout-wT_t1.json"
  jq -n --args '$ARGS.positional as $l | {result:{panes:([{pane_id:"wT:pA",tab_id:"wT:t1",label:"architect",agent:"claude",agent_status:"idle"}]
    + [range(0;6)|{pane_id:"wT:p\(.+1)",tab_id:"wT:t1",label:$l[.],agent:(if $l[.]=="free" then null else "claude" end),agent_status:"idle"}])}}' "$@" > "$T/fx/panes.json"
  echo '{"result":{"tabs":[{"tab_id":"wT:t1","label":"L 1"},{"tab_id":"wT:t9","label":"other 1"}]}}' > "$T/fx/tabs.json"
}

# ---- line-up
echo '{"result":{"tabs":[]}}' > "$T/fx/tabs.json"; echo 100 > "$T/fx/next"; : > "$T/log"; $G line-up L >/dev/null 2>&1
has   "line-up creates tab 'L 1'"               'tab create --workspace wT --cwd'
has   "line-up labels the architect"            'pane rename wT:p101 architect'
[ "$(grep -c '^pane split' "$T/log")" = 6 ] && ok "line-up builds 6 seat slots (2 columns + 4 rows)" || bad "line-up builds 6 seat slots" "$(grep -c '^pane split' "$T/log") splits"
[ "$(grep -c 'pane rename .* free' "$T/log")" = 6 ] && ok "line-up labels every slot free" || bad "line-up labels every slot free"
has   "left column keeps 1/3, then middle keeps 1/2" '--direction right --ratio 0.3333'
has   "rows split into equal thirds"            '--direction down --ratio 0.3333'

has   "line-up starts the architect with both flags, named for the line" 'pane run wT:p101 claude --dangerously-skip-permissions --remote-control "L architect"'
hasnt "and the command has no stray text after the name" 'architect"}'

# ---- architect-up: restart and resume keep both flags; never a second agent in the pane
mk_tab1 free free free free free free
jq '(.result.panes[]|select(.label=="architect")|.agent)=null' "$T/fx/panes.json" > "$T/fx/p2" && mv "$T/fx/p2" "$T/fx/panes.json"
: > "$T/log"; $G architect-up L resume >/dev/null 2>&1
has   "resume keeps both flags and adds --continue" '--remote-control "L architect" --continue'
mk_tab1 free free free free free free
: > "$T/log"; $G architect-up L >/dev/null 2>&1; rc=$?
[ "$rc" != 0 ] && hasnt "a live architect is never started twice" 'pane run' || bad "live architect refused"

# ---- seats: bypass always, Remote Control never
mk_tab1 free free free free free free
: > "$T/log"; $G seat-up L s1 "claude --model sonnet" >/dev/null 2>&1
has   "a plain claude seat gets bypass added"   'pane run wT:p1 claude --dangerously-skip-permissions --model sonnet'
: > "$T/log"; $G seat-up L s2 "cd /mnt/c/x && /mnt/c/u/claude.exe --chrome" >/dev/null 2>&1
has   "the Windows browser seat gets bypass after the cd" 'claude.exe --dangerously-skip-permissions --chrome'
: > "$T/log"; $G seat-up L s3 "claude --dangerously-skip-permissions --remote-control x" >/dev/null 2>&1; rc=$?
[ "$rc" != 0 ] && hasnt "a seat asking for Remote Control is refused before a slot is taken" 'pane rename' || bad "seat RC refused"

# ---- seat-up: slot order, no double claim, overflow
mk_tab1 free free free free free free
: > "$T/log"; $G seat-up L alpha >/dev/null 2>&1
has "first seat takes middle top"               'pane rename wT:p1 alpha'
mk_tab1 a b free free free free
: > "$T/log"; $G seat-up L c >/dev/null 2>&1
has "third seat takes middle bottom"            'pane rename wT:p3 c'
mk_tab1 a b c free free free
: > "$T/log"; $G seat-up L d >/dev/null 2>&1
has "fourth seat starts the right column"       'pane rename wT:p4 d'
: > "$T/log"; $G seat-up L a >/dev/null 2>&1; rc=$?
[ "$rc" != 0 ] && ok "a seat name already holding a slot is refused" || bad "duplicate seat refused"
mk_tab1 a b c d e f
: > "$T/log"; $G seat-up L g >/dev/null 2>&1
has   "full tab opens 'L 2'"                    '--label L 2'
hasnt "full tab never renames a held pane"      'pane rename wT:p1 g'

# ---- seat-down: refuse unfinished, close finished, never the architect
mk_tab1 a b c free free free
printf 'working...\n' > "$T/fx/read-wT_p1.txt"
: > "$T/log"; $G seat-down a L >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok "unfinished seat is refused (exit 2)" || bad "unfinished seat refused" "rc=$rc"
hasnt "unfinished seat's pane is not closed"    'pane close wT:p1'
printf 'DONE a https://example.test/pr/1\n' > "$T/fx/read-wT_p1.txt"
: > "$T/log"; $G seat-down a L >/dev/null 2>&1
has   "finished seat's pane is closed"          'pane close wT:p1'
printf 'brief says: DONE a <pr-url>\n' > "$T/fx/read-wT_p2.txt"
: > "$T/log"; $G seat-down b L >/dev/null 2>&1
hasnt "a quoted placeholder token is not done"  'pane close wT:p2'
: > "$T/log"; FORCE=1 $G seat-down architect L >/dev/null 2>&1; rc=$?
[ "$rc" != 0 ] && hasnt "architect pane is never closed" 'pane close wT:pA' || bad "architect refused"

# ---- line-clean: closes an emptied overflow tab, ignores another line
mk_tab1 free free free free free free
echo '{"result":{"tabs":[{"tab_id":"wT:t1","label":"L 1"},{"tab_id":"wT:t2","label":"L 2"},{"tab_id":"wT:t9","label":"other 1"}]}}' > "$T/fx/tabs.json"
jq -n '{result:{layout:{panes:[range(0;3)|{pane_id:"wT:q\(.+1)",rect:{x:0,y:(.*20)}}]}}}' > "$T/fx/layout-wT_t2.json"
jq '.result.panes += [range(0;3)|{pane_id:"wT:q\(.+1)",tab_id:"wT:t2",label:"free"}]' "$T/fx/panes.json" > "$T/fx/p2" && mv "$T/fx/p2" "$T/fx/panes.json"
: > "$T/log"; $G line-clean L >/dev/null 2>&1
has   "empty overflow tab is closed"            'tab close wT:t2'
hasnt "tab 1 is never closed"                   'tab close wT:t1'
hasnt "another line's tab is untouched"         'wT:t9'

# ---- line-status: no model calls, one table
mk_tab1 a free free free free free
out="$($G line-status L 2>&1)"
grep -q 'architect' <<<"$out" && grep -q '^L 1 *1 *a ' <<<"$out" && ok "line-status prints architect and slot 1" || bad "line-status table" "$out"

# ---- retry 3 then report
touch "$T/fx/fail"; : > "$T/log"; out="$($G line-status L 2>&1)"; rc=$?
[ "$(grep -c '^tab list' "$T/log")" = 3 ] && ok "a failing herdr call is tried exactly 3 times" || bad "3 tries" "$(grep -c '^tab list' "$T/log")"
grep -q 'FAILED after 3' <<<"$out" && ok "and the failure is reported" || bad "failure reported" "$out"
rm -f "$T/fx/fail"

[ "$fail" = 0 ] && echo "ok  herdr-grid" || { echo "FAIL herdr-grid"; exit 1; }
