---
name: container-sandbox
description: Run all dependency-heavy tasks (npm, go, pip) in isolated Podman containers. Also use when showing the user a localhost frontend that makes API calls — a real or mock backend must be running in the same compose stack.
---

# Dependency Isolation Protocol

**RULE:** Never run `npm install`, `go mod download`, or `pip install` on the host.

## 1. Choosing the Sandbox
- **Small Tasks:** Use the **Single-Use Container** (Podman).
- **Cluster Tasks:** Use the **Kind Sandbox** (Kind + Podman).
- **Terraform Tasks:** Use the **Ministack Sandbox** (see section below).

## 2. Dependency Management (The "No-Clutter" Way)

### Node.js (npm)
Instead of `npm install`, tell the agent to run:
```bash
podman run --rm -v .:/app:Z -w /app node:20-slim sh -c "npm install && npm test"
```

## Terraform / Ministack Sandbox

**RULE:** Use Ministack any time Terraform files are written or modified, unless the user explicitly says not to. This includes `terraform validate` — syntax-only checks are not enough. No exceptions.

### Step 1 — Gitignore Pre-Flight

Before anything else, verify these entries exist in `.gitignore`. If any are missing, add them. These files must never be committed:

```
test/
**/.terraform/
*.tfvars
*.tfstate.backup
**/.terraform.lock.hcl
```

```bash
REQUIRED=("test/" "**/.terraform/" "*.tfvars" "*.tfstate.backup" "**/.terraform.lock.hcl")
for entry in "${REQUIRED[@]}"; do
  grep -qxF "$entry" .gitignore 2>/dev/null || echo "$entry" >> .gitignore
done
```

Commit `.gitignore` if it was modified before continuing.

### Step 2 — Start Ministack

```bash
podman run -d \
  --name ministack_local \
  -p 4566:4566 \
  -v $XDG_RUNTIME_DIR/podman/podman.sock:/var/run/docker.sock:Z \
  ministackorg/ministack:full
```

Verify it is up before continuing:

```bash
podman ps --filter name=ministack_local --format "{{.Status}}"
# Must show "Up"
```

If the container fails to start, **stop and report the exact error to the user**. Do not proceed.

### Step 3 — Seed a Throwaway terraform.tfvars

Variables without defaults will cause `terraform validate` and `terraform plan` to fail with missing-value errors. Create a temporary `terraform.tfvars` with fake seed values for the test run. This file goes in the module root, never in source code — it is already covered by the `*.tfvars` gitignore entry and will never be committed.

Fake values go in this file, not into `variables.tf` defaults or hardcoded into resources:

```hcl
# terraform.tfvars — ministack test seed, never commit
aws_region   = "us-east-1"
account_id   = "000000000000"
domain       = "test.example.com"
cluster_name = "test-cluster"
```

Adapt the keys to match whatever variables the module actually declares. If a variable has a default, skip it. Only seed what's required.

### Step 4 — Point Terraform at Ministack

