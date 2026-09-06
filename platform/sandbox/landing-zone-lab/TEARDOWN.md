# Project A retirement controls

Status: **completed and verified on 2026-09-06**.

The retired workflow used manual, main-only, exact-input stages and protected
environments with owner review. It captured private inventory, generated an
exact-resource IAM policy from live inventory and Terraform state, checked its
actions against AWS Service Authorization Reference data, and simulated every
statement before use.

Before destruction, the archive/state S3 and KMS resources were imported into
the retained-evidence root and produced a zero-change plan. The remaining lab
plan contained only deletes and no S3 or KMS resources. Verification then
checked every enabled region and confirmed the retained buckets, KMS aliases,
state objects, and 90-day archive lifecycle remained readable.

The short-lived role, legacy CI role, operator, and project-specific IAM
policies were removed last. The repository variables and protected-environment
secrets that named those roles were also deleted. Historical workflow runs are
retained; the executable retirement workflow was removed from the current tree.

## Intentional residual spend

Retirement does not mean a zero-dollar AWS account. Project A intentionally
retains S3 object/version storage and requests plus two customer-managed KMS
keys and their requests. The archive keeps its existing 90-day current and
noncurrent-version lifecycle. Cost Explorer comparison remains subject to AWS
reporting delay, and unrelated account spend is outside this lab's scope.

See [`RETIREMENT_EVIDENCE.md`](RETIREMENT_EVIDENCE.md) for sanitized results.
