---
name: cicd-pipeline-design
description: Design CI/CD pipelines across Jenkins, GitHub Actions, GitLab CI, and CircleCI. Covers pipeline architecture, stage sequencing, artifact promotion, environment isolation, image tagging strategies to prevent build collisions, secrets management, caching, parallelism, and rollback patterns. Use when designing or debugging pipelines, when concurrent builds are overwriting each other's images or resources, when environments bleed into each other, when asked about pipeline structure, job dependencies, matrix builds, ephemeral environments, or promotion from dev to staging to production.
---

# CI/CD Pipeline Design

## Core mental model: every pipeline is a DAG

Before writing any config, map the directed acyclic graph:

```
[checkout] → [lint] → [test] ──┐
                                ├→ [build image] → [push] → [deploy staging] → [deploy prod]
                      [scan] ──┘
```

Questions to answer first:
1. What are the **stage gates** — what must pass before moving forward?
2. What **artifacts** flow between stages (images, binaries, test reports)?
3. What runs **in parallel** vs **must be sequential**?
4. What **resources** are shared across concurrent builds that could collide?

---

## Image tagging — prevent overwrites between concurrent builds

**The rule: never push a mutable tag (`:latest`, `:main`, `:staging`) as the primary build artifact.**

### Tag strategy by build type

| Build type | Tag pattern | Example |
|---|---|---|
| Every commit | `:{sha7}` | `app:a1b2c3d` |
| Branch build | `:{branch-slug}-{build-id}` | `app:feat-login-142` |
| PR/MR | `:pr-{number}` | `app:pr-47` |
| Release | `:{semver}` | `app:1.4.2` |
| Mutable alias (post-push only) | `:latest`, `:main` | Re-tag after immutable push succeeds |

### Branch slug sanitization

Branch names have slashes, dots, and uppercase — illegal in image tags:

```bash
# Portable sanitization
branch_slug() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | cut -c1-40
}
# feature/my-Feature.v2 → feature-my-feature-v2
```

### Promotion pattern (immutable → mutable)

```
push app:a1b2c3d          # immutable, traceable
test / scan app:a1b2c3d   # gate here
re-tag → app:staging      # mutable alias only after gates pass
deploy staging from app:a1b2c3d   # always deploy the immutable tag
```

Never deploy the mutable alias — it can shift under you. Deploy the SHA tag; mutable aliases are for human discoverability only.

---

## Environment isolation — prevent builds from stomping each other

### 1. Namespace-per-branch (Kubernetes)

```
prod:     namespace/app-prod
staging:  namespace/app-staging
PR-47:    namespace/app-pr-47        ← ephemeral, deleted on PR close
feat/x:   namespace/app-feat-x
```

Enforce via naming convention + cleanup job on branch delete / PR merge.

### 2. Unique resource naming

Every resource created by a pipeline run should include an isolation suffix:

```bash
# Bad — collides across concurrent builds
docker network create app-net
docker volume create app-data

# Good — isolated per run
RUN_ID="${BRANCH_SLUG}-${BUILD_NUMBER}"   # Jenkins
RUN_ID="${GITHUB_SHA:0:7}-${GITHUB_RUN_ID}"  # Actions
docker network create "app-net-${RUN_ID}"
docker volume create "app-data-${RUN_ID}"
```

Always clean up in a `finally`/`post`/`always` block:

```bash
cleanup() {
  docker network rm "app-net-${RUN_ID}" 2>/dev/null || true
  docker volume  rm "app-data-${RUN_ID}" 2>/dev/null || true
}
trap cleanup EXIT
```

### 3. Database isolation

| Approach | When to use |
|---|---|
| Schema-per-branch: `db_pr_47` | Shared DB host, cheap isolation |
| Ephemeral container DB | Full isolation, slower startup |
| DB seeded from snapshot | Reproducible state, best for integration tests |

Always suffix with `$PR_NUMBER` or `$BUILD_ID`. Never share a writable database across concurrent pipeline runs.

### 4. Port conflict avoidance

Use `0` (random port) or port ranges per branch:

```bash
# docker: let OS pick port, capture it
PORT=$(docker run -d -p 0:8080 my-app | xargs docker port | cut -d: -f2)
```

### 5. Concurrency controls (serialization when isolation isn't possible)

When a resource truly can't be duplicated (hardware, licensed tool, shared registry namespace):

- **Jenkins**: `lock('resource-name') { ... }` (Lockable Resources plugin)
- **GitHub Actions**: `concurrency: group: deploy-${{ github.ref }}` with `cancel-in-progress: true`
- **GitLab**: `resource_group: deploy-production`
- **CircleCI**: sequential workflows or approval gates

---

## Pipeline stages — standard structure

```
1. checkout          always first; set BUILD vars here
2. lint / validate   fast, cheap; fail early
3. unit tests        isolated, no external deps
4. build artifact    docker build, compile, package
5. push artifact     push only if tests passed
6. integration tests spin up deps; use isolated network/DB
7. security scan     image scan (Trivy), SAST, dependency check
8. deploy staging    immutable tag; gated by scan
9. smoke / E2E       verify staging is live
10. deploy prod      manual gate or auto on main
11. post-deploy      notify, tag release, update manifests
```

Anything after step 5 should reference the immutable SHA tag, not rebuild.

---

## Secrets management

- **Never** interpolate secrets into image layers or commit them.
- Inject at runtime via env vars, not build args (build args appear in image history).
- Use platform secret stores: Jenkins Credentials, GH Secrets/OIDC, GitLab CI Variables (masked), CircleCI Contexts.
- Rotate secrets ≠ update pipeline — store references, not values.
- Use OIDC / workload identity instead of long-lived keys where possible (GH Actions → AWS/GCP/Azure natively supported).

---

## Caching strategy

Cache layers from slowest-to-change to fastest:

```
OS packages     → cache by lockfile hash (apt, apk)
Language deps   → cache by manifest hash (package-lock, go.sum, Pipfile.lock)
Build cache     → Docker layer cache or BuildKit cache mounts
Test results    → cache by test file hash (skip unchanged)
```

Cache keys must be scoped to branch or be read-only from main:

```
restore-keys:
  - deps-${{ hashFiles('package-lock.json') }}   # exact
  - deps-                                         # fallback to any
```

---

## Additional reference
- See [platforms.md](platforms.md) for Jenkins, GitHub Actions, GitLab CI, and CircleCI platform-specific idioms, built-in variables, and config snippets.
- See [patterns.md](patterns.md) for complete worked examples: PR ephemeral environment, matrix test fan-out, image promotion pipeline.
