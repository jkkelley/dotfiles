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
    [ -f "$fx/slow" ] && sleep 0.3
    t=$(jq -r --arg p "$4" '.result.panes[]|select(.pane_id==$p)|.tab_id' "$fx/panes.json"); cat "$fx/layout-${t//:/_}.json" ;;
  "pane split") echo $((n+1)) > "$fx/next"; echo "{\"result\":{\"pane\":{\"pane_id\":\"wT:p$n\"}}}" ;;
  "tab create") echo $((n+2)) > "$fx/next"; echo "{\"result\":{\"tab\":{\"tab_id\":\"wT:t$n\"},\"root_pane\":{\"pane_id\":\"wT:p$((n+1))\"}}}" ;;
  "agent list") echo '{"result":{"agents":[{"pane_id":"wT:y2","name":"s9"}]}}' ;;
  "agent wait") [ -f "$fx/working" ] && [[ "$*" != *"--until working"* ]] && exit 1; echo '{"result":{"type":"ok"}}' ;;
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
has   "a plain claude seat gets bypass added"   '&& claude --dangerously-skip-permissions --model sonnet'
: > "$T/log"; $G seat-up L s2 "cd /mnt/c/x && /mnt/c/u/claude.exe --chrome" >/dev/null 2>&1
has   "the Windows browser seat gets bypass after the cd" 'claude.exe --dangerously-skip-permissions --chrome'
: > "$T/log"; $G seat-up L s3 "claude --dangerously-skip-permissions --remote-control x" >/dev/null 2>&1; rc=$?
[ "$rc" != 0 ] && hasnt "a seat asking for Remote Control is refused before a slot is taken" 'pane rename' || bad "seat RC refused"

# ---- seat-up with free slots in more than one tab: find_free must not die of SIGPIPE after printing the first hit
# (live bug 2026-10-16T04:33Z: seat-up exit 1 with a free slot present). The stub is slow so head has quit before the next tab.
mk_tab1 a free free free free free
echo '{"result":{"tabs":[{"tab_id":"wT:t1","label":"L 1"},{"tab_id":"wT:t2","label":"L 2"},{"tab_id":"wT:t3","label":"L 3"}]}}' > "$T/fx/tabs.json"
for tt in t2:q t3:r; do IFS=: read -r id pfx <<<"$tt"
  jq -n --arg p "wT:${pfx}1" '{result:{layout:{panes:[{pane_id:$p,rect:{x:0,y:0}}]}}}' > "$T/fx/layout-wT_$id.json"
  jq --arg id "wT:$id" --arg p "wT:${pfx}1" '.result.panes += [{pane_id:$p,tab_id:$id,label:"free"}]' "$T/fx/panes.json" > "$T/fx/p2" && mv "$T/fx/p2" "$T/fx/panes.json"
done
touch "$T/fx/slow"; : > "$T/log"; $G seat-up L zed >/dev/null 2>&1; rc=$?; rm -f "$T/fx/slow"
[ "$rc" = 0 ] && ok "seat-up succeeds with free slots in several tabs" || bad "seat-up with several free tabs" "rc=$rc"
has "and takes the first free slot of the first tab" 'pane rename wT:p2 zed'

# ---- a prompted seat is working at once (live bug 2026-10-16T05:42Z, stuck-watch-2): seat-up must wait on idle or working
mk_tab1 free free free free free free
touch "$T/fx/working"; rm -f "$T/state/L/pw.agent-seen"; : > "$T/log"; $G seat-up L pw "claude -p go" >/dev/null 2>&1; rc=$?; rm -f "$T/fx/working"
[ "$rc" = 0 ] && [ -f "$T/state/L/pw.agent-seen" ] && ok "seat-up with a prompted seat that is working exits 0 and writes agent-seen" || bad "seat-up with a prompted seat that is working exits 0 and writes agent-seen" "rc=$rc"

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

