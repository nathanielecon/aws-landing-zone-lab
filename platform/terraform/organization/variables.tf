variable "account_emails" {
  description = "Human-approved account email addresses keyed by the documented account names."
  type = object({
    security_tooling       = string
    log_archive            = string
    network                = string
    shared_services        = string
    nonproduction_workload = string
    production_workload    = string
  })

  validation {
    condition = alltrue([
      for email in values(var.account_emails) : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email))
    ])
    error_message = "Each account email must be a valid, human-approved email address."
  }
}

variable "account_access_role_name" {
  description = "Role AWS Organizations creates in new accounts; its permissions are defined separately."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.account_access_role_name))
    error_message = "Use a valid IAM role name."
  }
}

variable "scp_attachments" {
  description = "Human-approved SCP-to-OU attachment map. Keys are policy names and values are OU names."
  type        = map(string)
  default = {
    deny_leave_organization = "Workloads"
  }

  validation {
    condition     = alltrue([for target in values(var.scp_attachments) : contains(["Security", "Infrastructure", "Workloads"], target)])
    error_message = "SCP attachments may target only the documented Security, Infrastructure, or Workloads OUs."
  }
}
