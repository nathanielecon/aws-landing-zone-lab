variable "trail_name" {
  description = "Approved CloudTrail name for the centralized audit trail."
  type        = string
}

variable "config_recorder_name" {
  description = "Approved AWS Config recorder name."
  type        = string
}

variable "archive_bucket_name" {
  description = "Approved Log Archive S3 bucket name."
  type        = string
}

variable "kms_alias_name" {
  description = "Approved alias name for the audit KMS key."
  type        = string

  validation {
    condition     = can(regex("^alias/.+", var.kms_alias_name))
    error_message = "Audit KMS alias must be a non-empty alias/* name; missing KMS alias is rejected offline."
  }
}

variable "allow_public_archive_acls" {
  description = "Must remain false. Attempting public ACLs on the Log Archive bucket fails offline validation."
  type        = bool
  default     = false

  validation {
    condition     = var.allow_public_archive_acls == false
    error_message = "Public ACLs on the Log Archive bucket are forbidden."
  }
}

variable "require_customer_managed_kms" {
  description = "Must remain true. Missing customer-managed KMS for archive SSE fails offline validation."
  type        = bool
  default     = true

  validation {
    condition     = var.require_customer_managed_kms == true
    error_message = "Log Archive objects require customer-managed KMS encryption."
  }
}

variable "cloudtrail_prefix" {
  description = "S3 prefix for CloudTrail delivery."
  type        = string
  default     = "cloudtrail"
}

variable "config_prefix" {
  description = "S3 prefix for AWS Config delivery."
  type        = string
  default     = "config"
}

variable "flow_logs_prefix" {
  description = "S3 prefix for VPC Flow Logs delivery into the Log Archive bucket. Empty disables the flow-logs bucket-policy statements."
  type        = string
  default     = "vpc-flow-logs"
}

variable "retention_days" {
  description = "Minimum retention window for audit objects before expiration."
  type        = number
  default     = 365

  validation {
    condition     = var.retention_days >= 90
    error_message = "Audit retention must preserve at least 90 days of review history."
  }
}

variable "config_snapshot_delivery_frequency" {
  description = "Approved AWS Config snapshot cadence."
  type        = string
  default     = "TwentyFour_Hours"

  validation {
    condition = contains([
      "One_Hour",
      "Three_Hours",
      "Six_Hours",
      "Twelve_Hours",
      "TwentyFour_Hours"
    ], var.config_snapshot_delivery_frequency)
    error_message = "Config snapshot delivery frequency must use an approved AWS Config enum."
  }
}

variable "enable_log_file_validation" {
  description = "Must remain true. Disabling CloudTrail log-file validation fails offline validation."
  type        = bool
  default     = true

  validation {
    condition     = var.enable_log_file_validation == true
    error_message = "CloudTrail log-file validation must remain enabled."
  }
}

variable "enable_archive_versioning" {
  description = "Must remain true. Disabling Log Archive bucket versioning fails offline validation."
  type        = bool
  default     = true

  validation {
    condition     = var.enable_archive_versioning == true
    error_message = "Log Archive bucket versioning must remain enabled."
  }
}
