variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the EKS control plane and node group."
  type        = list(string)
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version (1.29 or newer)."
  type        = string
  default     = "1.29"

  validation {
    condition     = can(regex("^1\\.(29|[3-9][0-9])", var.kubernetes_version))
    error_message = "kubernetes_version must be 1.29 or newer."
  }
}

variable "node_instance_type" {
  description = "Instance type for the managed node group."
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired node count for the managed node group."
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum node count for the managed node group."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum node count for the managed node group."
  type        = number
  default     = 2
}

variable "tags" {
  description = "Additional tags applied to EKS resources."
  type        = map(string)
  default     = {}
}
