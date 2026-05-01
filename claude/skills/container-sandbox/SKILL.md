---
name: container-sandbox
description: Run all dependency-heavy tasks (npm, go, pip) in isolated Podman containers.
---

# Dependency Isolation Protocol

**RULE:** Never run `npm install`, `go mod download`, or `pip install` on the host. 

## 1. Choosing the Sandbox
- **Small Tasks:** Use the **Single-Use Container** (Podman).
- **Cluster Tasks:** Use the **Kind Sandbox** (Kind + Podman).

## 2. Dependency Management (The "No-Clutter" Way)

### Node.js (npm)
Instead of `npm install`, tell the agent to run:
```bash
podman run --rm -v .:/app:Z -w /app node:20-slim npm install && npm test

## Lifecycle Management
- **Pre-flight:** Always run `./scripts/verify-readiness.sh` before starting a cluster.
- **Teardown:** When the task is complete, run `./scripts/cleanup-kind-podman.sh`.
- **Maintenance:** If disk space is low or images are outdated, run `./scripts/prune-images.sh`.