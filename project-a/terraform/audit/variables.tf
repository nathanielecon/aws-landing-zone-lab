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
