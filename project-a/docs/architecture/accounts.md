# Accounts and organizational units

This repository defines a **multi-account design interface** (Organizations /
OU / SCP) and a **single-account live lab**.

| Mode | Status |
| --- | --- |
| Organization module (OU + member interface + SCP) | Offline-validated design interface — **member accounts not created** |
| Live lab account `<AWS_ACCOUNT_ID>` / `us-east-1` | Cloud-validated collapsed identity + network + audit composition |

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

The Terraform organization module has explicit `aws_organizations_account`
resources as a reviewed account-creation **interface**, not authorization to
create accounts in this lab. Account emails and the initial cross-account role
name are typed inputs. Member accounts are not created because this lab has a
single billed account and no H1-approved unique member emails. Details:
[`../../sandbox/landing-zone-lab/ORGS_INTERFACE.md`](../../sandbox/landing-zone-lab/ORGS_INTERFACE.md).

## Live single-account lab

In account `<AWS_ACCOUNT_ID>`, the Landing Zone lab collapses identity, private
network, and audit into one account for cloud validation. That does **not**
rewrite the multi-account design; it is an honest lab composition while Orgs
members remain unavailable.

See the [Organizations guardrail boundary](../guardrails/organizations.md) and
the [platform architecture contract](overview.md).
