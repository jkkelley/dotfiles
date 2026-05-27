---
name: eso-secret-workflow
description: >
  ESO + IRSA + Terraform identity workflow for any k8s namespace.
  Invoke when wiring secrets for a new namespace OR adding a new SSM
  parameter to an existing namespace setup. Covers the full stack:
  Terraform identity, ApplicationSet ARN discovery, ESO delivery.
---

# ESO Secret Workflow — Staff-Level Standard

## When to Invoke

- A new namespace needs to pull secrets from AWS SSM via ESO
- A new SSM parameter needs to reach a pod in an already-wired namespace
- A secret is about to go into a ConfigMap, manifest, or Git — stop and use this instead

---

## ⚡ HOMELAB CLUSTER OVERRIDE — Read This Before Anything Else

> Verified 2026-05-26 against the live homelab cluster. These facts override the generic
> patterns below. Do NOT follow the generic naming or bootstrap steps for this cluster.

**Before proceeding — ask the user these two questions (do not guess or use cached values):**
1. *"What is your AWS account ID?"* → store as `{AWS_ACCOUNT_ID}`
2. *"What AWS profile should I use?"* → store as `{AWS_PROFILE}`

**Retrieve the cluster OIDC issuer URL from SSM** (never hardcode it):
```bash
aws ssm get-parameter \
  --name /infra/cluster/oidc-issuer-url \
  --region us-east-2 \
  --query 'Parameter.Value' \
  --output text \
  --profile {AWS_PROFILE}
```
This returns the public OIDC discovery endpoint. Use it as `{OIDC_ISSUER_URL}` in IAM trust policies.
If the parameter does not exist yet, ask the user to provide the URL and create it first:
```bash
aws ssm put-parameter \
  --name /infra/cluster/oidc-issuer-url \
  --value "https://YOUR-OIDC-URL" \
  --type String \
  --region us-east-2 \
  --profile {AWS_PROFILE}
```

### What is actually deployed

| Fact | Value |
|---|---|
| ESO version | v2.4.1 (Helm chart `external-secrets-2.4.1`) |
| API version | `external-secrets.io/v1` — **not** `v1beta1` |
| SSM region | `us-east-2` — all homelab SSM parameters live here |
| Working reference | `prospector` namespace — copy its manifests as the canonical template |

### Actual naming convention (deviates from generic skill below)

```
IAM role name:       {NAMESPACE}-eso-role        ← same as generic
ESO ServiceAccount:  {NAMESPACE}-ssm-sa          ← NOT {NAMESPACE}-eso-sa
SecretStore name:    aws-ssm                      ← same as generic
SSM path prefix:     /{NAMESPACE}/               ← same as generic
```

### Role ARN injection — no ApplicationSet templating needed

The role ARN is **hardcoded directly in `serviceaccount.yaml`**, not injected by an ApplicationSet.
The ArgoCD cluster secret uses annotation key `eso_role_arn` (not `aws_account_id`).
Skip Flow A step 3 (ApplicationSet wiring) entirely — it is not used on this cluster.

```yaml
# serviceaccount.yaml — exact pattern from prospector
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {NAMESPACE}-ssm-sa
  namespace: {NAMESPACE}
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::{AWS_ACCOUNT_ID}:role/{NAMESPACE}-eso-role
```

```yaml
# secretstore.yaml — exact pattern from prospector
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-ssm
  namespace: {NAMESPACE}
spec:
  provider:
    aws:
      service: ParameterStore
      region: us-east-2
      auth:
        jwt:
          serviceAccountRef:
            name: {NAMESPACE}-ssm-sa
```

### Bootstrap prereq — already done

The OIDC provider is registered and working (proven by prospector and job-hunter).
Skip Flow A step 1 (bootstrap check) — the cluster is already bootstrapped.

### Trust policy `sub` condition for new IAM roles

```
system:serviceaccount:{NAMESPACE}:{NAMESPACE}-ssm-sa
```

