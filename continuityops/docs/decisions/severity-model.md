# Incident severity model

ContinuityOps severity definitions, ownership, and escalation templates for lab
and staging operations. Adjust thresholds per environment SLO catalog.

## Severity levels

| Level | Name | Customer impact | Response target | Update cadence |
| --- | --- | --- | --- | --- |
| SEV-1 | Critical | Platform unavailable or active data loss | 15 minutes | Every 30 minutes |
| SEV-2 | Major | Core workflow degraded; no workaround | 30 minutes | Every 60 minutes |
| SEV-3 | Minor | Limited feature impact; workaround exists | 4 hours | Daily |
| SEV-4 | Low | Cosmetic, internal-only, or drill finding | Next business day | As needed |

Severity is assigned at incident open and may be adjusted after triage. When in
doubt between two levels, choose the higher severity until evidence lowers it.

## Ownership

| Role | Responsibility |
| --- | --- |
| Incident commander (IC) | Coordinates response, comms, and resolution timeline |
| Technical lead | Drives mitigation, rollback, and fix-forward |
| Communications lead | Stakeholder updates (internal + customer-facing) |
| Scribe | Timeline, decisions, and evidence links |

Default IC rotation: ContinuityOps primary on-call. Technical lead defaults to
the service owner for the failing slice (S3 worker → serverless owner).

## Escalation triggers

Escalate when any condition holds:

- SEV-1 open longer than 30 minutes without mitigation path
- DLQ depth growing after replay attempt (`continuityops-events-dlq`)
- Cross-tenant blast radius suspected (shared queue or identity bug)
- Regulatory or export deadline at risk during `tenant.export` or deprovision

Escalation path: primary on-call → secondary on-call → engineering manager →
program sponsor (lab drills only for the last step).

## Escalation templates

### Internal — initial notification

```text
Subject: [SEV-{level}] {short title}

Status: Investigating | Identified | Mitigating | Resolved
Severity: SEV-{level}
Incident commander: {name}
Technical lead: {name}
Customer impact: {one sentence}
Start time (UTC): {iso8601}
Correlation / ticket: {id}

Current actions:
- {bullet}

Next update: {time UTC}
```

### Stakeholder — customer-facing (SEV-1/2)

```text
Subject: Service disruption — {product area}

We are investigating reports of {impact summary}. Some customers may experience
{symptom}. Our team is engaged and we will provide an update by {time UTC}.

Reference: {public incident id}
```

### Escalation — management

```text
Subject: ESCALATION SEV-{level} — {short title}

Reason: {trigger}
Duration: {minutes} since start
Mitigation status: {blocked | in progress | none}
Resources needed: {additional engineers | vendor | decision}
Blast radius: {tenants | regions | single tenant}
Evidence: {links to dashboards, correlation_ids, DLQ sample ids}
```

### Resolution

```text
Subject: [RESOLVED] SEV-{level} {short title}

Resolved at (UTC): {iso8601}
Duration: {duration}
Root cause (preliminary): {summary}
Customer impact: {summary}
Follow-ups: {ticket ids for post-incident review and preventive work}
```

## Mapping worker signals to severity

| Signal | Typical severity |
| --- | --- |
| Primary queue age p99 > SLO for 15m | SEV-2 |
| DLQ depth > 0 sustained 5m | SEV-3 (SEV-2 if tenant export backlog) |
| Poison message rate spike | SEV-3 until tenant scope confirmed |
| Worker `Errors` > 5% for 10m | SEV-2 |
| Complete region queue unavailable | SEV-1 |

Link dashboards and `correlation_id` samples in the incident record; never paste
raw message bodies containing tenant PII into public tickets.
