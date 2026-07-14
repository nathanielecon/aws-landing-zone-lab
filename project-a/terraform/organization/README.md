# Organizations baseline

This module defines the proposed AWS Organizations topology only. It has no
provider configuration and must not be applied from this repository. Under the
single-account Landing Zone lab, member accounts are intentionally **not**
created — see
[`../../sandbox/landing-zone-lab/ORGS_INTERFACE.md`](../../sandbox/landing-zone-lab/ORGS_INTERFACE.md).
A human must approve account emails, account-creation semantics, OU topology, and SCP
attachments at H1 before any separately controlled multi-account deployment is considered.

## Topology

- Security: Security Tooling and Log Archive.
- Infrastructure: Network and Shared Services.
- Workloads: Non-production Workload and Production Workload.

The Management account owns Organizations and billing; it is not modelled as a
member account. `account_emails` and `account_access_role_name` are required
inputs so no real identifiers or principals are committed. `close_on_deletion`
is false to prevent Terraform from requesting account closure.

## Guardrail boundary

The `deny_leave_organization` SCP is an explicit attachment interface, with a
default attachment to Workloads. SCPs set maximum permission boundaries; they
do not grant access. IAM roles and permission boundaries are defined in the
separate identity task. Attachment targets are restricted to the three
documented OUs and require H1 review before any deployment.

Run only offline checks during this task:

```powershell
terraform fmt -check -recursive
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
```

See the [account architecture](../../docs/architecture/accounts.md),
[Organizations guardrails](../../docs/guardrails/organizations.md), and the
offline [TAXONOMY.md](TAXONOMY.md) consistency checklist.
