#!/usr/bin/env bash
# lib.sh - process, container and config helpers shared by seat-resources.sh and mcp-orphans-clean.sh.
# Sets no shell options (see bin/workflow-lib.sh BREADCRUMB): each caller declares its own.
#
# BREADCRUMB - how a container is tied to the seat that owns it.
# What broke: 29 jenkins-mcp containers ran for 12 live seats (brief BR-20261016-resources). `podman run --rm -i` names no
#   owner, and a container outlives its client when the seat dies, so nothing said which containers were orphans.
# Why this fix: the live `podman run` client holds a unix socket whose peer is the container's conmon. Matching that peer to
#   `podman inspect .State.ConmonPid` ties each running container to a client, and each client to a seat by its ancestry.
#   A container with no live client is an orphan. Rejected: matching by start time (races), by label (the MCP config sets none).
# Cost: needs `ss` and `podman inspect`, one call each per sweep.

RES_DIR="${RES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
RES_CONFIG="${SR_CONFIG:-$RES_DIR/resources.json}"

res_die() { printf 'resources: %s\n' "$*" >&2; exit 1; }
res_cfg() { jq -r "$1" "$RES_CONFIG"; }
# res_val <env-name> <jq-key>: the env override if set, else the config value.
res_val() { local e="${!1:-}"; if [ -n "$e" ]; then printf '%s' "$e"; else res_cfg ".$2"; fi; }

# res_ps: pid ppid rss_kb lines, one ps call.
res_ps() { ps -eo pid=,ppid=,rss= | awk '{print $1, $2, $3}'; }

# res_descendants <pid> <ps-lines-file>: the pid and every descendant, one per line.
res_descendants() {
  awk -v root="$1" '{ kid[$2]=kid[$2] " " $1 } END {
    n=1; q[1]=root
    for (i=1;i<=n;i++) { print q[i]; split(kid[q[i]], a, " "); for (j in a) if (a[j]!="") q[++n]=a[j] } }' "$2"
}

# res_client_container_map: "client_pid container_id" for each live podman client attached to a running container.
res_client_container_map() {
  local conmons socks
  conmons="$(podman ps -q 2>/dev/null | xargs -r podman inspect --format '{{.State.ConmonPid}} {{.ID}}' 2>/dev/null)"
  [ -n "$conmons" ] || return 0
  socks="$(ss -xp 2>/dev/null)"
  printf '%s\n' "$socks" | awk -v cm="$conmons" '
    BEGIN { n=split(cm, L, "\n"); for (i=1;i<=n;i++) { split(L[i], f, " "); id[f[1]]=substr(f[2],1,12) } }
    { local_i=$6; peer=$8; if (match($0, /\(\("[^"]+",pid=[0-9]+/)) {
        s=substr($0, RSTART, RLENGTH); split(s, p, "\""); name=p[2]; sub(/.*pid=/, "", s); pid=s
        owner_name[local_i]=name; owner_pid[local_i]=pid; peerof[local_i]=peer } }
    END { for (i in owner_name) if (owner_name[i]=="podman") { pe=peerof[i]
            if (owner_name[pe]=="conmon" && (owner_pid[pe] in id)) print owner_pid[i], id[owner_pid[pe]] } }' | sort -u
}
