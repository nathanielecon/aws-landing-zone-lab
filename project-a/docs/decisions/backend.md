# Decision: remote Terraform state

Status: proposed for H0 human approval.

## Decision

Use a separately bootstrapped Amazon S3 bucket for remote state. Enable bucket
versioning, server-side encryption with a customer-managed KMS key, public
access blocking, and least-privilege bucket and key policies. Terraform uses
the S3 lockfile with `use_lockfile = true`; DynamoDB locking is excluded because
it is deprecated.

Backend infrastructure has a distinct lifecycle and owner from platform
stacks. The examples deliberately contain no credentials and are not activated
by the bootstrap module. Nonproduction state uses a `nonproduction/foundation.tfstate`
key and production state uses a `production/foundation.tfstate` key, in
separately controlled buckets or accounts. Never share a state key across
environments.

## Concurrency and access

Lockfile permissions include the state key's `.tflock` object. CI and operators
assume narrowly scoped roles; read, write, list, delete-lock, KMS decrypt, and
KMS encrypt permissions are granted only where required. Backend credentials
are supplied by the runtime identity, never by an HCL file.

## Recovery summary

Stop writers before recovery. Preserve the current object version and lock,
identify the last known-good S3 version, review the Terraform and audit trail,
then have two people approve restoration. Restore or copy the selected version,
reinitialize, and compare state to configuration with an approved offline or
future cloud workflow. Never overwrite state merely to clear drift. Record the
incident, object version, approvers, and rollback outcome. A stale lock may be
removed only after proving no writer remains.

S3 versioning supports rollback but is not a substitute for tested recovery.
See [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3).

**Out of scope for this runbook:** DynamoDB state locking tables, DynamoDB
lock acquisition/release, and any DynamoDB-based recovery path. This platform
uses S3 native lockfiles (`use_lockfile = true`) only.

## Dual-approval state-restore runbook (operator pressure-test)

Use this procedure when state drift, corruption, accidental overwrite, or a
failed apply leaves remote state untrustworthy. Treat every step as mandatory
unless an abort criterion fires. Two human approvers are required before any
restore write: one **platform** owner and one **security** owner. A single
operator must not both propose and sole-approve.

### 0. Preconditions

1. Confirm the affected environment (`nonproduction` or `production`) and the
   exact state key (`nonproduction/foundation.tfstate` or
   `production/foundation.tfstate`). Do not cross environments.
2. Confirm the state bucket, KMS key, and operator roles match the separately
   bootstrapped backend for that environment.
3. Open an incident ticket. Record UTC start time, reporter, suspected cause,
   and whether any apply is in flight.
4. Verify `use_lockfile = true` is the configured backend mode. Do **not**
   introduce or consult a DynamoDB lock table.

### 1. Detect drift or corruption

1. Inventory recent state-object versions in S3 (version IDs, LastModified,
   ETag, size) for the exact key. Note the current version and the prior N
   versions.
2. Compare the current object size and ETag against the last known-good
   version recorded in a prior successful plan/apply receipt or backup note.
3. If a `.tflock` object exists for the key, record its contents and age.
   Treat an unexpected lock as evidence of a concurrent writer until proven
   otherwise.
4. Capture Terraform CLI symptoms that motivated the restore (for example:
   checksum mismatch, state parse failure, resources missing from state that
   still exist in config, or serial/lineage anomalies). Prefer offline
   `terraform show` / plan against a **copied** state file when possible.
5. Classify the failure:
   - **Drift:** live resources diverge from state but state parses cleanly.
   - **Corruption / bad version:** state object is truncated, unreadable, or
     known-bad after a bad write.
   - **Wrong key / environment:** operator targeted the incorrect bucket or
     key (abort restore of the wrong object; correct the backend config).
6. If classification is unclear, freeze applies (step 2) and escalate to both
   approver roles before choosing a restore version.

### 2. Freeze applies and writers

1. Pause CI workflows and operator sessions that can `terraform apply` or
   write the state key for this environment.
2. Confirm no healthy writer holds the S3 lockfile. If a lock remains after
   freeze, do **not** delete it until both approvers agree no writer is active.
3. Snapshot (copy) the **current** state object version and the lockfile
   object (if present) to an incident-evidence prefix **before** any restore
   write. Preserve version IDs in the ticket.
4. Announce the freeze window in the incident channel with environment, key,
   and expected duration.

### 3. Select last known-good version

1. From S3 version history, identify candidate version IDs that predate the
   failure window.
