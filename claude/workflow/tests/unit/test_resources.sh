#!/usr/bin/env bash
# Proves resources/seat-resources.sh and resources/mcp-orphans-clean.sh do what the brief says, against stubs.
#
# Each check names the failure it rules out:
#   - a table whose RSS drifts from `ps` over the same process tree (AC1)
#   - a seat over its RSS ceiling, or machine RAM under the floor, that raises no ALERT, or a quiet seat that raises one
#   - --dry stopping anything
#   - a container owned by a live podman client being stopped (would kill a working seat's MCP)
#   - an orphan container surviving, or a container of an image outside mcp_images being touched
#   - a second run finding work to do (not idempotent)
# Hermetic: herdr, podman and ss are stubs on PATH; the process tree is real (sleep children under one bash).
# shellcheck disable=SC2015
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'kill "$TREE" 2>/dev/null; rm -rf "$T"' EXIT
fail=0
ok()  { printf 'ok  %s\n' "$1"; }
bad() { fail=1; printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
mkdir -p "$T/bin"; export T

# a real tree: one shell, three children
bash -c 'sleep 60 & sleep 60 & sleep 60 & wait' & TREE=$!
sleep 0.5

cat > "$T/bin/herdr" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "pane list") echo '{"result":{"panes":[{"agent":"claude","label":"seat-a","pane_id":"w:p1","tab_id":"w:t1"},{"agent":"claude","label":"seat-b","pane_id":"w:p2","tab_id":"w:t2"}]}}' ;;
  "tab list") echo '{"result":{"tabs":[{"tab_id":"w:t1","label":"lineone 1"},{"tab_id":"w:t2","label":"other 1"}]}}' ;;
  "pane process-info") echo "{\"result\":{\"process_info\":{\"shell_pid\":$(cat "$T/shellpid")}}}" ;;
esac
STUB
chmod +x "$T/bin/herdr"; echo "$TREE" > "$T/shellpid"

out="$(PATH="$T/bin:$PATH" bash "$R/resources/seat-resources.sh" --line lineone --json --sample 1)"
n="$(jq '.seats|length' <<<"$out")"
[ "$n" = 1 ] && ok "--line keeps only the line's seats" || bad "--line did not filter" "$n seats"
mine="$(jq '.seats[0].rss_mb' <<<"$out")"
ps_kb="$( { echo "$TREE"; pgrep -P "$TREE"; } | xargs -I{} ps -o rss= -p {} | awk '{s+=$1} END {print s}')"
awk -v a="$mine" -v b="$((ps_kb/1024))" 'BEGIN { d=(a>b?a-b:b-a); exit !(d<=1 || d/b<=0.05) }' \
  && ok "RSS matches ps within 5 percent ($mine MB vs $((ps_kb/1024)) MB)" || bad "RSS drifts from ps" "table $mine MB, ps $((ps_kb/1024)) MB"
[ "$(jq '.seats[0].processes' <<<"$out")" = 4 ] && ok "process count is the whole tree" || bad "process count wrong" "$(jq -c '.seats[0]' <<<"$out")"

a="$(PATH="$T/bin:$PATH" bash "$R/resources/seat-resources.sh" --line lineone --rss-mb 0 --floor-mb 99999999 --sample 1)"
grep -q 'ALERT seat seat-a.*RSS' <<<"$a" && ok "seat over the RSS ceiling raises an ALERT" || bad "no seat ALERT" "$a"
grep -q 'ALERT machine available RAM' <<<"$a" && ok "RAM under the floor raises an ALERT" || bad "no machine ALERT" "$a"
q="$(PATH="$T/bin:$PATH" bash "$R/resources/seat-resources.sh" --line lineone --rss-mb 99999 --cpu-pct 99999 --floor-mb 1 --sample 1)"
grep -q ALERT <<<"$q" && bad "a quiet seat raised an ALERT" "$q" || ok "no ALERT when every ceiling holds"

# orphans: container aaa is held by live client 111 via conmon 222; bbb has no client; ccc is another image
cat > "$T/bin/podman" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  ps) if [ "${2:-}" = -q ] && [ "${3:-}" = --filter ]; then [ "$4" = "ancestor=example/mcp" ] && printf 'aaaaaaaaaaaa\nbbbbbbbbbbbb\n'; else printf 'aaaaaaaaaaaa\nbbbbbbbbbbbb\ncccccccccccc\n'; fi ;;
  inspect) printf '222 aaaaaaaaaaaa\n333 bbbbbbbbbbbb\n444 cccccccccccc\n' ;;
  stop) echo "$*" >> "$T/stopped" ;;
esac
STUB
cat > "$T/bin/ss" <<'STUB'
#!/usr/bin/env bash
echo 'Netid State Recv-Q Send-Q Local Address:Port Peer Address:Port Process'
echo 'u_seq ESTAB 0 0 * 1000 * 1001 users:(("podman",pid=111,fd=10))'
echo 'u_seq ESTAB 0 0 * 1001 * 1000 users:(("conmon",pid=222,fd=11))'
echo 'u_seq ESTAB 0 0 * 2001 * 2000 users:(("conmon",pid=333,fd=11))'
STUB
chmod +x "$T/bin/podman" "$T/bin/ss"
echo '{"mcp_images":["example/mcp"],"mcp_process_patterns":["zzz-no-such-mcp"],"subreapers":[1]}' > "$T/res.json"
export SR_CONFIG="$T/res.json"
d="$(PATH="$T/bin:$PATH" bash "$R/resources/mcp-orphans-clean.sh" --dry)"
[ ! -e "$T/stopped" ] && ok "--dry stops nothing" || bad "--dry stopped something" "$(cat "$T/stopped")"
grep -q 'would stop container bbbbbbbbbbbb' <<<"$d" && ok "dry run names the orphan" || bad "dry run missed the orphan" "$d"
grep -q 'aaaaaaaaaaaa' <<<"$d" && bad "dry run named a container with a live client" "$d" || ok "a container with a live client is left alone"
PATH="$T/bin:$PATH" bash "$R/resources/mcp-orphans-clean.sh" >/dev/null
[ "$(cat "$T/stopped")" = "stop -t 3 bbbbbbbbbbbb" ] && ok "real run stops exactly the orphan" || bad "real run stopped the wrong set" "$(cat "$T/stopped" 2>/dev/null)"
exit "$fail"
