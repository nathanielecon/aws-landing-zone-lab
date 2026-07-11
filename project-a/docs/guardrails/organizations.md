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

No SCP is attached to Management by this module. This boundary avoids treating
an organization guardrail as an access-control grant and keeps billing and
organization administration under human review.
