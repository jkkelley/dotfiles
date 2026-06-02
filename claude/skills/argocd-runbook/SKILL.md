---
name: argocd-runbook
description: ArgoCD troubleshooting runbook and GitOps operation reference. Preloaded into the argocd-gitops agent.
---

# ArgoCD Runbook

## Sync Status Quick Reference

| Status | Meaning | Action |
|--------|---------|--------|
| `Synced` + `Healthy` | All good | — |
| `OutOfSync` | Drift detected | Review diff, sync if expected |
| `Progressing` | Rollout in flight | Wait or check rollout status |
| `Degraded` | Resource health failing | Check pod events/logs |
| `Missing` | Resource not in cluster | Check RBAC, namespace exists |
| `Unknown` | Health check not defined | Add custom health check |

## Debugging Commands

```bash
# App status and last operation
argocd app get <app-name>
argocd app get <app-name> --show-operation

# What's different (desired vs live)
argocd app diff <app-name>

# Force refresh (bypass cache)
argocd app get <app-name> --refresh

# Sync with dry run
argocd app sync <app-name> --dry-run

# Sync specific resources only
argocd app sync <app-name> --resource apps:Deployment:<name>

# Sync and wait for health
argocd app sync <app-name> --wait --health

# Hard refresh (re-fetch from git)
argocd app sync <app-name> --force

# View app logs
argocd app logs <app-name> -c <container>
```

## Repo & Connectivity

```bash
# List repos
argocd repo list

# Test repo connectivity
argocd repo get <repo-url>

# Add repo (HTTPS)
argocd repo add https://github.com/org/repo --username <user> --password <token>

# Add repo (SSH)
argocd repo add git@github.com:org/repo --ssh-private-key-path ~/.ssh/id_rsa
```

## RBAC Debugging

```bash
# Check what user can do
argocd account can-i sync applications '*'
argocd account can-i get applications 'my-project/*'

# List accounts
argocd account list

# Get user info
argocd account get --account <username>
```

## ApplicationSet Troubleshooting

```bash
# ApplicationSet controller logs (most problems are here)
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller -f

# List generated apps from an ApplicationSet
kubectl get applications -n argocd -l argocd.argoproj.io/application-set-name=<name>

# Describe ApplicationSet for events
kubectl describe applicationset <name> -n argocd
```

## Common Fixes

**App stuck OutOfSync with no changes:**
```bash
# ignoreDifferences for controller-managed fields (e.g., HPA replicas)
# Add to Application spec:
spec:
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas
```

**Sync wave ordering issues:**
```yaml
# Annotate resources with sync waves
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"   # lower = earlier
```

**Repo server cache stale:**
```bash
kubectl rollout restart deployment/argocd-repo-server -n argocd
```

**App stuck in Progressing forever:**
```bash
# Check if health check is undefined — add custom Lua health check
# Or check actual resource events
kubectl describe <resource> -n <app-ns>
```

## Sync Policy Cheatsheet

```yaml
syncPolicy:
  automated:
    prune: true        # delete resources removed from git
    selfHeal: true     # revert manual changes
  syncOptions:
  - CreateNamespace=true
  - ServerSideApply=true          # use SSA instead of client-side apply
  - RespectIgnoreDifferences=true # honor ignoreDifferences during sync
  - PrunePropagationPolicy=foreground
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

## Promotion Patterns

```bash
# Image tag update (CI pushes to config repo)
# 1. argocd-image-updater (automated):
argocd-image-updater.argoproj.io/image-list: myapp=registry/myapp
argocd-image-updater.argoproj.io/myapp.update-strategy: latest

