variable "aws_region" {
  description = "AWS region for bootstrap resources."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform remote state. Replace before enabling bootstrap."
  type        = string
  default     = "REPLACE_ME-continuityops-terraform-state"
}

variable "lock_table_name" {
  description = "DynamoDB table name for state locking. Replace before enabling bootstrap."
  type        = string
  default     = "REPLACE_ME-continuityops-terraform-locks"
}

variable "create_bootstrap_resources" {
  description = "When false (default), no AWS resources are created — safe for offline terraform validate."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to bootstrap resources when created."
  type        = map(string)
  default = {
    Project   = "continuityops"
    ManagedBy = "terraform"
    Component = "bootstrap"
  }
}
