#!/usr/bin/env bash
# mcp-orphans-clean.sh - stop MCP containers and processes whose owning claude seat is gone.
#
# usage: mcp-orphans-clean.sh [--dry] [--grace S]      (Make: make mcp-orphans-clean [DRY=1])
#   --dry      list what would stop and change nothing (always run this first)
#   --grace S  seconds `podman stop` waits (default 3)
# config: resources.json mcp_images (container images), mcp_process_patterns (process cmdline regexes), subreapers
#   (parent pids that mean "reparented, owner gone", default 1). SR_CONFIG overrides the file.
#
# Owner, 2026-10-16 UTC: "we need to be conscious of each seat cost the system resouces". Idempotent: a second run finds
# nothing. Owner is decided by lib.sh res_client_container_map (see its BREADCRUMB); only running containers of the listed
# images are touched, never any other container (nats, test images).
# BREADCRUMB - a bg-spare client is a live owner.
# What broke: nothing yet, this is the guard. `claude bg-spare` daemons are idle pre-spawned sessions that own an MCP set.
# Why it matters: reaping them would break the next session that claims the spare.
# Why this fix: ownership is "a live podman client holds the container", whoever the client's parent is.
set -uo pipefail
# shellcheck source=resources/lib.sh disable=SC1091
. "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/lib.sh"
command -v podman >/dev/null || res_die "podman is required"; command -v jq >/dev/null || res_die "jq is required"
DRY=0; GRACE=3
while [ $# -gt 0 ]; do case "$1" in
  --dry) DRY=1; shift ;; --grace) GRACE="$2"; shift 2 ;; -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) res_die "unknown argument $1" ;; esac; done

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
res_client_container_map | awk '{print $2}' | sort -u > "$tmp/owned"
before=0; stopped=0
while IFS= read -r img; do
  [ -n "$img" ] || continue
  podman ps -q --filter "ancestor=$img" 2>/dev/null | while read -r c; do printf '%s\t%s\n' "${c:0:12}" "$img"; done
done < <(res_cfg '.mcp_images[]') > "$tmp/running"
before=$(wc -l < "$tmp/running")
while IFS=$'\t' read -r c img; do
  grep -qx "$c" "$tmp/owned" && continue
  if [ "$DRY" = 1 ]; then echo "would stop container $c ($img)"; else
    if podman stop -t "$GRACE" "$c" >/dev/null 2>&1; then echo "stopped container $c ($img)"; stopped=$((stopped+1)); else echo "WARN could not stop $c" >&2; fi; fi
done < "$tmp/running"
[ "$DRY" = 1 ] && stopped=$(grep -cvxFf "$tmp/owned" <(cut -f1 "$tmp/running"))

# Orphan MCP processes: cmdline matches a pattern and the parent is a subreaper (reparented, owner gone).
pat="$(res_cfg '.mcp_process_patterns | join("|")')"; subs="$(res_cfg '.subreapers | map(tostring) | join("|")')"
procs=0
while read -r pid ppid args; do
  echo "$ppid" | grep -Eqx "$subs" || continue
  echo "$args" | grep -Eq "$pat" || continue
  # a process of this script's own pipeline would match its own pattern text; skip anything naming this script
  case "$args" in *mcp-orphans-clean*) continue ;; esac
  if [ "$DRY" = 1 ]; then echo "would kill process $pid: ${args:0:90}"; else kill "$pid" 2>/dev/null && echo "killed process $pid: ${args:0:90}"; fi
  procs=$((procs+1))
done < <(ps -eo pid=,ppid=,args=)
printf 'mcp-orphans-clean%s: containers running %d, orphan containers %d, orphan processes %d\n' "$([ "$DRY" = 1 ] && echo ' (dry)')" "$before" "$stopped" "$procs"
