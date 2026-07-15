# Organizations guardrails

AWS Organizations and service control policies (SCPs) establish guardrails,
not permissions. An SCP can restrict the maximum available permissions, but it
cannot grant an IAM principal access. IAM roles and their permission boundaries
remain a separate, reviewed concern.

The baseline declares one SCP: `deny_leave_organization`. It denies
`organizations:LeaveOrganization` and is attached through an explicit,
human-reviewed `scp_attachments` map. The default attachment target is the
Workloads OU. The interface permits only Security, Infrastructure, or
Workloads OUs; attaching to the organization root or individual accounts is
outside this baseline and requires a new review.

Before deployment, H1 must review the complete attachment map, expected impact
on every descendant account, break-glass and service exception paths, and any
new SCP statement. Removing or changing an SCP attachment can change the
effective permissions of every account below that OU, so it must be performed
through the same controlled deployment process.

## Blocked change example (H1)

Attaching an SCP to the organization root or to an individual account is outside
this baseline and must be rejected at H1. The module's `scp_attachments`
validation accepts only the documented Security, Infrastructure, or Workloads
OUs; a proposed map that targets root or an account ID fails offline review and
must not proceed to any separately controlled deployment. Enabling
`close_on_deletion` on an account resource is likewise a blocked change: H1 must
keep account-closure semantics false so Terraform cannot request account
closure.

No SCP is attached to Management by this module. This boundary avoids treating
an organization guardrail as an access-control grant and keeps billing and
organization administration under human review.

## Related

- [Platform architecture overview](../architecture/overview.md)
- [Accounts and OU taxonomy](../architecture/accounts.md)
- [S3 backend decision](../decisions/backend.md)
- [Secrets decision](../decisions/secrets.md)
- [Organization taxonomy checklist](../../terraform/organization/TAXONOMY.md)
