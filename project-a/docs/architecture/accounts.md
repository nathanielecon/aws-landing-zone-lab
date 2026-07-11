# Accounts and organizational units

This is a repo-only proposed topology. It is not cloud validated, and no AWS
accounts or organization resources have been created by this repository.

| Parent | Account | Responsibility |
| --- | --- | --- |
| Management | Management | Organizations and billing only |
| Security | Security Tooling | Security tooling and delegated security services |
| Security | Log Archive | Protected audit-log destination |
| Infrastructure | Network | Network ownership and shared network interfaces |
| Infrastructure | Shared Services | Shared platform services |
| Workloads | Non-production Workload | Non-production application workloads |
| Workloads | Production Workload | Production application workloads |

The Terraform module has explicit `aws_organizations_account` resources, but
it is a reviewed account-creation interface, not authorization to create an
account. Account email addresses and the initial cross-account role name are
typed inputs. Before an apply outside this repository, H1 must approve each
email, the account owner and billing contact, the initial role, break-glass
access, and the consequence of creating an account in the target organization.

The Management account is deliberately outside the member-account loop. It
owns Organizations and billing but does not host workloads. Account IDs and the
organization ID are outputs only after an approved deployment; they are never
committed as values here.

See the [Organizations guardrail boundary](../guardrails/organizations.md) and
the [platform architecture contract](overview.md).
