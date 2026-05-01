---
name: container-design
description: Design and sequence multi-container applications — dependency ordering, volume and network attachment, init patterns, health-check gating, and startup scripts. Use when wiring containers together in Docker, Podman, Docker Compose, or Kubernetes; when a container needs multiple resources (volumes, networks, sidecars) attached simultaneously; when deciding between init containers, entrypoint scripts, depends_on, or shell sequencing; or when asked about container startup order, PBF imports, database readiness, or any "container A needs B and C before it can run" problem.
---

# Container Design

## Core mental model

Every multi-container problem is a **dependency graph**. Before writing any script or config, draw it:

```
[resource/sidecar] ──needs──> [container]
[volume]           ──mount──> [container]
[network]          ──attach─> [container]
[container A ready]──gates──> [container B starts]
```

Identify for each container:
1. **Static resources** it needs mounted before PID 1 starts (volumes, config files)
2. **Network reachability** it needs (which other containers it must talk to)
3. **Runtime readiness** it needs (DB accepting connections, file fully written, port open)

---

## Sequencing patterns — choose one per dependency type

### 1. Volume + network simultaneously (shell script / Podman)

When a container needs a data volume AND a specific network at start time, both must exist before `run`:

```bash
# Create volume and network first (idempotent)
podman volume create pbf-data 2>/dev/null || true
podman network create osm-net 2>/dev/null || true

# Attach both at the same time in a single run call
podman run --rm \
  --network osm-net \
  --volume pbf-data:/data \
  my-binary-image \
  import /data/region.osm.pbf
```

Never run the container first and attach resources later — volumes and networks must be declared at `run` time.

### 2. Readiness gating (wait-for pattern)

Gate a dependent container on a service being actually ready, not just started:

```bash
wait_for_postgres() {
  local host=$1 port=${2:-5432} timeout=${3:-60}
  local elapsed=0
  until pg_isready -h "$host" -p "$port" -q; do
    [ $elapsed -ge $timeout ] && { echo "Postgres timeout"; exit 1; }
    sleep 2; elapsed=$((elapsed + 2))
  done
}

# Start Postgres container
podman run -d --name postgres --network osm-net \
  -e POSTGRES_PASSWORD=secret postgres:16

# Gate binary on Postgres being ready
wait_for_postgres localhost 5432 120

# Now run binary with both volume and network
podman run --rm --network osm-net --volume pbf-data:/data my-importer
```

### 3. Init container pattern (Kubernetes)

When the main container needs pre-work done (download, import, transform) before it starts:

```yaml
initContainers:
  - name: pbf-importer
    image: my-importer
    volumeMounts:
      - name: pbf-data
        mountPath: /data
    command: ["import.sh", "/data/region.osm.pbf"]

containers:
  - name: app
    image: my-app
    volumeMounts:
      - name: pbf-data
        mountPath: /data/read-only
```

Init containers run to completion before any main container starts. Use for: data imports, schema migrations, secret fetching.

### 4. Docker Compose dependency + health check

```yaml
services:
  postgres:
    image: postgres:16
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres"]
      interval: 5s
      timeout: 3s
      retries: 10

  importer:
    image: my-importer
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - pbf-data:/data
    networks:
      - osm-net

  app:
    image: my-app
    depends_on:
      importer:
        condition: service_completed_successfully
    networks:
      - osm-net

volumes:
  pbf-data:
networks:
  osm-net:
```

---

## Decision guide

| Situation | Use |
|---|---|
| One-shot import before app starts | Init container (K8s) or `service_completed_successfully` (Compose) |
| Container needs volume + network at same time | Declare both in single `run` / `container` spec |
| Wait for DB to accept connections | `pg_isready` loop or `service_healthy` depends_on |
| Wait for a file to exist | `until [ -f /data/done.flag ]; do sleep 1; done` in entrypoint |
| Wait for HTTP endpoint | `curl --retry 10 --retry-connrefused --retry-delay 2 http://host/health` |
| Sidecar must share process namespace | `shareProcessNamespace: true` (K8s) or `--pid container:name` (Podman) |
| Resources must be cleaned up after | `--rm` on the runner; trap EXIT in script |

---

## Script skeleton for shell-based sequencing

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Declare all resources (idempotent)
podman volume create pbf-data 2>/dev/null || true
podman network create osm-net  2>/dev/null || true

# 2. Start long-running services
podman run -d --name postgres \
  --network osm-net \
  -e POSTGRES_PASSWORD=secret \
  postgres:16

# 3. Gate on readiness
until podman exec postgres pg_isready -q; do sleep 2; done

# 4. Run one-shot containers (need both volume and network)
podman run --rm \
  --network osm-net \
  --volume pbf-data:/data \
  my-importer import /data/region.osm.pbf

# 5. Start app
podman run -d --name app \
  --network osm-net \
  --volume pbf-data:/data:ro \
  my-app
```

---

## Common mistakes

- **Splitting volume and network across separate steps** — both must be in the same `run` invocation.
- **Checking container started instead of service ready** — `podman inspect` showing "running" ≠ Postgres accepting connections.
- **Hardcoding sleep** — use active polling loops with a timeout ceiling, not `sleep 30`.
- **Forgetting `--rm` on one-shot containers** — they accumulate and block future runs with name conflicts.
- **Compose `depends_on` without `condition`** — defaults to `service_started`, not `service_healthy`.

---

## Additional reference
- See [patterns.md](patterns.md) for more complete worked examples (Nominatim/OSM stack, multi-DB fan-out, sidecar logging).