2. Prefer the newest version that:
   - parses as Terraform state,
   - matches a recorded successful plan/apply receipt, and
   - does not embed secrets or foreign environment lineage.
3. Download the candidate to an offline review path (never paste state into
   tickets or chat). Review resource counts, serial, lineage, and backend
   metadata.
4. Record the chosen `VersionId`, ETag, size, and rationale in the ticket.

### 4. Dual approval (platform + security)

1. **Platform approver** confirms: correct environment/key, freeze in effect,
   candidate version ID, and that restore is preferable to forward-fix.
2. **Security approver** confirms: blast-radius review, no secret exposure in
   evidence handling, operator identities are authorized state administrators,
   and audit retention for the incident is adequate.
3. Both approvals must be named humans (not a shared bot identity), recorded
   with UTC timestamps on the ticket **before** any restore write.
4. If either approver withholds approval, abort (see abort criteria). Do not
   proceed on a single approval or on “temporary emergency” verbal-only assent.

### 5. Restore from the versioned S3 object

1. Using the approved identity, restore by copying the approved historical
   `VersionId` over the current key **or** by S3 restore-object semantics that
   make that version current — whichever the bucket policy already permits.
2. Confirm the post-restore current object’s VersionId/ETag/size match the
   approved candidate (or the new current version produced by the copy).
3. Do **not** rewrite state with `terraform state` push/rm hacks to “clear
   drift” as a substitute for version restore.
4. Do **not** create, update, or delete any DynamoDB lock resources.

### 6. Verify lockfile and `use_lockfile`

1. Confirm backend configuration still has `use_lockfile = true`.
2. Confirm the `.tflock` object is absent **or** was cleared only after both
   approvers documented that no writer remained.
3. Confirm IAM still grants lockfile object permissions on the state key’s
   `.tflock` companion; do not widen roles during the incident.
4. Re-assert explicitly: DynamoDB locking remains excluded.

### 7. Post-restore validation

1. From a clean working directory with the matching configuration commit:
   - `terraform init` (backend configured to the restored bucket/key;
     credentials from runtime identity only).
   - `terraform plan` (no apply). Capture the plan summary in the ticket.
2. Interpret the plan:
   - Empty or expected-only diffs: restore likely successful; proceed to
     controlled follow-up under normal change management.
   - Large destroy/recreate sets or unexpected replacements: **stop**. Treat
     as failed restore; do not apply; escalate (abort / rollback criteria).
3. Optionally run offline module validation for nearby stacks
   (`terraform init -backend=false`, `terraform validate`) when the incident
   also touched local configuration — this does not replace the backend plan
   against restored remote state.
4. Record plan exit status, Terraform version, configuration commit SHA, and
   whether any apply remains blocked.

### 8. Closeout

1. Lift the apply freeze only after platform and security agree the plan is
   understood and any follow-up apply has a normal change ticket.
2. File the incident closeout: version restored from/to, both approver names,
   validation evidence, and residual risk.
3. Schedule a short retrospective if corruption was caused by process failure
   (shared state keys, missing freeze, single-approver attempt).

### Rollback abort criteria

Abort the restore immediately (leave the pre-restore snapshot intact, keep
applies frozen, and escalate) when any of the following is true:

1. Platform and security dual approval is incomplete, revoked, or represented
   by the same person.
2. The candidate version ID cannot be proven to belong to this environment’s
   state key, or lineage/serial indicates cross-environment contamination.
3. Post-restore `terraform init` fails for backend/auth/key reasons that were
   not resolved without widening IAM or disabling encryption.
4. Post-restore `terraform plan` shows uncontrolled mass destroy/recreate or
   cannot parse state.
5. Evidence handling may have exposed state contents (secrets risk); security
   must rotate/revoke before any further state write.
6. A live writer reappears (new `.tflock` or concurrent CI apply) during the
   freeze window.
7. Anyone proposes DynamoDB locking or a DynamoDB “unlock” as part of recovery
   — reject that path and stay on S3 lockfile procedures only.
8. The wrong bucket or key was targeted — revert any mistaken write using the
   pre-restore snapshot procedure under a **new** dual approval, do not
   “fix forward” on the wrong key.

## Related

- [Platform architecture overview](../architecture/overview.md)
- [Accounts and OU taxonomy](../architecture/accounts.md)
- [Secrets decision](secrets.md)
- [Organizations guardrails](../guardrails/organizations.md)
- [Organization taxonomy checklist](../../terraform/organization/TAXONOMY.md)
