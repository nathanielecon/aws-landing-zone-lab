# AWS sandbox proof (operator override)

This directory is a **separate operator apply path** used to prove live AWS
efficacy. It is **not** part of the repo-only Project A harness contract.

- Region: `us-east-1` (lowest-cost default commercial region for this proof)
- Account: supplied by the operator AWS identity at apply time
- Module: reuses `platform/terraform/audit` (Log Archive S3, KMS, CloudTrail, Config)

Do not treat a successful apply here as rewriting the portfolio claims boundary
unless evidence and docs are updated accordingly. Teardown remains an approved
operator action; prefer capturing evidence before destroy.
