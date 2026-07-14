# Central audit logging template

This module is an offline, reviewable template for a centralized audit path. It
declares a Log Archive S3 bucket, a KMS key, a multi-region CloudTrail trail
with log-file validation enabled, and an AWS Config recorder plus delivery
channel. It has no provider configuration and must not be applied from this
repository.

Organization CloudTrail / org-trail appears here as interface semantics for an
organization-scoped delivery path into Log Archive. The template does not assert
that an org-trail is enabled in AWS, and no cloud deployment is authorized from
this repository.

Versioning and lifecycle retention are both required because recovery depends on
restoring prior audit objects while still enforcing a bounded review window.
Fail-closed review inputs `enable_log_file_validation` and
`enable_archive_versioning` default to `true` and must stay true; setting either
false fails offline validation. A human must approve bucket names, KMS
administrators, retention periods, recorder scope, and delivery prefixes before
any separate deployment is considered.

Run only offline checks:

```powershell
terraform fmt -check -recursive
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
```

See the [logging architecture](../../docs/architecture/logging.md), the
[audit review guide](../../docs/operations/audit-review.md), and the
[audit troubleshooting guide](../../docs/operations/audit-troubleshooting.md).
