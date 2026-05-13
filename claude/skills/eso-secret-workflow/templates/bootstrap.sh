#!/usr/bin/env bash
# bootstrap.sh — One-time cluster bootstrap for ESO Templated Discovery
#
# Run once per cluster. Annotates the ArgoCD cluster secret with the AWS
# account ID so ApplicationSets can construct IAM role ARNs at sync time
# without any account ID or ARN ever touching Git.
#
# Safe to re-run — kubectl annotate uses --overwrite.

set -euo pipefail

# ── Prompts ────────────────────────────────────────────────────────────────

read -rp "AWS profile to use (leave blank for default): " AWS_PROFILE
read -rp "AWS region (e.g. us-east-2): " AWS_REGION
read -rp "kubectl context for target cluster: " KUBE_CONTEXT

# ── Resolve account ID ─────────────────────────────────────────────────────

AWS_ARGS=(--region "${AWS_REGION}")
if [[ -n "${AWS_PROFILE}" ]]; then
  AWS_ARGS+=(--profile "${AWS_PROFILE}")
fi

echo ""
echo "Fetching AWS account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity \
  "${AWS_ARGS[@]}" \
  --query 'Account' \
  --output text)

echo "Account ID: ${ACCOUNT_ID}"
echo ""

# ── Find the ArgoCD cluster secret ────────────────────────────────────────
# ArgoCD stores one Secret per registered cluster, labelled:
#   argocd.argoproj.io/secret-type: cluster
# For a single-cluster homelab this is the only cluster secret.
# For multi-cluster, scope this script to the correct context.

CLUSTER_SECRET=$(kubectl --context "${KUBE_CONTEXT}" \
  get secret -n argocd \
  -l argocd.argoproj.io/secret-type=cluster \
  -o jsonpath='{.items[0].metadata.name}')

if [[ -z "${CLUSTER_SECRET}" ]]; then
  echo "ERROR: No ArgoCD cluster secret found in namespace 'argocd'."
  echo "Ensure ArgoCD is installed and the cluster is registered."
  exit 1
fi

echo "ArgoCD cluster secret: ${CLUSTER_SECRET}"
echo ""

# ── Annotate ───────────────────────────────────────────────────────────────

kubectl --context "${KUBE_CONTEXT}" \
  annotate secret "${CLUSTER_SECRET}" \
  -n argocd \
  "aws_account_id=${ACCOUNT_ID}" \
  --overwrite

echo "Annotated '${CLUSTER_SECRET}' with aws_account_id=${ACCOUNT_ID}"
echo ""

# ── Verify ─────────────────────────────────────────────────────────────────

ANNOTATED=$(kubectl --context "${KUBE_CONTEXT}" \
  get secret "${CLUSTER_SECRET}" \
  -n argocd \
  -o jsonpath='{.metadata.annotations.aws_account_id}')

if [[ "${ANNOTATED}" == "${ACCOUNT_ID}" ]]; then
  echo "✓ Verification passed. ApplicationSets can now construct IAM role ARNs."
  echo ""
  echo "  ARN pattern: arn:aws:iam::${ACCOUNT_ID}:role/{NAMESPACE}-eso-role"
  echo ""
  echo "Next step: run terraform apply for each namespace that needs ESO."
else
  echo "ERROR: Annotation verification failed."
  echo "  Expected: ${ACCOUNT_ID}"
  echo "  Got:      ${ANNOTATED}"
  exit 1
fi
