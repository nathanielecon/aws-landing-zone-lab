output "workload_role_name" {
  description = "Proposed workload role name after separately approved deployment."
  value       = aws_iam_role.workload.name
}

output "workload_trust_policy" {
  description = "Inspectable protected-branch trust policy proposed for human review."
  value       = local.workload_trust
}
