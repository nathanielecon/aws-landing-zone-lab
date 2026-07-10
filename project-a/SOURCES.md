# Primary design sources

Checked 2026-07-10. These sources constrain the candidate plan; they do not
constitute cloud validation.

- [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3): S3 lockfiles, versioning recommendation, and deprecated DynamoDB locking.
- [Terraform validate](https://developer.hashicorp.com/terraform/cli/commands/validate): offline-oriented configuration validation and its remote-service limitation.
- [Terraform provider requirements](https://developer.hashicorp.com/terraform/language/providers/requirements): provider source/version constraints and committed dependency lock files.
- [Terraform 1.15.5 release](https://github.com/hashicorp/terraform/releases/tag/v1.15.5): target CLI release.
- [AWS provider 6.36.0](https://registry.terraform.io/providers/hashicorp/aws/6.36.0/docs): target provider line.
- [AWS Security Reference Architecture](https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/architecture.html): reference OUs/accounts and separation of duties.
- [AWS Organizations security](https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/organizations-security.html): organization guardrails and change-impact review.
- [IAM best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html): multi-account guardrails and Access Analyzer validation.
- [IAM resources in AWS SRA](https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/iam-resources.html): SCP, permission-boundary, human, and machine policy roles.
- [AWS SRA Network account](https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/network.html): centralized network patterns and flow-log boundaries.
- [AWS SRA Log Archive account](https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/log-archive.html): centralized protected logging and integrity controls.
- [Azure landing-zone management groups](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/resource-org-management-groups): policy-driven subscription hierarchy.
- [Compare Azure Government and global Azure](https://learn.microsoft.com/en-us/azure/azure-government/compare-azure-government-global-azure): environment and endpoint differences.
- [Azure sovereign landing zone](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/sovereign-landing-zone): sovereignty-oriented landing-zone translation context.
