variable "github_organization" {
  description = "Human-approved GitHub organization allowed to assume the workload role."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]{1,39}$", var.github_organization))
    error_message = "Use a GitHub organization name."
  }
}

variable "github_repository" {
  description = "Human-approved GitHub repository allowed to assume the workload role."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]{1,100}$", var.github_repository))
    error_message = "Use a GitHub repository name."
  }
}

variable "github_branch" {
  description = "Protected branch permitted by the workload trust policy."
  type        = string
  default     = "main"

  validation {
    condition     = var.github_branch == "main"
    error_message = "Only the protected main branch is permitted."
  }
}

variable "audit_bucket_name" {
  description = "Human-approved audit bucket name; no account identifier is committed."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.audit_bucket_name))
    error_message = "Use a valid S3 bucket name."
  }
}

variable "oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN. Default is a documentation-only placeholder account for offline review; live applies must supply the real provider ARN."
  type        = string
  default     = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:oidc-provider/token\\.actions\\.githubusercontent\\.com$", var.oidc_provider_arn))
    error_message = "Use a GitHub Actions OIDC provider ARN."
  }
}
