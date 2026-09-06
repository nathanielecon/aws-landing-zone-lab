# Project A retirement evidence

Date: 2026-09-06

This page contains only sanitized outcomes and hashes. Raw AWS inventory,
Terraform state, plans, IAM simulation responses, and Cost Explorer responses
remain in short-retention private Actions artifacts and an encrypted local
backup.

## Verified sequence

| Gate | Outcome |
| --- | --- |
| Encrypted mirror and state backup | Verified before destructive work |
| Exact-resource IAM bootstrap | 16 statements / 97 actions after partial-destroy resumption; no implicit-deny gaps |
| Retained state | Zero-change plan before teardown |
| Final lab plan | Delete-only; no S3 or KMS resources |
| Destruction | CloudTrail, Config/writer, workload IAM, flow log, and VPC networking removed |
| Regional verification | 17 enabled regions checked; 0 matching residual resources |
| Retained evidence | Archive and state readable; both KMS keys enabled; archive lifecycle 90 days |
| IAM cleanup | Project operator, legacy CI role, short-lived teardown role, and project policies removed |
| Shared identity provider | Account-wide GitHub OIDC provider preserved |

## Workflow receipts

- [State transfer and constrained plan](https://github.com/nathanielecon/aws-landing-zone-lab/actions/runs/34061866622)
- [Successful constrained teardown](https://github.com/nathanielecon/aws-landing-zone-lab/actions/runs/34062600233)
- [All-region and retained-evidence verification](https://github.com/nathanielecon/aws-landing-zone-lab/actions/runs/34062702613)
- [Temporary IAM cleanup](https://github.com/nathanielecon/aws-landing-zone-lab/actions/runs/34062896913)

The first teardown attempt stopped safely on missing exact-resource
permissions. [PR #48](https://github.com/nathanielecon/aws-landing-zone-lab/pull/48)
added only the state-owned flow-log resource and the exact route-table/subnet
resource types required by AWS, passed credential-free validation, and was
re-simulated before the successful retry.

## Private summary hashes

SHA-256 values let the private evidence be matched to this public record
without exposing cloud identifiers.

| Private summary | SHA-256 |
| --- | --- |
| Retained zero-change summary | `1421AD582F05A07D5B30F35ECAD54419834327A136CDB9F55B6BAD7B3EDA3D29` |
| Reviewed delete-only plan summary | `DD2BD08F39FA5883A6895E6799880153EBA4A9C56FC1E56F134A7750DD824F2E` |
| Final verification summary | `0B1D6E3CE5B063D7384D76C07305581F0A106412DF0DAED4CB6E444A9439E2D8` |

## Cost baseline

The private deterministic baseline sums unrounded daily AWS Cost Explorer
`UnblendedCost` service groups for 2026-08-07 through 2026-09-07 (end
exclusive). It is an account baseline, not a claim that all spend belonged to
Project A. The post-retirement comparison is intentionally pending Cost
Explorer's reporting delay; expected Project A residuals are limited to the
documented S3 and KMS retention posture.
