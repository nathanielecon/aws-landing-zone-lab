# Claims boundary

## What this project proves

This repository proves a repo-only, inspectable infrastructure design exercise
with Terraform modules, deterministic validation gates, and explicit evidence.
Harness task evidence for A-001…A-007 remains repo-only gated work and is not
cloud validated.

Separately, an **operator sandbox** under `project-a/sandbox/aws-proof` applied
the audit module live in AWS account `<AWS_ACCOUNT_ID>` / `us-east-1` (CloudTrail +
KMS-encrypted Log Archive bucket). See `project-a/sandbox/aws-proof/EVIDENCE.md`.
That sandbox proves **audit-module apply efficacy** only; it does not expand the
harness evidence claims or prove multi-account Organizations/network/identity
deployment.

## What this project does not prove

It does not prove production deployment, enterprise operations, senior-level
platform ownership, or that the full platform design was cloud validated across
accounts. Azure Government remains translation-only.

## Intended level

The supported framing is junior-to-mid infrastructure engineering work:
thoughtful module design, guardrails, validation, documentation, and accurate
handoff language — optionally supplemented by a narrow live sandbox proof of the
audit module.

## Avoid unsupported claims

Avoid claims that the work is production ready, senior-level, enterprise-scale,
or fully cloud validated. Keep Azure Government wording translation-only, not
implemented, and evidence-based. Keep harness delivery framing repo-only unless
citing the sandbox evidence file for the audit-module apply only.