# ---- seat-down of a seat that holds no slot (live 2026-10-16T05:28Z: seat-down treehouse-seats -> exit 1)
# s9 is the stub's agent name for wT:y2, a pane in a tab outside the grid; a gone seat is exit 0; the architect is still refused
mk_tab1 a b c free free free
echo '{"result":{"tabs":[{"tab_id":"wT:t1","label":"L 1"},{"tab_id":"wT:t5","label":"scratch"}]}}' > "$T/fx/tabs.json"
jq '.result.panes += [{pane_id:"wT:y2",tab_id:"wT:t5",label:"",agent:"claude",agent_status:"idle"},
  {pane_id:"wT:wc",tab_id:"wT:t5",label:"watch-compact-wT-y2",agent:null}]' "$T/fx/panes.json" > "$T/fx/p2" && mv "$T/fx/p2" "$T/fx/panes.json"
printf 'working...\n' > "$T/fx/read-wT_y2.txt"
: > "$T/log"; $G seat-down s9 L >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && hasnt "an unregistered seat still working is refused, not closed" 'pane close wT:y2' || bad "unregistered unfinished" "rc=$rc"
printf 'DONE s9 https://example.test/pr/9\n' > "$T/fx/read-wT_y2.txt"
: > "$T/log"; $G seat-down s9 L >/dev/null 2>&1; rc=$?
[ "$rc" = 0 ] && ok "seat-down of an unregistered seat exits 0" || bad "unregistered seat-down exit" "rc=$rc"
has   "and closes it, found by its herdr agent name" 'pane close wT:y2'
has   "and closes its watcher pane in the same call" 'pane close wT:wc'
: > "$T/log"; $G seat-down nobody L >/dev/null 2>&1; rc=$?
[ "$rc" = 0 ] && hasnt "a seat that is already gone is exit 0 and closes nothing" 'pane close' || bad "gone seat exit" "rc=$rc"
mk_tab1 a b c free free free
jq '.result.panes += [{pane_id:"wT:wd",tab_id:"wT:t1",label:"watch-seat-wT-p1",agent:null}]' "$T/fx/panes.json" > "$T/fx/p2" && mv "$T/fx/p2" "$T/fx/panes.json"
printf 'DONE a https://example.test/pr/1\n' > "$T/fx/read-wT_p1.txt"
: > "$T/log"; $G seat-down a L >/dev/null 2>&1
has   "a registered seat's watchers close with it" 'pane close wT:wd'

# ---- adopt-named: a named agent pane outside every grid tab takes the next free slot; grid, monitor and watcher tabs are left
mk_tab1 a free free free free free
echo '{"result":{"tabs":[{"tab_id":"wT:t1","label":"L 1"},{"tab_id":"wT:t5","label":"scratch"},{"tab_id":"wT:t6","label":"L monitor"},{"tab_id":"wT:t7","label":"L watchers"},{"tab_id":"wT:t9","label":"other 1"}]}}' > "$T/fx/tabs.json"
jq '.result.panes += [{pane_id:"wT:y2",tab_id:"wT:t5",label:"",agent:"claude",agent_status:"idle"},
  {pane_id:"wT:y3",tab_id:"wT:t5",label:"",agent:null},
  {pane_id:"wT:y4",tab_id:"wT:t6",label:"sweep",agent:"claude"},
  {pane_id:"wT:y5",tab_id:"wT:t7",label:"watch-compact-wT-p1",agent:"claude"},
  {pane_id:"wT:y6",tab_id:"wT:t9",label:"stranger",agent:"claude"},
  {pane_id:"wT:y7",tab_id:"wT:t5",label:"free 1.1",agent:"claude"}]' "$T/fx/panes.json" > "$T/fx/p2" && mv "$T/fx/p2" "$T/fx/panes.json"
: > "$T/log"; $G adopt-named L >/dev/null 2>&1; rc=$?
[ "$rc" = 0 ] && ok "adopt-named exits 0" || bad "adopt-named exit" "rc=$rc"
has   "the named pane moves onto the first free slot" 'pane move wT:y2 --tab wT:t1 --split down --target-pane wT:p2'
has   "the free shell it replaced closes"            'pane close wT:p2'
has   "the pane is labelled and the agent named for the seat" 'pane rename wT:y2 s9'
for q in y3 y4 y5 y6 y7; do hasnt "pane $q (no agent, monitor, watcher, other line, free) is not adopted" "pane move wT:$q"; done
mk_tab1 a s9 free free free free
: > "$T/log"; $G adopt-named L >/dev/null 2>&1
hasnt "adopting again is a no-op once the seat holds a slot" 'pane move'

