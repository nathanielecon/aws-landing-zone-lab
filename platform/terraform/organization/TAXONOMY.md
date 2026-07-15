# Organization taxonomy checklist

Offline consistency assert for the multi-account **design interface**.
This file is documentation only — not a live AWS inventory and not an apply
authorization. Compare these rows to `docs/architecture/accounts.md`,
`docs/architecture/overview.md`, `docs/guardrails/organizations.md`, and
`main.tf` locals in this module. Any rename, add, or remove requires a new H1.

## Expected OUs

| OU name | In `main.tf` `organizational_units` | SCP attachable |
| --- | --- | --- |
| Security | yes | yes |
| Infrastructure | yes | yes |
| Workloads | yes | yes (default for `deny_leave_organization`) |

Organization root and individual accounts are **not** valid SCP attachment
targets in this baseline.

## Expected member accounts (design only)

| Terraform key | Account name | Parent OU | In `accounts.md` |
| --- | --- | --- | --- |
| `security_tooling` | Security Tooling | Security | yes |
| `log_archive` | Log Archive | Security | yes |
| `network` | Network | Infrastructure | yes |
| `shared_services` | Shared Services | Infrastructure | yes |
| `nonproduction_workload` | Non-production Workload | Workloads | yes |
| `production_workload` | Production Workload | Workloads | yes |

## Management boundary

| Account | Member-create interface | Notes |
| --- | --- | --- |
| Management | **no** | Owns Organizations and billing only; outside the member-account loop |

## Variable keys that must stay aligned

`var.account_emails` object keys must equal the Terraform keys above
(`security_tooling`, `log_archive`, `network`, `shared_services`,
`nonproduction_workload`, `production_workload`).
`var.scp_attachments` values must be only `Security`, `Infrastructure`, or
`Workloads`.

## Manual drift check (offline)

1. Diff this table against the Proposed multi-account taxonomy table in
   [`../../docs/architecture/accounts.md`](../../docs/architecture/accounts.md).
2. Diff OU and account display names against
   [`../../docs/architecture/overview.md`](../../docs/architecture/overview.md)
   § Account and OU taxonomy.
3. Diff `locals.organizational_units` / `locals.accounts` in `main.tf`.
4. Diff SCP target validation in `variables.tf` and the prose in
   [`../../docs/guardrails/organizations.md`](../../docs/guardrails/organizations.md).
5. Fail the review if any name, parent OU, or key drifts without a new H1.

## Related

- [Accounts and OU taxonomy](../../docs/architecture/accounts.md)
- [Platform architecture overview](../../docs/architecture/overview.md)
- [Organizations guardrails](../../docs/guardrails/organizations.md)
- [S3 backend decision](../../docs/decisions/backend.md)
- [Secrets decision](../../docs/decisions/secrets.md)
- [Organization module README](README.md)
