# Environment compositions

`project-a` is an orchestration shell, not a deployable root module. The real
building blocks live in the bootstrap, organization, identity, network, and
audit submodules. Environment composition means selecting approved inputs and
reviewing how those modules would be combined for nonproduction and production
without committing credentials, state, or live provider configuration.

## Composition intent

- Nonproduction receives separate backend keys, account IDs, CIDR ranges, and
  audit prefixes from production.
- Production keeps a stricter approval path, distinct state location, and a
  separate review record for any identity, network, or logging exception.
- The root `project-a` directory stays empty on purpose so `terraform validate`
  and `terraform test` can confirm there is no accidental live deployment entry
  point in this repository.

## Deepened environment compositions

Both `nonproduction/main.tf` and `production/main.tf` wire non-secret module
inputs for identity, network, and audit into one reviewable locals/outputs
composition. A shared `log_archive_bucket_name` token (`example-log-archive`)
aligns:

- identity `audit_bucket_name`
- network `flow_logs_destination_arn` (`arn:aws:s3:::…/vpc-flow-logs`)
- audit `archive_bucket_name`

and keeps `is_organization_trail = false` (org-trail interface-only). Backend
keys, audit prefixes, CIDRs, and trail/recorder names stay distinct per
environment. No provider block, secrets, credentials, or module `source` apply
path is present. Reviewers inspect the outputs offline—these directories are
not live deployment entry points.

Use the [validation guide](../docs/validation.md), the
[baseline runbook](../docs/operations/baseline-runbook.md), and
[cost and teardown guidance](../docs/operations/cost-and-teardown.md) together.
