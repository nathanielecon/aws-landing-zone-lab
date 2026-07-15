locals {
  organizational_units = toset(["Security", "Infrastructure", "Workloads"])

  accounts = {
    security_tooling       = { name = "Security Tooling", ou = "Security" }
    log_archive            = { name = "Log Archive", ou = "Security" }
    network                = { name = "Network", ou = "Infrastructure" }
    shared_services        = { name = "Shared Services", ou = "Infrastructure" }
    nonproduction_workload = { name = "Non-production Workload", ou = "Workloads" }
    production_workload    = { name = "Production Workload", ou = "Workloads" }
  }

  scps = {
    deny_leave_organization = {
      description = "Prevents member accounts in the approved target OU from leaving the organization."
      content = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid      = "DenyLeavingOrganization"
          Effect   = "Deny"
          Action   = "organizations:LeaveOrganization"
          Resource = "*"
        }]
      })
    }
  }
}

resource "aws_organizations_organization" "this" {
  feature_set = "ALL"
}

resource "aws_organizations_organizational_unit" "this" {
  for_each  = local.organizational_units
  name      = each.value
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_account" "this" {
  for_each = local.accounts

  name                       = each.value.name
  email                      = var.account_emails[each.key]
  parent_id                  = aws_organizations_organizational_unit.this[each.value.ou].id
  role_name                  = var.account_access_role_name
  iam_user_access_to_billing = "DENY"
  close_on_deletion          = false
}

resource "aws_organizations_policy" "scp" {
  for_each = local.scps

  name        = each.key
  description = each.value.description
  content     = each.value.content
  type        = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy_attachment" "scp" {
  for_each = var.scp_attachments

  policy_id = aws_organizations_policy.scp[each.key].id
  target_id = aws_organizations_organizational_unit.this[each.value].id
}
