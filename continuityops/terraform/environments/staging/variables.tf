variable "aws_region" {
  description = "AWS region for the staging lab."
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "Target AWS account ID. Replace before apply; never commit real production IDs."
  type        = string
  default     = "283077380808"  # ContinuityOps lab account
}

variable "vpc_cidr" {
  description = "VPC CIDR for staging."
  type        = string
  default     = "10.42.0.0/16"
}

variable "availability_zones" {
  description = "AZs used by staging subnets."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway (default false for lab cost control)."
  type        = bool
  default     = false
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "EKS node instance type."
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired EKS node count."
  type        = number
  default     = 1
}

variable "lambda_package_path" {
  description = "Path to the worker Lambda zip relative to this environment root."
  type        = string
  default     = "../../../serverless/build/worker.zip"
}

variable "alarm_sns_topic_arn" {
  description = "Optional SNS topic for CloudWatch alarms."
  type        = string
  default     = ""
}