---

## Concepts

| Term | What it is |
|---|---|
| SSM Parameter | Where the secret value lives. Source of truth. Managed by Terraform. |
| IAM Role | Grants ESO permission to read SSM. One role per namespace. Created by Terraform. |
| OIDC Provider | Lets k8s ServiceAccounts assume IAM roles. Cluster-wide, one-time setup. |
| ESO ServiceAccount | The k8s identity ESO uses. Annotated with the IAM role ARN via ApplicationSet. |
| SecretStore | Namespace-scoped bridge between ESO and SSM. One per namespace, name always `aws-ssm`. |
| ExternalSecret | Declares which SSM paths become which k8s Secret keys. |
| Sync Wave -1 | ArgoCD annotation ensuring ESO resolves secrets before dependent resources start. |
| Templated Discovery | ApplicationSet constructs the IAM role ARN from `{{metadata.annotations.aws_account_id}}` on the ArgoCD cluster secret. The account ID is never in Git. |

---

## NAMING CONVENTION — Read Before Touching Anything

Terraform and the ApplicationSet must agree on role names exactly.
Deviation causes a silent ARN mismatch — ESO auth fails, pods CrashLoop, no obvious error.

```
IAM role name:       {NAMESPACE}-eso-role
ESO ServiceAccount:  {NAMESPACE}-eso-sa
SecretStore name:    aws-ssm              ← constant across ALL namespaces
SSM path prefix:     /{NAMESPACE}/        ← all secrets for a namespace live here
```

The ApplicationSet constructs the full ARN at sync time using the cluster secret annotation:

```
arn:aws:iam::{{metadata.annotations.aws_account_id}}:role/{NAMESPACE}-eso-role
```

`aws_account_id` is set once on the ArgoCD cluster secret by `templates/bootstrap.sh`.
It is **never** in Git. The GitOps repo is 100% account-agnostic.

---

## Flow A: New Namespace Setup

Run these steps in order. Do not skip the prereq check.

```
[ ] 1. PREREQ — Verify cluster bootstrap
        Check that aws_account_id annotation exists on the ArgoCD cluster secret.
        If missing, run templates/bootstrap.sh before anything else.

        kubectl get secret -n argocd \
          -l argocd.argoproj.io/secret-type=cluster \
          -o jsonpath='{.items[0].metadata.annotations.aws_account_id}'

        Expected: a 12-digit AWS account ID.
        Empty output → run bootstrap.sh now.

[ ] 2. TERRAFORM — Create identity and write secrets to SSM
        Copy templates/terraform.tf. Set: var.namespace, var.region, var.oidc_issuer_url.
        Add one aws_ssm_parameter block per secret this namespace needs.

        terraform init
        terraform plan   # review IAM role name, SSM paths, policy scope
        terraform apply

        Terraform creates:
          - IAM role: {NAMESPACE}-eso-role
          - IAM policy scoped to /{NAMESPACE}/* SSM paths only
          - All SSM SecureString parameters for this namespace
          - Audit parameter: /infra/iam/{NAMESPACE}-eso-role-arn

[ ] 3. GITOPS — Wire the ApplicationSet
        Add the cluster generator fragment from templates/applicationset-fragment.yaml
        to your ApplicationSet in homelab-gitops. Confirm:
          - generator uses cluster selector label: {NAMESPACE}/managed: "true"
          - values.esoRoleName is set to: {NAMESPACE}-eso-role
          - The role-arn annotation is injected via the Kustomize patch INSIDE the
            ApplicationSet manifest (spec.source.kustomize.patches) — NOT in
            serviceaccount.yaml. ApplicationSet {{...}} expressions are substituted
            only in the ApplicationSet manifest itself, not in synced source files.

[ ] 4. GITOPS — Add ESO manifests
        Create homelab-gitops/apps/{NAMESPACE}/eso/ with:
          serviceaccount.yaml   (from templates/serviceaccount.yaml — no role-arn
                                  annotation here; ApplicationSet patch injects it)
          secretstore.yaml      (from templates/secretstore.yaml)
          externalsecret.yaml   (from templates/externalsecret.yaml)

        For resources that must have secrets before they start (NATS, Postgres init):
          Use templates/externalsecret-wave.yaml (sync-wave: "-1") instead.

[ ] 5. GITOPS — Push and sync
        git push → ArgoCD syncs the new manifests.

        Force sync if needed:
        kubectl -n argocd patch application {APP} --type merge \
          -p '{"operation":{"sync":{"revision":"HEAD","syncStrategy":{"hook":{}}}}}'

[ ] 6. VERIFY — ExternalSecrets are READY
        kubectl get externalsecrets -n {NAMESPACE}
        All rows must show READY=True before dependent pods start.

        If not ready:
        kubectl describe externalsecret {NAME} -n {NAMESPACE}
        # Status.Conditions shows exactly which SSM path failed and why.

[ ] 7. VERIFY — k8s Secrets exist and pods are healthy
        kubectl get secrets -n {NAMESPACE}
        kubectl describe pod {POD} -n {NAMESPACE}
        Confirm secrets are mounted / env vars present.
```

