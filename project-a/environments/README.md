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

Use the [validation guide](../docs/validation.md), the
[baseline runbook](../docs/operations/baseline-runbook.md), and
[cost and teardown guidance](../docs/operations/cost-and-teardown.md) together.
