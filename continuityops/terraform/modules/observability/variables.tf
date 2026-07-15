variable "name_prefix" {
  description = "Prefix for observability resource names."
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name (defaults to /continuityops/<name_prefix>)."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 14
}

variable "alarm_namespace" {
  description = "CloudWatch metric namespace for alarms."
  type        = string
  default     = "ContinuityOps/Lab"
}

variable "alarm_metric_name" {
  description = "Metric name monitored by the baseline alarm."
  type        = string
  default     = "ErrorCount"
}

variable "alarm_threshold" {
  description = "Alarm threshold for the baseline metric."
  type        = number
  default     = 5
}

variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate for the alarm."
  type        = number
  default     = 2
}

variable "alarm_period_seconds" {
  description = "Metric period in seconds."
  type        = number
  default     = 300
}

variable "alarm_sns_topic_arn" {
  description = "Optional SNS topic ARN for alarm actions. Leave empty to scaffold alarm without actions."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags applied to observability resources."
  type        = map(string)
  default     = {}
}
