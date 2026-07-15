# Audit troubleshooting

Related: [blocked-change catalog](blocked-change-catalog.md),
[network failure cases](network-failure-cases.md),
[logging architecture](../architecture/logging.md),
[audit module template](../../terraform/audit/README.md).

## CloudTrail objects are missing

First check the approved bucket name, trail prefix, and KMS alias against the
change record. Then confirm the trail is intended to be multi-region and that
log-file validation remains enabled. Stop and escalate if the proposed fix would
disable integrity validation (**BC-AUD-03**), enable an organization trail
(**BC-AUD-05**, `is_organization_trail = true` — org-trail stays interface-only),
shorten retention, or redirect delivery to an unapproved bucket. Offline,
`enable_log_file_validation = false` fails closed via
`rejects_disabled_log_file_validation`; `is_organization_trail = true` fails
closed via `rejects_organization_trail_enabled`.

## AWS Config snapshots are missing

First check the recorder name, delivery channel bucket, and config prefix.
Confirm the recorder scope was approved for the target accounts and regions.
Stop and escalate if the proposed fix would widen recorder scope, weaken bucket
controls, or bypass the Log Archive account.

## Archive bucket objects were overwritten or deleted

Use bucket versioning history through separately approved operator access to
recover prior objects, then confirm lifecycle retention still preserves the
required review window. Record the recovery path and escalate if retention or
versioning changed without approval (**BC-AUD-04**). Offline,
`enable_archive_versioning = false` fails closed via
`rejects_disabled_archive_versioning`.

## KMS access blocks delivery

Confirm the approved key alias and key policy owner before changing any access
path. Stop and escalate if the proposed repair adds wildcard principals,
cross-account trust outside the approved boundary, or a plaintext logging path.

This guide is design-time operator guidance only. No live log-service call,
cloud login, or deployment action is authorized from this repository. Public
archive ACL or missing-CMK attempts are fail-closed offline (**BC-AUD-02**);
disabling log-file validation or archive versioning is likewise fail-closed
(**BC-AUD-03** / **BC-AUD-04**); enabling an organization trail is fail-closed
(**BC-AUD-05**). See the
[blocked-change catalog](blocked-change-catalog.md). For flow-log emission and
private-boundary triage before archive delivery, see
[network failure cases](network-failure-cases.md).
