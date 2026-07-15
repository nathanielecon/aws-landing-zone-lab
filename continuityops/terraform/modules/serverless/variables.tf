variable "name_prefix" {
  description = "Prefix for serverless resource names."
  type        = string
}

variable "lambda_package_path" {
  description = "Path to the Lambda deployment package (zip) relative to the calling root module."
  type        = string
  default     = "../../../serverless/build/worker.zip"
}

variable "lambda_handler" {
  description = "Lambda function handler."
  type        = string
  default     = "index.handler"
}

variable "lambda_runtime" {
  description = "Lambda runtime identifier."
  type        = string
  default     = "provided.al2023"
}

variable "lambda_timeout_seconds" {
  description = "Lambda function timeout in seconds."
  type        = number
  default     = 30
}

variable "lambda_memory_mb" {
  description = "Lambda function memory in MB."
  type        = number
  default     = 256
}

variable "sqs_visibility_timeout_seconds" {
  description = "SQS visibility timeout (should be >= Lambda timeout)."
  type        = number
  default     = 60
}

variable "sqs_message_retention_seconds" {
  description = "SQS message retention period."
  type        = number
  default     = 345600
}

variable "dlq_max_receive_count" {
  description = "Max receives before a message is sent to the DLQ."
  type        = number
  default     = 3
}

variable "tags" {
  description = "Additional tags applied to serverless resources."
  type        = map(string)
  default     = {}
}
