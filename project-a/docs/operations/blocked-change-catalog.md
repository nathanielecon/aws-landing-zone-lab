# Blocked-change catalog (offline replay)

Reviewers can replay this catalog from documentation alone. Every row is a
**blocked change**: it must fail offline review and must not proceed to any
separately controlled deployment without a new human approval packet. This
repository does not perform live AWS apply, Identity Center lifecycle, audit
deploy, or SCP attach.

Related: [organizations guardrails](../guardrails/organizations.md),
[accounts](../architecture/accounts.md), [network architecture](../architecture/network.md),
[logging architecture](../architecture/logging.md), [backend decision](../decisions/backend.md),
[secrets decision](../decisions/secrets.md).

## How to replay

1. Locate the change class in the table below.
2. Confirm the owning boundary (Network / Security Tooling / Log Archive /
   Management / identity).
3. Confirm the offline signal (doc text, variable validation, module absence, or
   negative test).
4. Stop and escalate if a proposed fix would implement the blocked change from
   this repository.

## Catalog

| ID | Blocked change | Owning boundary | Offline signal | Why blocked |
| --- | --- | --- | --- | --- |
| BC-NET-01 | Add Transit Gateway (TGW) attachment or routes | Network | Declared extension point only in `network.md` / `network-failure-cases.md`; no `aws_ec2_transit_gateway*` in module | Cross-account/shared routing is out of baseline |
| BC-NET-02 | Add Network Firewall (NFW) endpoints or policies | Network | Extension point; no NFW resources in module | Changes inspection/egress model without design approval |
| BC-NET-03 | Add NAT gateway / IGW / `0.0.0.0/0` default route | Network | Private route table has no default route; failure cases escalate NAT/IGW | Breaks private-only posture |
| BC-NET-04 | Add VPN or Direct Connect (DX) | Network | Extension point; not implemented | Introduces hybrid connectivity without H1-class review |
| BC-NET-05 | Create live RAM shares for subnets/TGW | Network | Extension point; no RAM resources | Shares network ownership across accounts without approval |
| BC-NET-06 | Open public security-group ingress (for example `0.0.0.0/0`) | Network | Default-deny SG (`ingress = []`); fail-closed `allow_unrestricted_ingress` (default deny; extension-blocked); `network_negative_tests` `expect_failures` + `enforces_default_deny_security_group` | Collapses private workload exposure controls |
| BC-NET-07 | Point flow logs at a non–Log Archive S3 ARN shape | Network | `flow_logs_destination_arn` must match `^arn:aws:s3:::`; negative test rejects other shapes | Diverting flow metadata breaks archive ownership |
| BC-NET-08 | Open unrestricted security-group egress (for example `0.0.0.0/0`) | Network | Default-deny SG (`egress = []`); fail-closed `allow_unrestricted_egress` (default deny; extension-blocked); `rejects_unrestricted_egress_exception` | Collapses private-only egress posture without approved egress design |
| BC-NET-09 | Place subnet CIDR outside VPC or overlapping another subnet | Network | `check.private_subnets_inside_vpc`; non-overlap validation on `private_subnets`; matching `expect_failures` | Breaks address-plan integrity before any deploy |
| BC-ID-01 | Live IAM Identity Center user/group/permission-set lifecycle | Identity / Management | Identity module is OIDC/workload-role interface only; no Identity Center resources | Lifecycle in cloud is outside repo-only baseline |
| BC-AUD-01 | Live audit deploy (apply trail, recorder, or archive from this repo) | Security Tooling → Log Archive | Module README + logging.md: interfaces only; forbidden `terraform apply` | Live log-service calls are unauthorized here |
| BC-AUD-02 | Public ACL / public bucket policy on archive, or missing KMS SSE | Log Archive (protected storage) | Fail-closed `allow_public_archive_acls` / `require_customer_managed_kms`; `aws_s3_bucket_public_access_block` all true; SSE `aws:kms` via `aws_kms_key.audit`; audit `expect_failures` negatives | Weakens integrity and confidentiality of audit objects |
| BC-ORG-01 | Attach SCP to organization root or to an individual account | Management / Organizations | `scp_attachments` accepts only Security, Infrastructure, or Workloads OUs; H1 blocked-change sample | Root/account attach is outside baseline attachment map |
| BC-ORG-02 | Enable `close_on_deletion` on account resources | Organizations | Documented false; H1 must keep closure semantics off | Prevents Terraform-requested account closure |
| BC-STATE-01 | Share a remote state key across nonproduction and production | Backend / bootstrap | Distinct keys (`nonproduction/...` vs `production/...`); never share keys | Cross-environment state contamination |
| BC-SEC-01 | Commit credential-shaped examples (real keys, tokens, `AKIA…` samples, usable secrets in tfvars) | Secrets / all modules | Secrets decision: placeholders only; secret_scan / credential_boundary gates | Credential leakage and unsafe copy-paste |

## Credential-shaped examples (explicitly blocked)

The following patterns are **examples of what must not appear** in committed
artifacts. They are illustrative shapes only—not usable credentials:

- Access-key shaped strings such as `AKIA` + 16 alphanumeric characters in
  docs, tfvars, or examples
- Secret-access-key or session-token blocks pasted into HCL or Markdown
- Private key PEM blocks (`BEGIN PRIVATE KEY`) in the repository
- Live OIDC client secrets or webhook signing secrets in environment files

Use obvious placeholders (`REPLACE_ME`, `example-org`, `arn:aws:s3:::example-log-archive`)
instead. Runtime credentials come from the execution identity, never from
committed files.

## Stop conditions

Stop and escalate when a proposed repair would implement any catalog row, widen
Codex/`workspace-write` beyond the task policy, or claim live teardown/billing
proof from this offline catalog.
