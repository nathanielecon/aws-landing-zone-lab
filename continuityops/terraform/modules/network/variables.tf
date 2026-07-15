variable "name_prefix" {
  description = "Prefix for network resource names (e.g. continuityops-staging)."
  type        = string
}

variable "vpc_cidr" {
  description = "RFC 1918 CIDR block for the VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for public and private subnets."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.42.1.0/24", "10.42.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)."
  type        = list(string)
  default     = ["10.42.11.0/24", "10.42.12.0/24"]
}

variable "enable_nat_gateway" {
  description = "Create a single NAT gateway for private subnet egress. Default false for lab cost control."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags applied to all network resources."
  type        = map(string)
  default     = {}
}
