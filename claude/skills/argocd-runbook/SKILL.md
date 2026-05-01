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
