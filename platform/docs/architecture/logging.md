# Logging and audit architecture

## Ownership boundaries

| Account | Owns | Does not own |
| --- | --- | --- |
| **Log Archive** | Protected storage for audit objects: the S3 archive bucket, versioning, public-access blocking, lifecycle retention, and the customer-managed KMS key that encrypts archived CloudTrail, Config, and flow-log deliveries | VPC boundaries, workload routing, or Security Tooling runtime services |
| **Security Tooling** | The centralized audit *path*: organization CloudTrail / org-trail interface semantics, AWS Config recorder and delivery-channel interfaces, and the review/troubleshooting workflow that lands events in Log Archive | The durable archive bucket itself (Log Archive owns protected storage) |
| **Network** | VPC Flow Logs *emission* from the private VPC boundary toward a human-approved Log Archive S3 ARN | Archive bucket policy, KMS key policy, retention, or trail/recorder configuration |

The Security Tooling account owns the centralized audit path. CloudTrail and AWS
Config write to a dedicated Log Archive S3 bucket protected by versioning,
server-side encryption, and public-access blocking. **The Log Archive account
owns that protected storage**—bucket, KMS, versioning, public-access block, and
retention—so Security Tooling can operate the trail/recorder interfaces without
reassigning storage ownership. The design is multi-region so global service
events and regional control-plane activity land in one review path.

Organization CloudTrail (org-trail) is part of that design as an interface
semantic: the intended control plane for organization-scoped trail delivery into
Log Archive. The audit module exposes typed `is_organization_trail` (default
`false`, fail-closed) so reviewers can see the interface without enabling it.
This repository models the trail, bucket, KMS, and Config interfaces only; it
does not enable an org-trail in AWS, does not claim a live organization trail
exists, and does not authorize cloud deployment.

CloudTrail log-file validation stays enabled so investigators can prove whether
archived trail objects were modified after delivery. AWS Config snapshots and
configuration history use the same archive bucket with a separate prefix to keep
retention and review scope explicit. This repository defines the interfaces only;
it does not deploy the bucket, KMS key, trail, or recorder.

Object versioning and lifecycle retention are both part of the recovery model.
Versioning preserves prior objects for rollback or overwrite investigation, while
lifecycle retention sets a minimum window for review before any expiration action.
Human review must confirm bucket ownership, KMS key policy, retention periods,
delivery prefixes, and recorder scope before a separately controlled deployment.

Use the [audit review guide](../operations/audit-review.md), the
[audit troubleshooting guide](../operations/audit-troubleshooting.md), the
[blocked-change catalog](../operations/blocked-change-catalog.md), and the
[audit module](../../terraform/audit/README.md) together. This repository is
repo-only, not cloud validated, and not authorized for live log-service calls.
