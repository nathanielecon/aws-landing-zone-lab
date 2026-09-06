# Project A retirement controls

Status: staged for reviewer-gated execution. A later evidence commit records
the outcome; this document does not claim retirement completed.

The public workflow exposes only operation categories and sanitized outcomes.
Raw inventory, policy simulation, Terraform state, plans, and Cost Explorer
responses are short-retention private artifacts.

## Protected stages

All stages are manual, main-only, serialized, and exact-input gated.

1. `inventory` reads every enabled region and privately backs up live state.
2. `bootstrap` derives an exact-resource retirement policy from live inventory,
   validates every action against AWS's machine-readable Service Authorization
   Reference, simulates the policy, creates the short-lived environment-only
   role, narrows the legacy role trust, and captures a deterministic 30-day
   Cost Explorer baseline.
3. `state-transfer` imports archive/state S3 and KMS resources into the retained
   root. It requires a zero-change retained plan before removing their old
   state ownership, then requires a delete-only lab plan that contains no S3 or
   KMS resource.
4. `teardown` repeats both gates and removes trails (including superseded
   project trails), Config recorder/channel and writer role, flow logs, private
   networking, and workload IAM.
5. `verify` checks every enabled region and proves both retained buckets, both
   KMS aliases/keys, both Terraform state objects, and the existing 90-day
   archive lifecycle remain readable.
6. `cleanup` removes the operator, legacy CI role, and short-lived teardown
   role. The account-wide GitHub OIDC provider is intentionally preserved.

The protected job name displays the affected categories before approval. The
`lab` and `lab-teardown` environments require the repository owner as reviewer.

## Retained spend

Retirement intentionally does not mean a zero-dollar AWS account. Expected
Project A residuals are S3 object/version storage and requests plus two
customer-managed KMS keys and their requests. The archive keeps its existing
90-day current/noncurrent lifecycle. Cost Explorer comparison is meaningful
only after AWS's reporting delay; unrelated account spend is outside this lab's
baseline.

## Recovery

Execution requires a verified encrypted local repository mirror and encrypted
Terraform-state/inventory backup. No destructive stage runs before those
backups, the zero-change retained plan, and the exact removal-plan audit exist.
