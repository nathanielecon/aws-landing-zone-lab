output "organization_id" {
  description = "Organization identifier after an explicitly approved apply."
  value       = aws_organizations_organization.this.id
}

output "organizational_unit_ids" {
  description = "Organizational unit identifiers keyed by documented OU name."
  value       = { for name, ou in aws_organizations_organizational_unit.this : name => ou.id }
}

output "account_ids" {
  description = "Account identifiers keyed by documented account name after an explicitly approved apply."
  value       = { for name, account in aws_organizations_account.this : name => account.id }
}
