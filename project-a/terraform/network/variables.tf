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

  validation {
    # Pairwise non-overlap/non-nest using cidrhost (this Terraform pin has no cidrcontains).
    condition = alltrue([
      for a in keys(var.private_subnets) : alltrue([
        for b in keys(var.private_subnets) :
        a == b || !can(cidrnetmask(var.private_subnets[a].cidr)) || !can(cidrnetmask(var.private_subnets[b].cidr)) || !(
          (
            cidrhost(format("%s/%s", cidrhost(var.private_subnets[a].cidr, 0), split("/", var.private_subnets[b].cidr)[1]), 0)
            == cidrhost(var.private_subnets[b].cidr, 0)
            ) || (
            cidrhost(format("%s/%s", cidrhost(var.private_subnets[b].cidr, 0), split("/", var.private_subnets[a].cidr)[1]), 0)
            == cidrhost(var.private_subnets[a].cidr, 0)
          )
        )
      ])
    ])
    error_message = "Private subnet CIDRs must not overlap or nest within each other."
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
  description = "Must remain false. Public or unrestricted ingress exceptions on the private workload boundary fail offline validation. Opening ingress is an extension-blocked change."
  type        = bool
  default     = false

  validation {
    condition     = var.allow_unrestricted_ingress == false
    error_message = "Unrestricted public ingress exceptions are blocked for the private workload boundary."
  }
}

variable "allow_unrestricted_egress" {
  description = "Must remain false (default deny). Unrestricted egress exceptions on the private workload boundary fail offline validation. Opening egress is an extension-blocked change pending a separate human-approved egress design."
  type        = bool
  default     = false

  validation {
    condition     = var.allow_unrestricted_egress == false
    error_message = "Unrestricted egress exceptions are blocked for the private workload boundary."
  }
}

variable "sg_exception_attempts" {
  description = "Typed security-group exception review shape (CIDR, port, protocol). Must remain empty/deny in this baseline; any non-empty exception attempt fails closed and is extension-blocked pending a separate human-approved design."
  type = object({
    cidrs    = optional(list(string), [])
    ports    = optional(list(number), [])
    protocol = optional(string, "")
  })
  default = {
    cidrs    = []
    ports    = []
    protocol = ""
  }

  validation {
    condition = (
      length(var.sg_exception_attempts.cidrs) == 0 &&
      length(var.sg_exception_attempts.ports) == 0 &&
      var.sg_exception_attempts.protocol == ""
    )
    error_message = "SG exception attempts (non-empty CIDR, port, or protocol) are blocked for the private workload boundary in this baseline."
  }
}
