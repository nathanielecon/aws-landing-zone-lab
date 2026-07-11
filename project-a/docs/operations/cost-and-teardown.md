# Cost and teardown guidance

This repository is not cloud validated, but operators still need to understand
cost drivers before any separate deployment. The main cost drivers in this
design are NAT Gateway or Transit Gateway extensions if they are later approved,
CloudTrail and Config log storage in S3, KMS key usage, and any retained flow
logs or audit snapshots.

## Cost review

- Check whether a proposed change adds NAT Gateway, Transit Gateway, or another
  cross-network component outside the current private-only boundary.
- Check whether CloudTrail, Config, and flow logs all point at the intended Log
  Archive S3 destination with the approved retention window.
- Check whether KMS key usage, bucket versioning, and retention settings align
  with the expected billing and recovery window.

## Teardown boundary

Do not destroy from this repository. If a separately deployed environment needs
teardown after validation, remove after validation only through an approved
operator workflow that preserves the audit trail, captures final evidence, and
documents retained logs before deletion.

## Stop and escalate

Stop and escalate when cost pressure is used to justify removing audit events
captured by CloudTrail, Config, or flow logs, shortening retention below the
approved review window, or bypassing the archive destination to save charges.
