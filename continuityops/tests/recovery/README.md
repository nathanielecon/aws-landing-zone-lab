# Recovery verification tests (S7)

JSON artifacts for recovery-lab backup/restore drills. All payloads use
**synthetic data only** and must not contain secrets, access keys, or real
tenant identifiers.

## Schema

`restore-verification.schema.json` defines the evidence record produced after
executing `operations/changes/CH-backup-restore.md`.

## Usage

1. Run the restore procedure for the chosen scenario (`helm_rollback`,
   `queue_redrive`, or `full_rebuild`).
2. Complete the verification checklist in the change record.
3. Emit a JSON document conforming to the schema.
4. Validate locally:

```bash
# Requires ajv-cli or equivalent JSON Schema validator
ajv validate -s continuityops/tests/recovery/restore-verification.schema.json \
  -d path/to/your-restore-verification.json
```

4. Link the artifact from `evidence/slices/S7-resilience.md` with candidate SHA.

## Example (synthetic, illustrative)

```json
{
  "schema_version": "continuityops-restore-verification-v1",
  "verification_id": "rv-2026-07-15-synthetic-example",
  "candidate_sha": "0000000000000000000000000000000000000000",
  "environment": "repo_only",
  "change_id": "CH-backup-restore",
  "scenario": "helm_rollback",
  "started_at_utc": "2026-07-15T14:00:00Z",
  "completed_at_utc": "2026-07-15T14:18:00Z",
  "result": "pass",
  "synthetic_data_label": true,
  "rto_rpo": {
    "rto_minutes_measured": 18,
    "rto_minutes_target": 30,
    "rpo_minutes_measured": 0,
    "rpo_minutes_target": 0,
    "rto_met": true,
    "rpo_met": true
  },
  "components": [
    {
      "name": "eks_workloads",
      "check": "helm rollback + rollout status",
      "status": "pass"
    },
    {
      "name": "lambda_worker",
      "check": "Errors metric below threshold",
      "status": "pass"
    }
  ],
  "evidence_links": [
    "continuityops/operations/changes/CH-backup-restore.md"
  ],
  "notes": "Synthetic example for schema documentation — not a live drill result."
}
```

Replace placeholder SHA and timestamps with live values only when executing an
approved recovery-lab drill.

## Related documents

- `docs/decisions/rto-rpo.md` — per-component RTO/RPO targets
- `operations/changes/CH-backup-restore.md` — procedure and checklist
- `operations/changes/CH-teardown.md` — teardown evidence (`scenario: teardown_complete`)