# 2. Manual kustomize update:
cd apps/overlays/prod
kustomize edit set image registry/myapp:${NEW_TAG}
git commit -am "chore: promote myapp to ${NEW_TAG}"
git push
```

---

## ArgoCD Vault Plugin (AVP) — Homelab Pattern

AVP is installed as a CMP sidecar on `argocd-repo-server` (v1.18.1, arm64).
Vault auth: k8s auth role `argocd-repo-server` → policy `argocd-read` (reads `secret/data/homelab/*`).

Full troubleshooting runbook: `~/Documents/local-k8s-docs/runbooks/argocd-avp/argocd_avp_runbook.md`

### The correct CMP generate command

`argocd-vault-plugin generate ./` does **NOT** auto-detect Helm charts — it reads all files as raw Kubernetes YAML and fails. The avp-cmp-plugin ConfigMap must use this three-stage pipeline:

```yaml
generate:
  command:
    - sh
    - -c
    - |
      helm template "$ARGOCD_APP_NAME" . -n "$ARGOCD_APP_NAMESPACE" | argocd-vault-plugin generate - | sed -E 's/\b(replicas|containerPort|port|targetPort|number): "([0-9]+)"/\1: \2/g'
```

**Why `- |` (block literal):** The sed pattern contains `': "'` (colon-space-quote), a YAML mapping separator. A plain scalar sequence item with this pattern crashes the AVP sidecar on startup (`yaml: did not find expected key`). The block literal suppresses YAML special-character processing.

**Why the sed stage:** AVP wraps every substituted Vault value in double quotes (`replicas: "2"`). Kubernetes rejects quoted strings for integer fields. The sed strips quotes from known integer field names only. Do NOT use a broad pattern like `'s/: "([0-9]+)"$/: \1/'` — it will also convert `env.value: "3000"` to an integer, which Kubernetes rejects.

**Do NOT use `| int` in Helm templates** — Helm evaluates it against the placeholder string `<path:...>` before AVP runs, outputting `0`.

### Application source for AVP-enabled apps

Every AVP-enabled app needs a manifest in `argocd-apps/workloads/<app>.yaml`. Without it, the Application is an orphaned imperative object and won't receive GitOps updates.

```yaml
source:
  path: helm/myapp
  plugin:
    name: argocd-vault-plugin
# NOT: helm: { releaseName: myapp }
# ARGOCD_APP_NAME is injected by ArgoCD — AVP uses it as the Helm release name
# ARGOCD_APP_NAMESPACE is the destination namespace — required for {{ .Release.Namespace }}
```

### Placeholder format in values.yaml

```yaml
iamRoleArn:  <path:secret/data/homelab/roles#myapp-eso>
awsRegion:   <path:secret/data/homelab/apps/myapp#aws-region>
memoryLimit: <path:secret/data/homelab/apps/myapp#memory-limit>
host:        <path:secret/data/homelab/apps/myapp#host>
```

`imageTag` is **never** a placeholder — Jenkins yq writes it literally.

Numeric values (ports, replicas, resource limits) do NOT need `| int` — the sed post-processor handles them after AVP substitution.

### sync-wave ordering for Vault-backed ESO

| Wave | Resources |
|------|-----------|
| -2 | Vault ESO ServiceAccount + Vault-backed SecretStore |
| -1 | ExternalSecret (e.g. ghcr-pull-secret) |
|  0 | Deployment, Service, Ingress, SSM resources (default) |

If ExternalSecret (wave -1) deploys before SecretStore (wave 0), ESO fails with "could not get secret data from provider".

### AVP debugging

```bash
# Check AVP sidecar is running (should be 2/2)
kubectl get pod -n argocd -l app.kubernetes.io/name=argocd-repo-server

# Tail AVP logs during sync
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server -c avp -f

# Force re-sync (without argocd CLI — not installed on WSL2 host)
kubectl -n argocd annotate application <app> argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd patch application <app> --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Test full AVP pipeline manually in the sidecar
REPO_POD=$(kubectl get pod -n argocd -l app.kubernetes.io/name=argocd-repo-server -o name | head -1)
kubectl cp ~/projects/homelab-gitops/helm/<app> argocd/${REPO_POD#pod/}:/tmp/test -c avp
kubectl exec -n argocd $REPO_POD -c avp -- sh -c \
  'helm template <app> /tmp/test -n <namespace> | argocd-vault-plugin generate -' \
  | grep -E "replicas:|containerPort:|namespace:"

# Verify Vault connectivity from AVP container
kubectl exec -n argocd $REPO_POD -c avp -- vault status

# Check Vault k8s auth role
kubectl exec -n vault vault-0 -- vault read auth/kubernetes/role/argocd-repo-server
```

### Common AVP failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| AVP sidecar in CrashLoopBackOff, `yaml: did not find expected key` | CMP command has `': "'` in a plain scalar sequence item | Use YAML block literal (`- \|`) for the generate command sequence item |
| Resources deploy with literal `<path:...>` names | `avp generate ./` used instead of helm pipeline; or Application still on `helm:` source | Apply correct ConfigMap; add `argocd-apps/workloads/<app>.yaml` with `plugin:` source |
| `cannot unmarshal string into ... of type int32` | AVP quotes all values; sed stage missing or wrong | Apply ConfigMap with sed stage; do NOT use `\| int` in templates |
| `env.value` becomes integer, Deployment rejected | sed pattern too broad — matches `value:` field | Use field-name-targeted sed: `\b(replicas\|containerPort\|port\|targetPort\|number):` |
| `namespace default is not permitted in project` | `helm template` missing `-n "$ARGOCD_APP_NAMESPACE"` | Add `-n "$ARGOCD_APP_NAMESPACE"` to helm template command |
| ExternalSecret `could not get secret data from provider` | SecretStore wave 0 deploys after ExternalSecret wave -1 | Move SecretStore + its SA to wave -2 |
| `error when patching: unrecognized type: int32` | Old Helm field manager metadata on existing resource | Delete the resource; ArgoCD recreates it cleanly |
| `could not find secret` in ArgoCD sync log | Vault path wrong or key missing | `vault kv get secret/homelab/...` to verify |
| Placeholder literal in cluster (not resolved) | Vault auth failing silently | Check AVP container logs; verify `argocd-repo-server` k8s role |
