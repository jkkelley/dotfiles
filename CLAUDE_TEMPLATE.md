# CLAUDE.md — Project Template

> **This file is a template copied from `~/dotfiles/CLAUDE_TEMPLATE.md`.**
> Public dotfiles repo policy applies: no real values may live in the template itself.
> Real values belong here in the project-level `CLAUDE.md` after it's been copied in.

---

## TO CLAUDE — read this block FIRST

If any `<placeholder>` token still appears anywhere in this file, you are reading the
template for the first time in a fresh project and **the operator has not yet filled it in**.

**Before doing any other work — including answering "simple" questions, exploring the
codebase, or running tools — do this:**

1. Scan the file for every `<placeholder>` token.
2. Walk through each one with the user, in order, and ask for the real value.
3. Replace each placeholder via `Edit` as you go (don't batch — confirm each one).
4. When finished, delete this entire `## TO CLAUDE — read this block FIRST` section
   and the surrounding template-instruction blocks (the top "This file is a template"
   admonition and the bottom "Template provenance" footer).
5. Then, and only then, proceed to the user's original task.

If the user explicitly says "skip the placeholder pass" — honor it, but flag any
`<placeholder>` you encounter later as "unresolved template token" and confirm before
relying on it.

---

## Session State

See `CONTEXT_STATE.md` in this project root for current infrastructure state, active
tasks, decisions made, blockers, and lessons learned. **Read it before starting any task.**

If `CONTEXT_STATE.md` doesn't exist yet, create one using the `context-compaction` skill
when context usage exceeds ~30%, or when starting a new session that needs continuity.

---

## Cluster & Architecture (homelab — non-negotiable defaults)

| Fact | Value |
|------|-------|
| Cluster | homelab Kubernetes |
| Node architecture | **ARM64 (aarch64)** |
| Default image platform | `linux/arm64` |
| Multi-arch images | **only when explicitly requested** |
| Kubernetes version | `<k8s-version>` (e.g. `1.31`) |
| Control plane | `<control-plane-host>` |
| Worker nodes | `<worker-node-1>`, `<worker-node-2>` |

**Implications Claude must respect without being told:**

- Every `Dockerfile` in this repo must produce an `arm64` image. Either use a base
  image whose default arch is arm64, or pin `--platform=linux/arm64` / set
  `GOARCH=arm64` / equivalent for the language.
- When pulling container images during local testing (Podman), prefer `arm64`
  variants. Some images (e.g. `wiktorn/overpass-api`) ship amd64-only — flag this
  before suggesting them.
- Don't recommend amd64-only tools (e.g. some `ghcr.io/*` releases without arm64
  builds, certain prebuilt CLIs) without confirming the user has a workaround.
- Cross-compile from amd64 dev hosts when WSL2/x86 is the dev box; build on-cluster
  when possible.

---

## Project Overview

`<one-paragraph description of what this project does, who uses it, and which other
services it interacts with>`

`<table of subdirectories / services if monorepo, otherwise delete>`

| Directory | Language | Role |
|---|---|---|
| `<dir>` | `<lang>` | `<role>` |

---

## Commands

```bash
# Local dev
<dev-command>

# Build
<build-command>

# Tests
<test-command>      # or note "no test suite yet"

# Lint
<lint-command>      # or note "no linting configured"
```

---

## Architecture

`<short prose + diagram describing layers, data flow, and any non-obvious design
decisions. Pull only what's NOT derivable from reading the code — design rationale,
constraints, cross-service contracts, schema-flexibility rules.>`

---

## Development Workflow (homelab — always in this order)

This homelab has a strict, opinionated workflow. Claude must follow it even when
"shipping fast" feels tempting. Skipping a step has caused build failures and
cluster drift in the past.

