locals {
  # Least-privilege baseline; workload_action_overrides must stay empty (fail-closed).
  workload_actions = concat(
    ["s3:PutObject", "s3:AbortMultipartUpload"],
    var.workload_action_overrides
  )

  oidc_trust_conditions = {
    StringEquals = {
      "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
      "token.actions.githubusercontent.com:sub" = "repo:${var.github_organization}/${var.github_repository}:ref:refs/heads/${var.github_branch}"
    }
  }

  workload_trust = {
    Version = "2012-10-17"
    Statement = [{
      Sid    = "GitHubActionsFromProtectedBranch"
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      # require_oidc_trust_conditions is fail-closed (must be true); negation would drop aud/sub.
      Condition = var.require_oidc_trust_conditions ? local.oidc_trust_conditions : {}
    }]
  }

  workload_permissions = {
    Version = "2012-10-17"
    Statement = [{
      Sid      = "WriteAuditObjects"
      Effect   = "Allow"
      Action   = local.workload_actions
      Resource = "arn:aws:s3:::${var.audit_bucket_name}/workload/*"
    }]
  }

  permission_boundary = {
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowAuditWriteOnly"
      Effect   = "Allow"
      Action   = local.workload_actions
      Resource = "arn:aws:s3:::${var.audit_bucket_name}/workload/*"
    }]
  }
}

resource "aws_iam_policy" "workload" {
  name        = "workload-audit-write"
  description = "Least-privilege audit object writes for the approved workload role."
  policy      = jsonencode(local.workload_permissions)
}

resource "aws_iam_policy" "permission_boundary" {
  name        = "workload-audit-boundary"
  description = "Permission boundary limiting delegated workload roles to audit writes."
  policy      = jsonencode(local.permission_boundary)
}

resource "aws_iam_role" "workload" {
  name               = "workload-audit-writer"
  assume_role_policy = jsonencode(local.workload_trust)
  # require_permissions_boundary is fail-closed (must be true); negation would drop the cap.
  permissions_boundary = var.require_permissions_boundary ? aws_iam_policy.permission_boundary.arn : null
}

resource "aws_iam_role_policy_attachment" "workload" {
  role       = aws_iam_role.workload.name
  policy_arn = aws_iam_policy.workload.arn
}
