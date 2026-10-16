#!/usr/bin/env bash
# name: test_bus_bind.sh
# purpose: prove bus.sh up publishes only on 127.0.0.1 and refuses any other bind host (BUS-BIND-REFUSED, exit 3)
# inputs: none; BUS_NATS and podman are stubbed on PATH
# outputs: ok/FAIL lines on stdout, exit 0 when all pass
# writes-to: a mktemp scratch dir only
# cleanup: removes its scratch dir on exit
# Proves bus.sh up publishes only on 127.0.0.1 and refuses any other bind host, against a stub podman.
#   - a podman -p flag that is not 127.0.0.1-prefixed (the bus on the LAN, ORD-0553 R1)
#   - a widened bind that still reaches podman instead of BUS-BIND-REFUSED with exit 3
# Hermetic: podman is a stub on PATH recording its args; no container is started.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
ok()  { printf 'ok  %s\n' "$1"; }
bad() { fail=1; printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
mkdir -p "$T/bin"
cat > "$T/bin/podman" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$T/podman.log"
case "$1" in container) exit 1 ;; exec) echo '"ok"' ;; esac
exit 0
STUB
cat > "$T/bin/nats" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$T/bin/podman" "$T/bin/nats"; export T

run_up() { # $1 bind value
  jq --arg b "$1" '.bus.bind=$b | .bus.store=env.T+"/store"' "$R/config/line-watch.json" > "$T/cfg.json"
  : > "$T/podman.log"
  PATH="$T/bin:$PATH" LW_BUS="$T/cfg.json" BUS_NATS="$T/bin/nats" BUS_RETRY_SLEEP=0 bash "$R/bin/bus.sh" up >"$T/out" 2>&1
}

run_up 127.0.0.1
runline="$(grep -m1 '^run ' "$T/podman.log")"
if grep -q -- '-p 127.0.0.1:4222:4222' <<<"$runline" && grep -q -- '-p 127.0.0.1:8222:8222' <<<"$runline" \
   && ! grep -oE -- '-p [^ ]+' <<<"$runline" | grep -vq -- '-p 127.0.0.1:'; then
  ok "bus-up publishes only on 127.0.0.1"
else bad "bus-up publish flags" "$runline"; fi

run_up 0.0.0.0; rc=$?
if [ "$rc" = 3 ] && grep -q 'BUS-BIND-REFUSED 0.0.0.0' "$T/out" && [ ! -s "$T/podman.log" ]; then
  ok "bind 0.0.0.0 is BUS-BIND-REFUSED"
else bad "0.0.0.0 not refused" "rc=$rc" "$(cat "$T/out")" "$(cat "$T/podman.log")"; fi

exit "$fail"