1. **Local development & verification — every change.** Iterate inside an
   ephemeral sandbox. Two flavors, pick whichever fits the change:

   - **Podman** — for unit tests, integration tests, build verification, and any
     work that does not require a Kubernetes API. See *Build & Dependency Hygiene*
     below for the exact pattern.
   - **Kind** (Kubernetes-in-Docker) — for any change that touches manifests,
     RBAC, NetworkPolicies, CRDs, or anything else that needs a real apiserver.
     Spin up a throwaway Kind cluster, apply the manifests there, prove
     correctness, then tear it down. **Never test manifests against the homelab
     cluster directly.**

   **Bring every dependency into the sandbox.** No language toolchains, kubectl
   plugins, helm chart caches, or test fixtures may be installed on the host.
   The container/cluster is the dependency boundary.

2. **Commit + push — only after sandbox verification passes.** Push the project
   repo to its `main` (or feature branch). Don't push code that hasn't been
   exercised in step 1.

3. **Manually trigger Jenkins.** Webhooks and SCM polling are *not* the trigger
   of record — the operator (the human user) clicks "Build Now" in the Jenkins
   UI when ready. This is intentional: it gives the operator a final chance to
   confirm the right commit will be built. **Claude does not trigger Jenkins.**

4. **Jenkins → Kaniko → GHCR.** The pipeline builds the image, scans it with
   Trivy, and (for ArgoCD-managed apps only) updates the GitOps overlay. See
   *CI/CD Pipeline*.

5. **GitOps prerequisite — for ArgoCD-managed apps only.** **The Jenkins
   `Update GitOps` stage will fail unless `apps/<app-name>/{base,overlays/homelab}/`
   already exists in the `homelab-gitops` repo.** When scaffolding any new
   project that will be ArgoCD-managed:

   - Claude must scaffold the overlay directory in `homelab-gitops`
     **before** the first Jenkins build that includes the GitOps stage.
   - Pattern: `apps/<app-name>/base/{kustomization.yaml, manifests…}` plus
     `apps/<app-name>/overlays/homelab/kustomization.yaml` containing an
     `images:` block.
   - Use an existing app under `apps/` as the template.

   **If the project produces only an image with no continuously-synced k8s
   resources** (e.g. a dispatcher whose Jobs are created on demand by another
   service), drop the `Update GitOps — Homelab` stage from the project's
   `Jenkinsfile` instead of scaffolding an empty overlay.

6. **ArgoCD sync.** Once `homelab-gitops` is updated, ArgoCD picks up the change
   and syncs the cluster. **Never `kubectl apply` against homelab as a workflow
   step** — that bypasses GitOps and causes drift. (One-off `kubectl` against
   homelab is fine for inspection, debugging, and reading state.)

**Claude's responsibility:** Surface step 5 (the `homelab-gitops` overlay) as a
pre-flight check **before** the first Jenkins build of any new ArgoCD-managed
project — not after the build fails. Don't wait to be reminded.

---

## Build & Dependency Hygiene (sandbox-only — applies to every project)

**Never run language toolchains directly on the host.** This includes (but is not
limited to) `go build`, `go mod tidy`, `go test`, `npm install`, `npm run *`,
`pip install`, `pytest`, `cargo build`, `cargo test`, `mvn`, `gradle`, etc.

Use Podman with a throwaway container whose tag matches the `FROM` line in the
project's `Dockerfile`. Mount the repo at `/app`:

```bash
# Pattern (substitute the right base image for the language)
podman run --rm -v .:/app:Z -w /app <base-image> sh -c "<command>"

# Examples
podman run --rm -v .:/app:Z -w /app docker.io/golang:1.22-alpine sh -c "go mod tidy"
podman run --rm -v .:/app:Z -w /app docker.io/node:20-alpine     sh -c "npm install"
podman run --rm -v .:/app:Z -w /app docker.io/python:3.12-slim   sh -c "pip install -r requirements.txt"
```

Notes:
- The `:Z` mount flag is required on SELinux hosts; harmless elsewhere.
- Podman on WSL2 requires **fully-qualified image names** (`docker.io/golang:1.22`,
  not `golang:1.22`).
- See the `container-sandbox` skill for the full protocol.

This rule exists because uncontrolled toolchain use on the host pollutes module/build
caches and causes "works on my machine" drift between local and CI builds.

---

## CI/CD Pipeline (homelab standard)

**Triggering: manual.** Operator clicks "Build Now" in the Jenkins UI. See
*Development Workflow*, step 3.

