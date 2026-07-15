variable "state_bucket_name" {
  description = "Globally unique placeholder name for the separately managed S3 state bucket."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "Use a valid lowercase S3 bucket name."
  }
}

variable "primary_region" {
  description = "Human-approved primary AWS region; this contract makes no default choice."
  type        = string
}

variable "kms_key_alias" {
  description = "Non-secret alias for the separately managed state KMS key."
  type        = string
}
