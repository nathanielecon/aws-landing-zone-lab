# Claims boundary

## What this project proves

This repository proves a repo-only, inspectable infrastructure design exercise
with Terraform modules, deterministic validation gates, and explicit evidence.
Harness task evidence for A-001…A-007 remains repo-only gated work and is not
cloud validated.

Separately, a **single-account Landing Zone lab** under
`project-a/sandbox/landing-zone-lab` is **READY TO APPLY** / `PENDING_APPLY`
for a collapsed composition of **identity + private network + audit** in AWS
account `283077380808` / `us-east-1`. Designed interfaces and Terraform roots
exist; the intended control plane is **GitHub OIDC → Terraform CI**
(`.github/workflows/landing-zone-lab.yml`, role `GitHubActionsLZLab`), not
Cursor Cloud Agent assume-role. Live apply is **not** complete until CI/local
bootstrap finishes and evidence updates — see
`project-a/sandbox/landing-zone-lab/EVIDENCE.md`.

The multi-account Organizations / OU / SCP layout remains a **documented and
offline-validated Terraform interface**; member accounts are **not** created
under the single-account constraint. See
`project-a/sandbox/landing-zone-lab/ORGS_INTERFACE.md`.

The earlier audit-only sandbox (`project-a/sandbox/aws-proof`) remains evidence
of the first live audit-module apply.

## Honest resume bullet (target / after-exit wording)

Not current proof — use only after a successful live lab apply and evidence
update. Target wording:

> Designed a multi-account AWS Landing Zone (Orgs/OU/SCP interfaces) and
> cloud-validated a single-account lab composition of identity, private
> network, and audit (CloudTrail/KMS Log Archive) in `us-east-1` with
> Terraform, evidence, and CI-gated delivery.

## What this project does not prove

It does not prove production deployment, enterprise operations, senior-level
platform ownership, or that a **multi-account** Landing Zone was fully
cloud-validated across Organizations + network + identity. It also does **not**
yet prove a completed single-account cloud validation of identity + network +
audit while lab status remains `PENDING_APPLY`. Azure Government remains
translation-only.

## Intended level

The supported framing is junior-to-mid infrastructure engineering work:
thoughtful module design, guardrails, validation, documentation, accurate
handoff language, and an honest single-account lab that is ready to apply for
identity/network/audit — superior to audit-only sandbox proof once applied,
inferior to real multi-account cloud validation.

## Avoid unsupported claims

Avoid claims that the work is production ready, senior-level, enterprise-scale,
or a fully cloud-validated multi-account Landing Zone. Do **not** claim the
single-account lab identity+network+audit composition is cloud-validated while
`EVIDENCE.md` remains `PENDING_APPLY`. Keep Azure Government wording
translation-only. Keep harness delivery framing repo-only unless citing the lab
evidence files for the specific live resources shown there.
