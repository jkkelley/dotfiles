#!/usr/bin/env bash
# name: test_bus_health.sh
# purpose: prove bus.sh health maps podman healthcheck results to HEALTHY, UNHEALTHY, ABSENT or HEALTHCHECK-NOT-RUN and publishes each
# inputs: none; podman and BUS_NATS are stubbed on PATH
# outputs: ok/FAIL lines on stdout, exit 0 when all pass
# writes-to: a mktemp scratch dir only
# cleanup: removes its scratch dir on exit
# Proves a failing healthcheck reads UNHEALTHY within one health call (exit 3, one pub of that code), rc 0 HEALTHY exit 0,
# rc 125 HEALTHCHECK-NOT-RUN, a missing container ABSENT, and status health= comes from the check, not State.Health.
# Hermetic: podman and nats are stubs on PATH driven by $T/hc.rc and $T/exists; no container is started, no bus is touched.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
ok()  { printf 'ok  %s\n' "$1"; }
bad() { fail=1; printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
mkdir -p "$T/bin"
cat > "$T/bin/podman" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  container) [ "$(cat "$T/exists")" = yes ] ;;
  healthcheck) exit "$(cat "$T/hc.rc")" ;;
  inspect) case "$*" in *Running*) echo true ;; *Health*) echo healthy ;; *) echo running ;; esac ;;
  exec) echo '"ok"' ;;
esac
STUB
cat > "$T/bin/nats" <<'STUB'
#!/usr/bin/env bash
case "$*" in *" pub "*) echo "$*" >> "$T/pub.log" ;; esac
exit 0
STUB
chmod +x "$T/bin/podman" "$T/bin/nats"; export T
jq --arg s "$T/store" '.bus.store=$s' "$R/config/line-watch.json" > "$T/cfg.json"

run() { # $1 healthcheck rc, $2 container exists yes|no, $3 verb
  echo "$1" > "$T/hc.rc"; echo "$2" > "$T/exists"; : > "$T/pub.log"
  PATH="$T/bin:$PATH" LW_BUS="$T/cfg.json" BUS_NATS="$T/bin/nats" BUS_RETRY_SLEEP=0 LINE=test bash "$R/bin/bus.sh" "${3:-health}" >"$T/out" 2>&1
}

run 1 yes; rc=$?
if [ "$rc" = 3 ] && grep -qx 'UNHEALTHY zenith-nats' "$T/out" && [ "$(grep -c 'status_code":"UNHEALTHY' "$T/pub.log")" = 1 ] \
   && grep -q 'line.test.health.zenith-nats' "$T/pub.log"; then ok "failing check reads UNHEALTHY, exit 3, one pub"
else bad "UNHEALTHY" "rc=$rc" "$(cat "$T/out")" "$(cat "$T/pub.log")"; fi

run 0 yes; rc=$?
if [ "$rc" = 0 ] && grep -qx 'HEALTHY zenith-nats' "$T/out" && grep -q 'status_code":"HEALTHY' "$T/pub.log"; then ok "passing check reads HEALTHY, exit 0"
else bad "HEALTHY" "rc=$rc" "$(cat "$T/out")"; fi

run 125 yes; rc=$?
if [ "$rc" = 3 ] && grep -qx 'HEALTHCHECK-NOT-RUN zenith-nats' "$T/out"; then ok "rc 125 reads HEALTHCHECK-NOT-RUN"
else bad "HEALTHCHECK-NOT-RUN" "rc=$rc" "$(cat "$T/out")"; fi

run 0 no; rc=$?
if [ "$rc" = 3 ] && grep -qx 'ABSENT zenith-nats' "$T/out"; then ok "missing container reads ABSENT"
else bad "ABSENT" "rc=$rc" "$(cat "$T/out")"; fi

run 1 yes status
if grep -q 'running health=UNHEALTHY' "$T/out"; then ok "status health= comes from the check, not State.Health"
else bad "status health" "$(cat "$T/out")"; fi

exit "$fail"
