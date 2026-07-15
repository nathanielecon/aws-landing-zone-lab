# Bottleneck repair — CPU throttling before and after

One documented performance remediation for the ContinuityOps lab Helm workload.
All figures are **synthetic** and labeled for portfolio evidence; replace with
measured values after a live drill.

## Context

During a post-restore load run (`load-scenario.md` steady phase, 50 VUs), the
lab deployment exhibited elevated p95 latency and HPA unable to stabilize
replica count. Investigation targeted the `continuityops-lab` Deployment in
namespace `continuityops-lab`.

## Symptom (before)

| Signal | Synthetic observed value | Threshold |
| --- | --- | --- |
| Steady-phase p95 latency | 890 ms | ≤ 500 ms SLO |
| Error rate | 2.4% | < 1% |
| Pod CPU throttling | 38% of intervals | < 5% expected |
| HPA desired replicas | Oscillating 2 ↔ 4 | Stable at 2–3 |
| `kubectl top pods` CPU | 249m / 250m limit | At limit |

**Root cause:** CPU limit (`250m`) matched sustained request rate for
`/api/smoke` while readiness probes and sidecar overhead consumed headroom.
Throttling increased queue depth inside the process, inflating p95 latency.

## Change (repair)

| Field | Before | After |
| --- | --- | --- |
| `resources.requests.cpu` | 50m | 100m |
| `resources.limits.cpu` | 250m | 500m |
| `resources.requests.memory` | 64Mi | 128Mi |
| `resources.limits.memory` | 256Mi | 256Mi |
| HPA `targetCPUUtilizationPercentage` | 80 | 70 |

Applied via Helm values update in `kubernetes/chart/values.yaml` (lab tier).
Change recorded as performance remediation linked to `CH-backup-restore` drill
follow-up — no secrets or account-specific ARNs in ticket.

## Result (after)

| Signal | Synthetic after value | Delta |
| --- | --- | --- |
| Steady-phase p95 latency | 318 ms | −64% |
| Error rate | 0.1% | −96% |
| Pod CPU throttling | 2% of intervals | −95% |
| HPA desired replicas | Stable at 2 | Oscillation resolved |
| Steady-phase cost estimate | +$4.20/month lab (see finops.md) | Acceptable for SLO gain |

Synthetic structured results: `baseline-results.json` (post-repair profile).

## Verification

1. Re-ran load scenario steady + spike phases
2. Compared JSON output against `results.schema.json`
3. Confirmed SLO flags `slo_p95_met` and `slo_availability_met` true
4. Linked run id in `evidence/slices/S7-resilience.md`

## Lessons

- Set CPU requests to reflect probe + baseline traffic overhead, not ideal idle
- Watch throttling metrics before scaling replica count
- Right-size before adding nodes — aligns with `docs/decisions/finops.md`

## Related documents

- `tests/performance/load-scenario.md`
- `tests/performance/baseline-results.json`
- `docs/decisions/finops.md`
