variable "aws_region" {
  description = "Commercial AWS region for the sandbox proof."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Short prefix for sandbox resource names."
  type        = string
  default     = "project-a-sandbox"
}
