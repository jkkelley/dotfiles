---
name: kubectl-runbook
description: Quick reference for kubectl commands and Kubernetes troubleshooting workflows. Preloaded into the k8s-master agent.
---

# kubectl Runbook

## Debugging Hierarchy (always in this order)

```bash
# 1. Events first — fastest signal
kubectl get events -n <ns> --sort-by='.lastTimestamp' | tail -20

# 2. Describe — full picture
kubectl describe pod <pod> -n <ns>

# 3. Logs — current and previous container
kubectl logs <pod> -n <ns> --tail=100
kubectl logs <pod> -n <ns> --previous

# 4. Exec in — when you need to poke around
kubectl exec -it <pod> -n <ns> -- sh
```

## Pod Lifecycle Quick Checks

| Status | First Check |
|--------|-------------|
| `Pending` | `kubectl describe pod` → Events: quota, node selector, taints, PVC |
| `CrashLoopBackOff` | `kubectl logs --previous` → exit code, OOM, misconfig |
| `ImagePullBackOff` | Registry creds, image tag exists, network to registry |
| `OOMKilled` | Increase memory limit or find leak: `kubectl top pod` |
| `Terminating` stuck | Finalizers: `kubectl patch pod <pod> -p '{"metadata":{"finalizers":[]}}' --type=merge` |

## Resource Management

```bash
# Resource usage live
kubectl top pods -n <ns> --sort-by=memory
kubectl top nodes

# Check resource requests vs limits
kubectl get pods -n <ns> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources}{"\n"}{end}'

# Find pods with no resource requests (danger)
kubectl get pods -A -o json | jq '.items[] | select(.spec.containers[].resources.requests == null) | .metadata.name'
```

## RBAC Debugging

```bash
# Can this service account do X?
kubectl auth can-i get pods --as=system:serviceaccount:<ns>:<sa> -n <ns>

# What can this user do?
kubectl auth can-i --list --as=<user>

# Show all roles in namespace
kubectl get roles,rolebindings,clusterroles,clusterrolebindings -n <ns>
```

## Networking Debugging

```bash
# Test DNS resolution from inside cluster
kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never -- nslookup <service>.<ns>.svc.cluster.local

# Test connectivity between pods
kubectl run nettest --image=nicolaka/netshoot --rm -it --restart=Never -- bash
# Inside: curl http://<service>.<ns>.svc.cluster.local:<port>

# Check service endpoints (empty = selector mismatch)
kubectl get endpoints <service> -n <ns>

# Decode NetworkPolicy (what's allowed)
kubectl get networkpolicies -n <ns> -o yaml
```

## Node Operations

```bash
# Drain node safely
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

# Cordon (stop scheduling) / Uncordon
kubectl cordon <node>
kubectl uncordon <node>

# What's running on a node
kubectl get pods -A --field-selector spec.nodeName=<node>

# Node conditions
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[-1]}{"\n"}{end}'
```

## Rollout Management

```bash
# Status
kubectl rollout status deployment/<name> -n <ns>

# History
kubectl rollout history deployment/<name> -n <ns>

# Rollback
kubectl rollout undo deployment/<name> -n <ns>
kubectl rollout undo deployment/<name> --to-revision=2 -n <ns>

# Restart (rolling)
kubectl rollout restart deployment/<name> -n <ns>
```

## etcd & Control Plane

```bash
# Check control plane health
kubectl get componentstatuses

# etcd member health (from control plane node)
etcdctl member list --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key

# Snapshot etcd
etcdctl snapshot save /backup/etcd-$(date +%F).db
```

## Helm Quick Reference

```bash
helm list -A                                    # all releases
helm status <release> -n <ns>                  # release status
helm history <release> -n <ns>                 # revision history
helm rollback <release> <revision> -n <ns>     # rollback
helm get values <release> -n <ns>              # current values
helm diff upgrade <release> <chart> -f vals.yaml  # preview changes (requires helm-diff)
```

## One-Liners Worth Memorizing

```bash
# All non-running pods
kubectl get pods -A --field-selector=status.phase!=Running

# Pods sorted by restart count
kubectl get pods -A --sort-by='.status.containerStatuses[0].restartCount'

# Delete all evicted pods
kubectl get pods -A | grep Evicted | awk '{print $2 " -n " $1}' | xargs -L1 kubectl delete pod

# Watch events in real time
kubectl get events -A --watch --sort-by='.lastTimestamp'

# Force delete stuck pod
kubectl delete pod <pod> -n <ns> --grace-period=0 --force
```