All projects in this homelab use the same pipeline shape:

1. **Kaniko** builds the OCI image inside the cluster (no Docker daemon).
2. **Trivy** scans the image (non-blocking by default).
3. **Kustomize** overlay at `k8s/overlays/homelab/` is updated with the new image tag.
   *(Skip for projects that produce an image-only artifact with no synced k8s resources.)*
4. **ArgoCD** picks up the manifest change and syncs to the cluster.

**Pre-flight requirement (step 3):** the GitOps overlay path must already exist
in `homelab-gitops` before the stage runs — see *Development Workflow*, step 5.

| Variable | Value |
|----------|-------|
| Image registry | `ghcr.io/<github-username>/<repo-name>` |
| Image tag scheme | `<tag-scheme>` (typically `${BUILD_NUMBER}` or `${GIT_SHA}`) |
| Pipeline definition | `jenkins/Jenkinsfile` |
| Shared library | `jenkins-shared-lib` (see the `homelab-shared-lib` skill) |
| GitOps repo | `github.com/<github-username>/<gitops-repo-name>` |
| Overlay path | `apps/<app-name>/overlays/homelab` |

Standard shared-lib steps used: `buildKaniko`, `imageScanTrivy`, `updateGitOpsManifest`.
For Jenkinsfile patterns and snippets, see the `jenkinsfile-snippets` skill.

---

## Shared Infrastructure (cluster-wide constants)

| Resource | Value |
|----------|-------|
| Cluster name | `<cluster-name>` |
| Namespace (this project) | `<project-namespace>` |
| Ingress controller | HAProxy + cert-manager |
| Cert issuer | `local-ca-issuer` |
| TLS host(s) | `<host>.homelab` |
| Storage class | Longhorn (RWO default; RWX where explicitly noted) |
| Secrets management | external-secrets-operator (`jenkins-ssm-store`) |
| Service registry pattern | `http://<svc>.<namespace>.svc.cluster.local:<port>` |
| Image pull secret | `<image-pull-secret-name>` (typically `ghcr-pull-secret`) |

**In-cluster service URLs (this project):**

| Service | URL |
|---------|-----|
| `<service-1>` | `http://<svc-1>.<namespace>.svc.cluster.local:<port>` |
| `<service-2>` | `http://<svc-2>.<namespace>.svc.cluster.local:<port>` |

---

## Database

| Field | Value |
|-------|-------|
| Engine | `<postgres|mysql|sqlite|...>` |
| Deployment | `<StatefulSet|managed|external>` |
| Storage | `<longhorn-pvc-size>` |
| Backup | `<backup-strategy>` (e.g. daily `pg_dump` to S3 at `<time>`) |
| Connection secret | `<db-secret-name>` |
| Connection string env var | `DATABASE_URL` |

`<schema-flexibility / migration-strategy notes — only what isn't derivable from
inspecting migration files. Examples: JSONB column for forward-compat, soft-delete
convention, dedup contract shared between services, etc.>`

---

## Recommended File Skeleton (when expanding this template)

Add sections only if they apply. Follow this order so cross-project navigation stays
predictable:

1. Session State (above)
2. Cluster & Architecture (above)
3. Project Overview
4. Commands
5. Architecture
6. Shared Contracts (if monorepo or if this service shares state with others)
7. Development Workflow (above)
8. Build & Dependency Hygiene (above)
9. CI/CD Pipeline (above)
10. Shared Infrastructure (above)
11. Database
12. Environment Variables
13. Known Issues / Footguns

---

## Template provenance (delete after first fill-in)

This file was copied from `~/dotfiles/CLAUDE_TEMPLATE.md`. The dotfiles repo is **public**
and contains only placeholders. Real environment values (registry paths, hostnames,
namespaces, IPs, secret names) live **here** in the project-level `CLAUDE.md` and in
`CONTEXT_STATE.md` — never back in the template.

Once you've filled in every `<placeholder>`, delete:
- The top admonition block
- The `## TO CLAUDE — read this block FIRST` section
- This `## Template provenance` section

What remains is your project-level `CLAUDE.md`.