# ---- line-clean: closes an emptied overflow tab, ignores another line
mk_tab1 free free free free free free
echo '{"result":{"tabs":[{"tab_id":"wT:t1","label":"L 1"},{"tab_id":"wT:t2","label":"L 2"},{"tab_id":"wT:t9","label":"other 1"}]}}' > "$T/fx/tabs.json"
jq -n '{result:{layout:{panes:[range(0;3)|{pane_id:"wT:q\(.+1)",rect:{x:0,y:(.*20)}}]}}}' > "$T/fx/layout-wT_t2.json"
jq '.result.panes += [range(0;3)|{pane_id:"wT:q\(.+1)",tab_id:"wT:t2",label:"free"}]' "$T/fx/panes.json" > "$T/fx/p2" && mv "$T/fx/p2" "$T/fx/panes.json"
: > "$T/log"; $G line-clean L >/dev/null 2>&1
has   "empty overflow tab is closed"            'tab close wT:t2'
hasnt "tab 1 is never closed"                   'tab close wT:t1'
hasnt "another line's tab is untouched"         'wT:t9'

# ---- line-reconcile: two tabs both labelled "L 2" and a hole in tab 1 become unique numbered tabs, no seat closed
mk_tab1 a b c d e free
echo '{"result":{"tabs":[{"tab_id":"wT:t1","label":"L 1"},{"tab_id":"wT:t2","label":"L 2"},{"tab_id":"wT:t3","label":"L 2"},{"tab_id":"wT:t4","label":"L stash"}]}}' > "$T/fx/tabs.json"
for tt in t2:x:s7 t3:y:s8 t4:z:; do IFS=: read -r id pfx nm <<<"$tt"
  jq -n --arg p "wT:${pfx}1" '{result:{layout:{panes:[{pane_id:$p,rect:{x:0,y:0}}]}}}' > "$T/fx/layout-wT_$id.json"
  jq --arg id "wT:$id" --arg p "wT:${pfx}1" --arg nm "$nm" '.result.panes += [{pane_id:$p,tab_id:$id,label:$nm,agent:(if $nm=="" then null else "claude" end)}]' "$T/fx/panes.json" > "$T/fx/p2" && mv "$T/fx/p2" "$T/fx/panes.json"
done
: > "$T/log"; $G line-reconcile L >/dev/null 2>&1
has   "reconcile renames the duplicate tabs out of the numbering" 'tab rename wT:t2 L old-0'
has   "reconcile fills tab 1's hole with the first overflow seat"   'pane move wT:x1 --tab wT:t1'
hasnt "reconcile never closes a seat's pane"                       'pane close wT:x1'
hasnt "reconcile never closes the second seat's pane"              'pane close wT:y1'
# an unlabeled agent pane is found by its agent name and moved too (read ate the empty label field once)
jq --arg id wT:t3 '.result.panes += [{pane_id:"wT:y2",tab_id:$id,label:"",agent:"claude"}]' "$T/fx/panes.json" > "$T/fx/p2" && mv "$T/fx/p2" "$T/fx/panes.json"
jq '.result.layout.panes += [{pane_id:"wT:y2",rect:{x:0,y:20}}]' "$T/fx/layout-wT_t3.json" > "$T/fx/p2" && mv "$T/fx/p2" "$T/fx/layout-wT_t3.json"
: > "$T/log"; $G line-reconcile L >/dev/null 2>&1
has   "reconcile finds an unlabeled agent pane by agent name" 'pane rename wT:y2 s9'
# with tab 1 full, the overflow seats get fresh numbered tabs (the stub is stateless, so tab 1 is rewritten full)
jq '(.result.panes[]|select(.label=="free" and .tab_id=="wT:t1")|.label)="f"' "$T/fx/panes.json" > "$T/fx/p2" && mv "$T/fx/p2" "$T/fx/panes.json"
: > "$T/log"; $G line-reconcile L >/dev/null 2>&1
has   "reconcile gives overflow seats a fresh numbered tab"         'pane move wT:x1 --new-tab --workspace wT --label L 2'

