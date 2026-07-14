# Accounts and organizational units

This repository defines a **multi-account design interface** (Organizations /
OU / SCP) and, separately, a **single-account live lab**. The multi-account
foundation remains repo-only / not cloud-validated.

| Mode | Status |
| --- | --- |
| Organization module (OU + member interface + SCP) | Offline-validated design interface — **member accounts not created**; multi-account Orgs **not** cloud-validated |
| Live lab account `283077380808` / `us-east-1` | **APPLIED** / cloud-validated — collapsed identity + network + audit via GitHub OIDC CI ([run 29366105164](https://github.com/nathanielecon/cloud/actions/runs/29366105164), role `project-a-lzlab-gha`); see [`EVIDENCE.md`](../../sandbox/landing-zone-lab/EVIDENCE.md) |

## Proposed multi-account taxonomy (design only)

| Parent | Account | Responsibility |
| --- | --- | --- |
| Management | Management | Organizations and billing only |
| Security | Security Tooling | Security tooling and delegated security services |
| Security | Log Archive | Protected audit-log destination |
| Infrastructure | Network | Network ownership and shared network interfaces |
| Infrastructure | Shared Services | Shared platform services |
| Workloads | Non-production Workload | Non-production application workloads |
| Workloads | Production Workload | Production application workloads |

Management stays **outside** the member-account creation loop: it owns
Organizations and billing only and is not created through the member-account
interface.

## H1 typed inputs (required before any member create)

The Terraform organization module exposes reviewed account-creation
**interfaces**, not authorization to create accounts. The following remain
**typed inputs** until **H1** human approval:

| Input | H1 requirement |
| --- | --- |
| Account emails | Unique, non-placeholder member emails approved at H1 |
| Owners | Named owner / cost-owner contacts per account approved at H1 |
| Initial cross-account role name | Role name string approved at H1 (no silent default elevation) |
| Break-glass consequences | H1 must record who may break-glass, under what ticket/control, and that misuse is a security incident with immediate access review |

Member accounts are **not** created in this lab because there is a single
billed account and no H1-approved unique member emails/owners. Details:
[`../../sandbox/landing-zone-lab/ORGS_INTERFACE.md`](../../sandbox/landing-zone-lab/ORGS_INTERFACE.md).

### Blocked changes that invalidate H1

Examples that must fail offline review and must not proceed without a new H1:

- Changing OU taxonomy (add/remove/rename Security, Infrastructure, Workloads
  accounts or parents) after an H1 packet was approved
- Substituting placeholder emails or owners for H1-approved values
- Changing the initial cross-account role name without re-approval
- Enabling `close_on_deletion` on account resources
- Attaching SCPs to organization root or individual accounts (see
  [organizations guardrails](../guardrails/organizations.md))

## Live single-account lab (separate from foundation)

In account `283077380808`, the Landing Zone lab collapses identity, private
network, and audit into one account. Status is **APPLIED** / cloud-validated
(GHA OIDC apply run `29366105164`, role `project-a-lzlab-gha`). Offline
`terraform validate` for lab + modules is documented in
[`../../sandbox/landing-zone-lab/OFFLINE_VALIDATE.md`](../../sandbox/landing-zone-lab/OFFLINE_VALIDATE.md).
CI continues to validate via `.github/workflows/landing-zone-lab.yml`.
That does **not** rewrite the multi-account design; Orgs members remain
unavailable and **not** cloud-validated.

## Related

- [Platform architecture overview](overview.md)
- [S3 backend decision](../decisions/backend.md)
- [Secrets decision](../decisions/secrets.md)
- [Organizations guardrails](../guardrails/organizations.md)
- [Organization taxonomy checklist](../../terraform/organization/TAXONOMY.md)
