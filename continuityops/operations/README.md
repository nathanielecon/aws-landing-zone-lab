# ContinuityOps operations (S5)

Incident response, drills, runbooks, and change records for the ContinuityOps
lab and staging environments. All paths are synthetic — no live credentials,
ARNs, or tenant data belong in this tree.

## Layout

| Path | Purpose |
| --- | --- |
| `drills/` | Tabletop and lab walkthroughs with hypothesis → recovery narratives |
| `runbooks/` | Pressure-usable diagnosis guides (read before mutating) |
| `incidents/` | Active incident record templates and archived tickets |
| `postmortems/` | Blameless review templates after SEV-1/2 or drill findings |
| `changes/` | Standard and emergency change records |

## Severity and ownership

Use `continuityops/docs/decisions/severity-model.md` for SEV levels, IC
rotation, and escalation templates. Default technical lead follows the failing
slice owner (S2 Kubernetes, S3 serverless, S4 observability).

## Drills

Eight incident drills cover misleading symptoms, startup/config faults, DNS,
ingress, network policy, serverless poison/DLQ, bad release rollback, and
observability blind spots. Each drill includes:

- Hypothesis and first-five-minute checks
- Commands (lab namespace `continuityops-lab` unless noted)
- Timeline, ruled-out causes, root cause, recovery choice
- Verification, user-impact draft, and follow-up actions

Run drills in a non-production namespace. Pair with `kubernetes/scenarios/`
inject scripts where referenced.

## Runbooks

Every runbook includes **stop/escalation** criteria and **do not do this yet**
cautions before any mutating step. Read the relevant runbook before executing
commands from a drill or incident record.

| Runbook | When to use |
| --- | --- |
| `runbooks/kubectl-first-five.md` | Any Kubernetes incident — cluster triage |
| `runbooks/process-logs-in-container.md` | CrashLoop, OOM, or silent process failure |
| `runbooks/dns-tls-checks.md` | Resolver, service discovery, or TLS handshake errors |
| `runbooks/lb-target-health.md` | Ingress/LB 502/503, uneven traffic, target drain |
| `runbooks/security-boundary-checks.md` | NetworkPolicy, egress deny, or auth boundary suspicion |
| `runbooks/app-smoke.md` | End-to-end HTTP smoke after mitigation |

## Templates

Copy and rename (do not edit in place):

- `incidents/TEMPLATE.md` — open and update during active incidents
- `postmortems/TEMPLATE.md` — within five business days of resolution
- `changes/TEMPLATE.md` — standard or emergency production/lab changes

## Related ContinuityOps paths

- Kubernetes scenarios: `continuityops/kubernetes/scenarios/`
- Serverless DLQ/replay: `continuityops/serverless/infra/sqs-dlq.md`
- Smoke contract: `continuityops/app-contract/openapi-smoke.yaml`
- SLO catalog: `continuityops/observability/slo-catalog.json`

## Evidence

Attach drill and incident evidence (dashboard links, `correlation_id` samples,
redacted logs) to the ContinuityOps evidence stream per `continuityops/evidence/`.
Never paste raw tenant payloads or secrets into tickets.
