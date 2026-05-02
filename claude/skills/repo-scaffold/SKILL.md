---
name: repo-scaffold
description: Scaffold a new repository from an existing one as a template, applying targeted tweaks. Use when you want to clone a repo's structure and patterns into a new project with a different name, language version, framework, or configuration; when spinning up a new service that mirrors an existing one; when asked to "make one just like X but change Y"; or when bootstrapping a new repo from a working reference.
---

# Repo Scaffold

Clone an existing repo's structure, conventions, and tooling into a new repo — changing only what needs to change.

## Workflow

### Step 1 — Analyze the source repo

Read these files before touching anything:

```
Source repo fingerprint:
- Package manifest: package.json / go.mod / pyproject.toml / Cargo.toml / pom.xml
- CI/CD: .github/workflows/ / Jenkinsfile / .gitlab-ci.yml / .circleci/
- Containers: Dockerfile / docker-compose.yml / podman-compose.yml
- K8s / GitOps: k8s/ / helm/ / argocd/ / manifests/
- Config: .env.example / config/ / values.yaml
- Root: README.md / Makefile / justfile / taskfile.yml
```

Extract and note:
- **Service name** in all its forms (see naming variants below)
- **Tech stack** and versions
- **Port numbers**, **DB names**, **env var prefixes**
- **CI triggers**, **registry paths**, **deploy targets**

### Step 2 — Define the delta

Be explicit about exactly what changes. Common deltas:

| Delta type | What to update |
|---|---|
| Service rename | All name variants everywhere (see below) |
| Language/runtime version | Manifest, Dockerfile `FROM`, CI matrix |
| Framework swap | Dependencies, entry point, config format |
| Port number | Dockerfile `EXPOSE`, compose ports, K8s service, env vars |
| Database name | Env vars, init scripts, K8s secrets |
| Registry / namespace | Dockerfile, CI push step, K8s image ref |
| Feature flag / toggle | Config files, env vars |

### Step 3 — Scaffold

Use the scaffold script (see `scripts/scaffold.sh`) or follow manually:

```bash
scripts/scaffold.sh \
  --source ~/projects/old-service \
  --dest   ~/projects/new-service \
  --old    old-service \
  --new    new-service
```

The script copies, renames files, and substitutes all name variants. Then apply your specific delta on top.

### Step 4 — Apply targeted tweaks

After scaffolding, make the specific changes for your delta:

```bash
cd ~/projects/new-service

# Example: bump Node version
sed -i 's/node:20/node:22/g' Dockerfile .github/workflows/*.yml

# Example: change port
grep -rl '3000' . --include='*.yml' --include='*.env*' --include='Dockerfile' \
  | xargs sed -i 's/3000/4000/g'
```

### Step 5 — Post-scaffold checklist

```
- [ ] Update README title, description, and badge URLs
- [ ] Update package name / module path in manifest
- [ ] Regenerate lockfile: npm install / go mod tidy / pip-compile
- [ ] Update .env.example with new service-specific vars
- [ ] Update CI: registry paths, deploy targets, environment names
- [ ] Update K8s/Helm: namespace, ingress host, resource names
- [ ] Create GitHub repo: gh repo create org/new-service --private
- [ ] Push: git init && git add . && git commit -m "init: scaffold from old-service" && git push -u origin main
- [ ] Update secrets in CI (don't copy old service's secrets)
- [ ] Update any service discovery / DNS / load balancer config
```

---

## Naming variants — always substitute all of them

When renaming `my-service` → `new-service`, every form appears somewhere:

| Variant | Example | Where |
|---|---|---|
| `kebab-case` | `my-service` | package.json name, Docker image, K8s metadata |
| `PascalCase` | `MyService` | Go package, Java class, TypeScript export |
| `camelCase` | `myService` | JS vars, JSON keys, env var defaults |
| `snake_case` | `my_service` | Python module, DB name, some env vars |
| `SCREAMING_SNAKE` | `MY_SERVICE` | Env var prefixes, constants |
| `Title Case` | `My Service` | README headers, display names |

The scaffold script handles all of these automatically given `--old` and `--new`.

---

## What to always exclude from copy

```
.git/
node_modules/ / vendor/ / .venv/ / __pycache__/
dist/ / build/ / target/ / .next/ / out/
*.log / *.lock (regenerate these)
.env (never copy real secrets — copy .env.example only)
coverage/ / .nyc_output/
```

---

## Additional reference
- See [scripts/scaffold.sh](scripts/scaffold.sh) — run this to do the copy + rename in one shot.
- See [checklist.md](checklist.md) for a more detailed post-scaffold verification checklist by stack.
