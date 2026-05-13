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
