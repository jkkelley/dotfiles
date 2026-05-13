# terraform.tf — ESO IRSA module for one namespace
#
# Usage: copy this file, set the variables, run terraform apply.
# Terraform creates the IAM role, scoped permissions policy, and all SSM
# parameters for the namespace. Nothing sensitive touches Git.
#
# Required variables: namespace, region, oidc_issuer_url
# Add one aws_ssm_parameter block per secret this namespace needs.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ── Variables ─────────────────────────────────────────────────────────────

variable "namespace" {
  type        = string
  description = "Kubernetes namespace. Drives role name, SA name, SSM path prefix."
}

variable "region" {
  type        = string
  description = "AWS region (e.g. us-east-2)."
}

variable "oidc_issuer_url" {
  type        = string
  description = "OIDC issuer URL for the cluster (no trailing slash). e.g. https://<oidc-id>.cloudfront.net"
}

# ── Dynamic account ID — never hardcoded ──────────────────────────────────

data "aws_caller_identity" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  role_name    = "${var.namespace}-eso-role"     # MUST match ApplicationSet values.esoRoleName
  sa_name      = "${var.namespace}-eso-sa"
  ssm_prefix   = "/${var.namespace}"
  oidc_issuer  = trimprefix(var.oidc_issuer_url, "https://")
}

# ── IAM trust policy ─────────────────────────────────────────────────────
# Scoped to the exact namespace + service account. No wildcard subjects.

data "aws_iam_policy_document" "eso_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${local.account_id}:oidc-provider/${local.oidc_issuer}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${local.sa_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ── IAM permissions policy ────────────────────────────────────────────────
# Scoped to /{namespace}/* only. Never grants cross-namespace SSM access.

data "aws_iam_policy_document" "eso_ssm" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${local.account_id}:parameter${local.ssm_prefix}/*",
    ]
  }
}

# ── IAM role ──────────────────────────────────────────────────────────────

resource "aws_iam_role" "eso" {
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.eso_trust.json

  tags = {
    namespace   = var.namespace
    managed-by  = "terraform"
  }
}

resource "aws_iam_policy" "eso_ssm" {
  name        = "${var.namespace}-eso-ssm-policy"
  description = "ESO SSM read access for namespace ${var.namespace}"
  policy      = data.aws_iam_policy_document.eso_ssm.json
}

resource "aws_iam_role_policy_attachment" "eso_ssm" {
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.eso_ssm.arn
}

# ── SSM parameters ────────────────────────────────────────────────────────
# Add one block per secret. type = SecureString. Never use String for secrets.
#
# Example:
#
# resource "aws_ssm_parameter" "database_url" {
#   name  = "/${var.namespace}/database-url"
#   type  = "SecureString"
#   value = var.database_url        # pass via TF_VAR or tfvars file, not hardcoded
# }
#
# resource "aws_ssm_parameter" "api_key" {
#   name  = "/${var.namespace}/api-key"
#   type  = "SecureString"
#   value = var.api_key
# }

# ── Audit trail ───────────────────────────────────────────────────────────
# Stores the role ARN in SSM for reference. ESO does not read this path —
# the ApplicationSet constructs the ARN directly from the cluster annotation.

resource "aws_ssm_parameter" "role_arn_audit" {
  name  = "/infra/iam/${var.namespace}-eso-role-arn"
  type  = "SecureString"
  value = aws_iam_role.eso.arn

  tags = {
    purpose    = "audit-trail"
    namespace  = var.namespace
    managed-by = "terraform"
  }
}

# ── Outputs ───────────────────────────────────────────────────────────────

output "eso_role_arn" {
  value       = aws_iam_role.eso.arn
  description = "IAM role ARN for the ESO ServiceAccount in namespace ${var.namespace}."
}

output "eso_role_name" {
  value       = local.role_name
  description = "Must match ApplicationSet values.esoRoleName exactly."
}
