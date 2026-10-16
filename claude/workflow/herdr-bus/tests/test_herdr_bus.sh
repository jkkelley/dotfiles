#!/usr/bin/env bash
# Tests herdr-bus.sh against a stub herdr (a snapshot file) and a stub nats (a log file). Intent, not just behaviour:
#   AC1 a status change is exactly one published message with the documented subject; AC2 a quiet tick publishes nothing;
#   a failed publish is retried (state is not advanced); only owner=true becomes a toast.
# shellcheck disable=SC2015  # ok and bad always return 0, so A && ok || bad is an if/else here
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0; ok() { printf 'ok   %s\n' "$1"; }; bad() { printf 'FAIL %s\n' "$1"; fail=1; }

# stub herdr: `api snapshot` prints $T/snap.json; `notification show` logs its arguments.
cat >"$T/herdr" <<STUB
#!/bin/sh
case "\$1 \$2" in
  "api snapshot") cat "$T/snap.json" ;;
  "notification show") echo "\$*" >> "$T/toast.log" ;;
esac
STUB
# stub nats: `pub` logs subject and body, or fails when $T/nats.fail exists; `consumer next` replays $T/msgs.
cat >"$T/nats" <<STUB
#!/bin/sh
shift 2
case "\$1" in
  pub) [ -e "$T/nats.fail" ] && { echo "no servers available" >&2; exit 1; }; echo "\$2 \$3" >> "$T/pub.log" ;;
  consumer) case "\$2" in info) exit 0 ;; next) cat "$T/msgs" 2>/dev/null ;; esac ;;
esac
STUB
chmod +x "$T/herdr" "$T/nats"
snap() {  # snap <status>: one agent pane
  jq -n --arg st "$1" '{result:{snapshot:{
    workspaces:[{workspace_id:"w1",label:"line"}], tabs:[{tab_id:"w1:t1",label:"line 1"}],
    agents:[{pane_id:"w1:p1",tab_id:"w1:t1",workspace_id:"w1",agent:"claude",name:"seat-a",agent_status:$st}]}}}' >"$T/snap.json"; }
run() { HB_CONFIG="$R/config.json" HB_STATE_DIR="$T/st" HERDR_BIN="$T/herdr" NATS_BIN="$T/nats" bash "$R/herdr-bus.sh" "$@"; }

snap idle
run tick >/dev/null; [ ! -e "$T/pub.log" ] && ok "first tick is a silent baseline" || bad "first tick published"
run tick >/dev/null; [ ! -e "$T/pub.log" ] && ok "AC2 quiet tick publishes nothing" || bad "quiet tick published"

snap working; run tick >/dev/null
[ "$(wc -l <"$T/pub.log")" = 1 ] && ok "AC1 one change is one message" || bad "expected 1 message, got $(wc -l <"$T/pub.log")"
grep -q '^herdr\.w1\.w1-t1\.w1-p1\.claude\.working ' "$T/pub.log" && ok "subject is herdr.<ws>.<tab>.<pane>.<agent>.<status>" || bad "subject: $(cat "$T/pub.log")"
body="$(cut -d' ' -f2- "$T/pub.log" | head -1)"
python3 -c "
import json,sys,jsonschema
jsonschema.validate(json.loads(sys.argv[1]), json.load(open(sys.argv[2])))" "$body" "$R/event.schema.json" 2>"$T/err" \
  && ok "payload validates against event.schema.json" || { bad "payload invalid: $(cat "$T/err")"; }
[ "$(jq -r .prev <<<"$body")" = idle ] && ok "payload carries the previous status" || bad "prev wrong"

run tick >/dev/null; [ "$(wc -l <"$T/pub.log")" = 1 ] && ok "tick after the change is quiet again" || bad "re-published"

# a failed publish must not advance state: the change is retried on the next tick, not lost.
snap blocked; touch "$T/nats.fail"; run tick >/dev/null 2>&1; rm "$T/nats.fail"
run tick >/dev/null
grep -q 'claude\.blocked ' "$T/pub.log" && ok "failed publish is retried next tick" || bad "blocked change lost"
[ "$(jq -r .owner <<<"$(grep 'claude.blocked ' "$T/pub.log" | cut -d' ' -f2-)")" = true ] && ok "blocked is tagged owner" || bad "blocked not owner"

# a pane that disappears is reported once as gone.
jq '.result.snapshot.agents=[]' "$T/snap.json" >"$T/s2" && mv "$T/s2" "$T/snap.json"
run tick >/dev/null; grep -q 'claude\.gone ' "$T/pub.log" && ok "closed pane is published as gone" || bad "gone missing"

# notify: only owner=true becomes a toast, the idle event is swallowed.
printf '%s\n%s\n' \
  '{"schema":"herdr-bus/event/1","owner":false,"status":"idle","agent":"claude","name":"","workspace_label":"l","tab_label":"t","pane":"p"}' \
  '{"schema":"herdr-bus/event/1","owner":true,"status":"blocked","agent":"claude","name":"seat-a","workspace_label":"l","tab_label":"t","pane":"p"}' >"$T/msgs"
HB_TEST_ONCE=1 run notify >/dev/null
[ "$(wc -l <"$T/toast.log")" = 1 ] && grep -q 'seat-a is blocked' "$T/toast.log" && ok "notify shows one toast, for the owner event only" || bad "toasts: $(cat "$T/toast.log" 2>&1)"

exit "$fail"
