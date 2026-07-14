variable "environment" {
  description = "Environment whose private network boundary is being reviewed."
  type        = string

  validation {
    condition     = contains(["nonproduction", "production"], var.environment)
    error_message = "Environment must be nonproduction or production."
  }
}

variable "vpc_cidr" {
  description = "Human-approved RFC 1918 CIDR for this VPC."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && can(regex("^(10\\.|172\\.(1[6-9]|2[0-9]|3[0-1])\\.|192\\.168\\.)", var.vpc_cidr))
    error_message = "VPC CIDR must be an RFC 1918 IPv4 network."
  }
}

variable "private_subnets" {
  description = "At least two human-approved private subnet CIDRs and availability zones."
  type = map(object({
    availability_zone = string
    cidr              = string
  }))

  validation {
    condition = (
      length(var.private_subnets) >= 2 &&
      alltrue([
        for subnet in values(var.private_subnets) :
        can(cidrnetmask(subnet.cidr)) &&
        subnet.availability_zone != "" &&
        can(regex("^(10\\.|172\\.(1[6-9]|2[0-9]|3[0-1])\\.|192\\.168\\.)", subnet.cidr))
      ])
    )
    error_message = "Provide at least two private subnets with valid RFC 1918 CIDRs and non-empty availability zones."
  }
}

variable "flow_logs_destination_arn" {
  description = "Human-approved Log Archive S3 destination ARN for VPC Flow Logs."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:s3:::", var.flow_logs_destination_arn))
    error_message = "Flow logs must target an S3 ARN owned by the Log Archive boundary."
  }
}

variable "allow_unrestricted_ingress" {
  description = "Must remain false. Public or unrestricted ingress exceptions on the private workload boundary fail offline validation."
  type        = bool
  default     = false

  validation {
    condition     = var.allow_unrestricted_ingress == false
    error_message = "Unrestricted public ingress exceptions are blocked for the private workload boundary."
  }
}
