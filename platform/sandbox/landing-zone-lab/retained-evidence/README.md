# Retained Project A evidence root

This root owns only the intentionally retained archive and Terraform-state
resources after the lab is retired:

- the archive bucket, versioning, public-access block, encryption, policy, and
  existing 90-day lifecycle;
- the audit KMS key and alias;
- the Terraform-state bucket, versioning, public-access block, ownership, and
  encryption;
- the state KMS key and alias.

Its remote state key is `retained-evidence/terraform.tfstate`. The protected
retirement workflow transfers/imports ownership and requires a zero-change plan
before any lab resource is destroyed. The root contains no deployable lab
network, trail, Config recorder, flow log, or workload IAM resource.

