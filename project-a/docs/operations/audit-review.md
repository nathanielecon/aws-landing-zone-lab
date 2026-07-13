# Audit review guide

Review CloudTrail and AWS Config as one evidence stream. Confirm the trail is
multi-region, log-file validation is enabled, the archive bucket is versioned,
and the KMS key alias matches the approved security boundary before trusting any
delivered records. Treat organization CloudTrail / org-trail as the intended
organization-scoped interface into Log Archive; this repository documents that
interface only and does not claim a live org-trail deployment.

## First review checks

1. Verify the approved bucket name, trail name, Config recorder name, and KMS
   alias match the change record.
2. Confirm the archive bucket blocks public access and uses the expected
   lifecycle retention window.
3. Confirm CloudTrail writes under the trail prefix and Config writes under the
   config prefix so investigators can distinguish event history from resource
   snapshots.

## What this path captures

- CloudTrail captures management events across regions plus integrity metadata
  for delivered trail files.
- AWS Config captures configuration history and scheduled snapshots for the
  approved recorder scope.
- Versioned objects support recovery review when an archive object is overwritten
  or unexpectedly deleted.

## Review boundary

Do not call AWS APIs from this repository to inspect a trail, bucket, or Config
recorder. Use separately approved operator access for live review. Record gaps,
ownership questions, and retention mismatches in the incident notes, then link
back to the [logging architecture](../architecture/logging.md) and the
[audit module template](../../terraform/audit/README.md).
