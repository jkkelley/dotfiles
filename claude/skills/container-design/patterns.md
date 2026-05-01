# Container Design — Worked Patterns

## Pattern: OSM/Nominatim-style stack (PBF import → Postgres → app)

Classic three-phase pipeline where a binary importer needs a data volume and the Postgres network simultaneously.

```bash
#!/usr/bin/env bash
set -euo pipefail

REGION_PBF="${1:?Usage: $0 <region.osm.pbf>}"
PBF_VOL="pbf-data"
PG_NET="osm-net"
PG_NAME="osm-postgres"
APP_NAME="nominatim"

# --- Phase 1: Infrastructure ---
podman volume create "$PBF_VOL"   2>/dev/null || true
podman network create "$PG_NET"   2>/dev/null || true

# Copy PBF into volume via throwaway container
podman run --rm \
  --volume "$PBF_VOL":/data \
  --volume "$(dirname "$REGION_PBF")":/src:ro \
  busybox cp /src/"$(basename "$REGION_PBF")" /data/region.osm.pbf

# --- Phase 2: Postgres ---
podman run -d --name "$PG_NAME" \
  --network "$PG_NET" \
  --volume pg-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=nominatim \
  -e POSTGRES_PASSWORD=nominatim \
  postgres:16-postgis

until podman exec "$PG_NAME" pg_isready -U nominatim -q; do
  echo "Waiting for Postgres…"; sleep 3
done

# --- Phase 3: Import (needs BOTH volume AND network) ---
podman run --rm \
  --network "$PG_NET" \
  --volume "$PBF_VOL":/nominatim/data:ro \
  -e NOMINATIM_DATABASE_DSN="pgsql:host=$PG_NAME;dbname=nominatim;user=nominatim;password=nominatim" \
  nominatim-image \
  nominatim import --osm-file /nominatim/data/region.osm.pbf --threads 4

# --- Phase 4: App ---
podman run -d --name "$APP_NAME" \
  --network "$PG_NET" \
  -p 8080:8080 \
  -e NOMINATIM_DATABASE_DSN="pgsql:host=$PG_NAME;dbname=nominatim;user=nominatim;password=nominatim" \
  nominatim-image \
  nominatim serve
```

---

## Pattern: Migration-gated app (schema must run before app starts)

```bash
# Run migrations to completion
podman run --rm \
  --network app-net \
  -e DATABASE_URL="postgres://..." \
  my-app \
  migrate up

# Only start app after migrations succeed (exit 0)
podman run -d --name app \
  --network app-net \
  my-app serve
```

In Compose:
```yaml
  migrator:
    image: my-app
    command: migrate up
    depends_on:
      postgres: { condition: service_healthy }

  app:
    image: my-app
    command: serve
    depends_on:
      migrator: { condition: service_completed_successfully }
```

---

## Pattern: Sidecar log forwarder sharing a log volume

```bash
podman volume create app-logs

podman run -d --name app \
  --volume app-logs:/var/log/app \
  my-app

podman run -d --name log-forwarder \
  --volume app-logs:/var/log/app:ro \
  fluent-bit -c /etc/fluent-bit/fluent-bit.conf
```

Both containers attach to the same named volume; the forwarder uses `:ro` to prevent accidental writes.

---

## Pattern: HTTP readiness gate

```bash
wait_for_http() {
  local url=$1 timeout=${2:-60} elapsed=0
  until curl -sf --max-time 2 "$url" > /dev/null; do
    [ $elapsed -ge $timeout ] && { echo "Timeout waiting for $url"; exit 1; }
    sleep 2; elapsed=$((elapsed + 2))
  done
  echo "$url is ready"
}

podman run -d --name api --network app-net -p 3000:3000 my-api
wait_for_http http://localhost:3000/health 90

podman run -d --name worker --network app-net my-worker
```

---

## Pattern: Cleanup trap for one-shot containers

```bash
cleanup() {
  podman stop osm-postgres 2>/dev/null || true
  podman rm   osm-postgres 2>/dev/null || true
}
trap cleanup EXIT

podman run -d --name osm-postgres ...
# rest of script — cleanup runs on exit regardless of success/failure
```
