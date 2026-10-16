#!/usr/bin/env bash
# Stub `wslpath` for the inbox sweep's tests: the Podman image has no WSL. `wslpath -w <p>` and `-u <p>` echo <p>,
# so a test can compare the path the script passed to the stub powershell.exe with the file it then finds on disk.
[ "${1:-}" = "-w" ] || [ "${1:-}" = "-u" ] || exit 2
printf '%s\n' "${2:-}"
