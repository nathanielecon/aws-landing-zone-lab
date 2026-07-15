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

variable "eks_cluster_name" {
  description = "EKS cluster name for kubernetes.io/cluster/<name> subnet tags. Leave empty to skip cluster tags."
  type        = string
  default     = ""
}

variable "eks_cluster_tag_value" {
  description = "Value for kubernetes.io/cluster/<name> tag: shared or owned."
  type        = string
  default     = "shared"

  validation {
    condition     = contains(["shared", "owned"], var.eks_cluster_tag_value)
    error_message = "eks_cluster_tag_value must be shared or owned."
  }
}

variable "public_subnet_tags" {
  description = "Optional extra tags applied to public subnets (merged after ELB role tags)."
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Optional extra tags applied to private subnets (merged after internal ELB role tags)."
  type        = map(string)
  default     = {}
}
