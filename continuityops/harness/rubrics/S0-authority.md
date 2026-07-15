# ContinuityOps S0 rubric — authority and proof harness

Status: `frozen-candidate` (Phase 0)

## Must-haves

1. Plan ID `continuityops-cloud-reliability-v1` is recorded with status
   `candidate-specification` until human H0 approval.
2. `integration/upstreams.lock.json` pins Project A commit and records Project C
   availability honestly.
3. Partition manifest assigns every ContinuityOps path to exactly one primary
   slice owner.
4. Task policies declare `allowed_paths`, `adapter_owned_paths`, and allowlisted
   validators only.
5. Unauthorized Phase 1 execution is rejected while `execution_approved` is
   false.
6. No ContinuityOps task modifies `project-a/`.
7. No cloud credentials or live cloud mutation occur in Phase 0.
8. Worker Mandarin / recruiter English language boundary is documented.
9. Append-only `ISSUES.md`, `STATUS.md`, `DECISIONS.md`, and `BREAK_FIX_LOG.md`
   exist.
10. Evidence events bind candidate SHA, environment, command, timestamp,
    exit code, result, and artifact hash.

## Scoring guidance

Judges score the candidate SHA and evidence manifest, not an uncommitted
worktree. Fresh-council verdicts are authoritative after any saved-cohort
provisional pass.
