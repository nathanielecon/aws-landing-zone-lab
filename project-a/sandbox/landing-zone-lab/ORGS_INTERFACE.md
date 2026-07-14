# Organization module — design interface (not applied)

## Constraint

This lab runs in **one** AWS account (`283077380808`). AWS Organizations member
accounts are separate billed accounts. One account cannot host six real member
accounts.

## What stays validated

The `project-a/terraform/organization` module remains the reviewed multi-account
interface:

- OU taxonomy: Security, Infrastructure, Workloads
- Member account creation interface (`aws_organizations_account`)
- SCP attachment interface (`deny_leave_organization`)
- Offline `terraform fmt` / `init -backend=false` / `validate`

## Why member accounts are not created

- No unique per-account emails are available for H1-approved member creation.
- Applying the organization module would either fail or require fabricating
  emails — both violate the honest claims boundary.
- Tag/prefix theater labeled as "accounts" is explicitly banned by the lab plan.

## Stretch path (later)

If six unique emails become available (including alias forms) and Organizations
is enabled on the management account, reopen the multi-account track: apply the
organization module, add assume-role providers, split identity/network/audit
into member accounts, and rewrite rubrics/claims upward. Until then, do **not**
write "multi-account cloud validation."