# ---- line-status: no model calls, one table
mk_tab1 a free free free free free
out="$($G line-status L 2>&1)"
grep -q 'architect' <<<"$out" && grep -q '^L 1 *1 *a ' <<<"$out" && ok "line-status prints architect and slot 1" || bad "line-status table" "$out"

# ---- retry 3 then report
touch "$T/fx/fail"; : > "$T/log"; out="$($G line-status L 2>&1)"; rc=$?
[ "$(grep -c '^tab list' "$T/log")" = 3 ] && ok "a failing herdr call is tried exactly 3 times" || bad "3 tries" "$(grep -c '^tab list' "$T/log")"
grep -q 'FAILED after 3' <<<"$out" && ok "and the failure is reported" || bad "failure reported" "$out"
rm -f "$T/fx/fail"

# ---- seat-down gives back the treehouse slot the seat leased, pinned to the holder, never with --force
mk_tab1 a b c free free free
printf 'DONE a https://example.test/pr/1\n' > "$T/fx/read-wT_p1.txt"
git init -q "$T/repo"
cat > "$T/bin/treehouse" <<'STUB'
#!/usr/bin/env bash
printf 'treehouse %s\n' "$*" >> "$T/log"
case "$1" in
  status) printf '[{"name":"1","path":"/slot/1","lease_holder":"a"},{"name":"2","path":"/slot/2","lease_holder":"zz"}]\n' ;;
  return) [ -f "$T/fx/th-dirty" ] && { echo 'uncommitted changes' >&2; exit 1; }; exit 0 ;;
esac
STUB
chmod +x "$T/bin/treehouse"
: > "$T/log"; WF_REPO="$T/repo" $G seat-down a L >/dev/null 2>&1; rc=$?
has   "seat-down returns the slot leased to the seat"     'treehouse return /slot/1 --if-lease-holder a'
hasnt "seat-down never forces a return (uncommitted work)" '--force'
hasnt "seat-down never returns another holder's slot"     '/slot/2'
[ "$rc" = 0 ] && ok "seat-down with its slot returned exits 0" || bad "slot returned exit 0" "rc=$rc"
touch "$T/fx/th-dirty"
: > "$T/log"; WF_REPO="$T/repo" $G seat-down a L >/dev/null 2>&1; rc=$?
[ "$rc" = 1 ] && ok "a slot that will not return is reported (exit 1), never forced" || bad "dirty slot exit 1" "rc=$rc"
rm -f "$T/fx/th-dirty"
: > "$T/log"; FORCE=1 WF_REPO="$T/repo" $G seat-down c L >/dev/null 2>&1
hasnt "a seat with no lease triggers no return"           'treehouse return'
rm -f "$T/bin/treehouse"

# ---- seat-up exports a per-seat TMPDIR the seat can write; seat-down removes it (WO-20261016-a36a, ORD-1150 T1)
export GRID_SEAT_TMP="$T/seat-tmp"
mk_tab1 free free free free free free
: > "$T/log"; $G seat-up L tq "bash -c 'test -w \"\$TMPDIR\" && echo TMPOK=\$TMPDIR'" >/dev/null 2>&1
has "seat-up passes TMPDIR to the seat" 'export TMPDIR='
runcmd="$(grep -F 'pane run ' "$T/log" | head -1 | sed 's/^pane run [^ ]* //')"
out="$(bash -c "$runcmd" 2>&1)"
[ "$out" = "TMPOK=$T/seat-tmp/L/tq" ] && [ -d "$T/seat-tmp/L/tq" ] && ok "seat-up exports TMPDIR and the seat can write it" || bad "seat-up exports TMPDIR and the seat can write it" "out=$out"
mk_tab1 tq free free free free free
FORCE=1 $G seat-down tq L >/dev/null 2>&1
[ ! -e "$T/seat-tmp/L/tq" ] && ok "seat-down removes the seat TMPDIR" || bad "seat-down removes the seat TMPDIR"
unset GRID_SEAT_TMP

[ "$fail" = 0 ] && echo "ok  herdr-grid" || { echo "FAIL herdr-grid"; exit 1; }
