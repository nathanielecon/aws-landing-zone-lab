# Audit troubleshooting

## CloudTrail objects are missing

First check the approved bucket name, trail prefix, and KMS alias against the
change record. Then confirm the trail is intended to be multi-region and that
log-file validation remains enabled. Stop and escalate if the proposed fix would
disable integrity validation, shorten retention, or redirect delivery to an
unapproved bucket.

## AWS Config snapshots are missing

First check the recorder name, delivery channel bucket, and config prefix.
Confirm the recorder scope was approved for the target accounts and regions.
Stop and escalate if the proposed fix would widen recorder scope, weaken bucket
controls, or bypass the Log Archive account.

## Archive bucket objects were overwritten or deleted

Use bucket versioning history through separately approved operator access to
recover prior objects, then confirm lifecycle retention still preserves the
required review window. Record the recovery path and escalate if retention or
versioning changed without approval.

## KMS access blocks delivery

Confirm the approved key alias and key policy owner before changing any access
path. Stop and escalate if the proposed repair adds wildcard principals,
cross-account trust outside the approved boundary, or a plaintext logging path.

This guide is design-time operator guidance only. No live log-service call,
cloud login, or deployment action is authorized from this repository. For the
offline template shape and intended defaults, see the
[audit module template](../../terraform/audit/README.md).