---

## Flow B: Add a Secret to an Existing Namespace

Use this when the namespace already has a working SecretStore and ESO ServiceAccount.

```
[ ] 1. SSM — Put the parameter
        aws ssm put-parameter \
          --name /{NAMESPACE}/{SECRET_NAME} \
          --type SecureString \
          --value "the-value" \
          --region {REGION} \
          [--profile {AWS_PROFILE}]

        Verify immediately:
        aws ssm get-parameter \
          --name /{NAMESPACE}/{SECRET_NAME} \
          --with-decryption \
          --query 'Parameter.Value' \
          --output text \
          --region {REGION} \
          [--profile {AWS_PROFILE}]

[ ] 2. GITOPS — Add the ExternalSecret entry
        Option A: append a new data entry to an existing ExternalSecret.
        Option B: add a new ExternalSecret file for a new logical secret group.
                  Use templates/externalsecret.yaml as the base.
                  Use templates/externalsecret-wave.yaml if the consuming resource
                  must have this secret before it starts.

        Key rules:
          - secretStoreRef.name must be: aws-ssm
          - remoteRef.key must match the full SSM path: /{NAMESPACE}/{SECRET_NAME}
          - target.creationPolicy: Owner
          - target.deletionPolicy: Retain

[ ] 3. VERIFY
        kubectl get externalsecret {NAME} -n {NAMESPACE}
        kubectl describe externalsecret {NAME} -n {NAMESPACE}
        kubectl get secret {TARGET_SECRET_NAME} -n {NAMESPACE}
```

---

## Common Failures

| Symptom | Root Cause | Fix |
|---|---|---|
| ExternalSecret not READY, status: SecretSyncedError | SSM path typo or parameter does not exist | `aws ssm get-parameter --name /exact/path --with-decryption` |
| ESO auth error / AccessDenied in ESO logs | Trust policy namespace or SA name mismatch | Check `sub` condition: `system:serviceaccount:{NAMESPACE}:{NAMESPACE}-eso-sa` |
| ARN construction resolves to wrong role | Role name deviates from `{NAMESPACE}-eso-role` | Fix Terraform var.namespace or role name |
| `aws_account_id` annotation empty | bootstrap.sh never ran for this cluster | Run `templates/bootstrap.sh` |
| ExternalSecret READY but pod crashes on start | Order-dependent secret missing sync wave | Switch to `externalsecret-wave.yaml` (sync-wave: "-1") |
| Secret exists but pod gets wrong value | SSM path missing namespace prefix | Verify full path: `/{NAMESPACE}/{SECRET_NAME}` |
| ExternalSecret READY but k8s Secret not created | `creationPolicy` misconfigured | Must be `Owner`, not `Orphan` or `Merge` |
