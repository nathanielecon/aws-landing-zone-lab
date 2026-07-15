# Change record — TEMPLATE

Copy to `changes/CHG-YYYYMMDD-NNN-short-title.md`. Required for production and
recommended for staging lab changes that affect shared environments.

## Metadata

| Field | Value |
| --- | --- |
| Change ID | CHG-YYYYMMDD-NNN |
| Type | Standard / Normal / Emergency |
| Status | Proposed / Approved / In progress / Completed / Rolled back |
| Requester | |
| Implementer | |
| Approver | |
| Scheduled window (UTC) | |
| Environments | lab / staging / recovery-lab |
| Rollback owner | |

## Summary

What changes, why now, expected outcome.

## Risk assessment

| Factor | Rating | Notes |
| --- | --- | --- |
| Blast radius | low / medium / high | |
| Reversibility | | |
| Customer impact if failed | | |
| Dependencies | | |

## Implementation plan

Numbered steps with verification after each step.

1.
2.

## Rollback plan

Exact commands or Helm revision to restore prior state. Tested: yes / no.

## Pre-change verification

- [ ] Backup or snapshot where applicable
- [ ] Smoke baseline recorded (`runbooks/app-smoke.md`)
- [ ] On-call aware
- [ ] Monitoring dashboards open

## Post-change verification

- [ ] Smoke tests pass
- [ ] SLO dashboards green for 30 minutes
- [ ] No new DLQ depth or error-rate spike

## Emergency change justification

(Required only for Type = Emergency.)

Why normal change window was bypassed and who approved.

## Related incidents / postmortems

INC-… / PM-… / none

## Completion

| Field | Value |
| --- | --- |
| Completed at (UTC) | |
| Outcome | success / partial / rolled back |
| Evidence links | |
