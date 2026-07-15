# Incident record — TEMPLATE

Copy to `incidents/INC-YYYYMMDD-NNN-short-title.md`. Do not commit live tenant
data or credentials.

## Metadata

| Field | Value |
| --- | --- |
| Incident ID | INC-YYYYMMDD-NNN |
| Severity | SEV-1 / SEV-2 / SEV-3 / SEV-4 |
| Status | Investigating / Identified / Mitigating / Resolved |
| Incident commander | |
| Technical lead | |
| Communications lead | |
| Scribe | |
| Start time (UTC) | |
| Detected via | Alert / customer report / drill |
| Affected environments | lab / staging |
| Related change | CHG-… or none |

## Summary

One paragraph: what is broken, who is affected, current mitigation status.

## Customer impact

- **Symptom:**
- **Scope:** tenants / regions / internal-only
- **Workaround:**

## Timeline (UTC)

| Time | Event | Actor |
| --- | --- | --- |
| | Detection / alert fired | |
| | IC assigned | |
| | | |

## Hypothesis log

| Time | Hypothesis | Evidence for / against | Status |
| --- | --- | --- | --- |
| | | | open / ruled out / confirmed |

## Technical notes

Links to dashboards, `correlation_id` samples, pod names, queue depths. Redact
PII.

## Mitigation and recovery

What was done, rollback vs fix-forward, who approved emergency changes.

## Verification

How recovery was confirmed (smoke tests, SLO green, DLQ drained).

## Communications

- Internal update times:
- Customer-facing status page / email: yes / no

## Follow-up tickets

| Ticket | Owner | Due |
| --- | --- | --- |
| Postmortem | | |
| Preventive fix | | |

## Resolution

| Field | Value |
| --- | --- |
| Resolved at (UTC) | |
| Duration | |
| Preliminary root cause | |
| Final severity | |