Set these environment variables before running any Terraform commands:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566
```

### Step 5 — Validate

```bash
terraform init -backend=false
terraform validate
terraform plan    # optional but recommended — catches provider-level errors validate misses
```

If any command fails, **stop and report the exact error to the user**. Do not guess at a fix and re-run silently.

### Step 6 — Teardown

```bash
podman stop ministack_local && podman rm ministack_local
```

---

## Lifecycle Management
- **Pre-flight:** Always run `./scripts/verify-readiness.sh` before starting a cluster.
- **Teardown:** When the task is complete, run `./scripts/cleanup-kind-podman.sh`.
- **Maintenance:** If disk space is low or images are outdated, run `./scripts/prune-images.sh`.

---

## 3. Frontend Dev With API Dependency — Full Stack Compose Rule

**RULE: Never ask the user to look at a page with no data.**

When a frontend feature makes API calls, spin up a `podman compose` stack with:
- The real backend (or a mock) seeded with realistic data
- The frontend dev server
- All services on the same compose network

Verify data flows end-to-end with `curl` before handing the URL to the user.

### Port convention — always use high ports

Multiple Claude Code sessions may run simultaneously. Use high ports to avoid cross-session conflicts:

| Service | Host port |
|---------|-----------|
| Frontend (Vite) | `13000` |
| Backend API | `18000` |
| Mock backend | internal only (no host port) |

Always map `13000:<container_port>` for the frontend. Expose the backend on `18000:8000` for direct debugging during validation.

---

### Pattern — real backend stack

When the project already has a working backend image (`<service>:dev`):

1. **Create `test/start-be.sh`** — startup script baked into the be service that runs migrations, seeds data, then starts the server. This avoids one-shot init containers, which break `--requires` chains in podman-compose 1.0.6.

   ```sh
   #!/bin/sh
   set -e
   echo "[start-be] running migrations..."
   alembic upgrade head          # or your migration tool
   echo "[start-be] seeding..."
   python /init.py
   echo "[start-be] starting server..."
   exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```

2. **Create `test/init.py`** — seed script using the same DB library already in the image (e.g. asyncpg). No extra installs.

3. **Create `compose.test.yml`** in the workspace root (parent of all service repos) so relative paths reach sibling repos:

   ```yaml
   services:
     postgres:
       image: docker.io/postgres:15-alpine
       environment:
         POSTGRES_DB: myapp
         POSTGRES_USER: myapp
         POSTGRES_PASSWORD: dev
       healthcheck:
         test: ["CMD-SHELL", "pg_isready -U myapp"]
         interval: 3s
         retries: 15

     be:
       image: myapp-be:dev           # pre-built dev image
       volumes:
         - ./myapp-be:/app:Z
         - ./test/init.py:/init.py:ro,Z
         - ./test/start-be.sh:/start-be.sh:ro,Z
       environment:
         DATABASE_URL: postgresql+asyncpg://myapp:dev@postgres:5432/myapp
       ports:
         - "18000:8000"
       command: sh /start-be.sh
       depends_on:
         postgres:
           condition: service_healthy

     frontend:
       image: docker.io/node:20-alpine
       volumes:
         - ./myapp-fe:/app:Z
       working_dir: /app
       ports:
         - "13000:3000"             # or whatever port Vite uses
       environment:
         API_PROXY_TARGET: http://be:8000   # see proxy env var rule below
       command: npm run dev -- --host
       depends_on:
         - be
   ```

4. **Spin up:** `podman compose -f compose.test.yml up --build -d`

5. **Verify the API responds** before directing the user to the browser:
   ```bash
   curl -s http://localhost:18000/api/v1/<resource>/ | python3 -m json.tool | head -20
   curl -s http://localhost:13000/api/v1/<resource>/          # through the Vite proxy
   ```

   Both must return data. If the first works but the second doesn't, the proxy env var is wrong (see below).

6. **Direct user to:** `http://localhost:13000`

---

### Critical: Vite proxy env var — use API_PROXY_TARGET, not VITE_API_URL

Vite exposes **all** `VITE_*` env vars to the browser bundle at dev-server startup. If you set `VITE_API_URL=http://be:8000` in the container, Axios picks it up client-side and tries to fetch `http://be:8000/api/...` directly from the browser — which can't resolve the internal Docker hostname. The page loads but shows no data.

**The fix:** use a non-`VITE_` prefixed variable for the server-side proxy target only.

In `vite.config.ts`:
```ts
proxy: {
  '/api': {
    target: process.env.API_PROXY_TARGET || process.env.VITE_API_URL || 'http://localhost:8000',
    changeOrigin: true,
  },
},
```

In `compose.test.yml`:
```yaml
environment:
  API_PROXY_TARGET: http://be:8000   # server-side only — NOT exposed to browser
  # do NOT set VITE_API_URL here
```

With this, Axios uses an empty base URL → relative paths → Vite proxy routes them → `be:8000` resolves on the compose network.

---

### Pattern — mock backend (no real backend image available)

When there is no pre-built backend image, create a zero-dependency Node.js mock:

1. **Create `test/mock-api/server.mjs`** — uses only `node:http` built-in, no npm install.
   - Handles CORS (`Access-Control-Allow-Origin: *`)
   - Serves realistic seed data
   - Logs all requests so you can verify API contracts

2. **Create `test/mock-api/Dockerfile`**:
   ```dockerfile
   FROM node:20-alpine
   WORKDIR /app
   COPY server.mjs .
   EXPOSE 9090
   CMD ["node", "server.mjs"]
   ```

3. Add to `compose.test.yml` as a `mock-api` service (internal only, no host port).

4. In the frontend service, set `API_PROXY_TARGET: http://mock-api:9090`.

---

### podman-compose 1.0.6 known limitations

- **One-shot containers in dependency chains don't work.** `depends_on: condition: service_completed_successfully` is ignored — podman uses `--requires` which requires the dependency to be *running*, not *completed*. A one-shot init container that exits will break the chain for all downstream services.
  - **Workaround:** merge migrations and seed into the main service startup script (see `start-be.sh` pattern above).

- **`condition: service_healthy`** works correctly for postgres with a `pg_isready` healthcheck.

- **`condition: service_started`** works for always-running services.

---

### Seed data guidelines
- Include enough records to exercise every UI state: empty results, filtered results, edge-case values.
- Use realistic names, addresses, phone numbers — not `"foo"` / `"bar"` / `999`.
- Insert seed data in **non-alphabetical order** when testing sort fixes — this is the only way to prove the sort is actually working.
- Use `ON CONFLICT DO NOTHING` so the script is safe to re-run.

### Teardown
```bash
podman compose -f compose.test.yml down
```
