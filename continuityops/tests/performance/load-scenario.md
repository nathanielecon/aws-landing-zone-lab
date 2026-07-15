# Load scenario — ContinuityOps lab HTTP surface

Synthetic load profile for recovery-lab and staging spot checks. Numbers in
`baseline-results.json` are **synthetic** and labeled as such; replace with
measured results after an approved drill.

## Objective

Validate that the lab HTTP workload (`continuityops-lab` Helm release) meets
latency and error targets under moderate concurrent load after backup/restore
or performance tuning changes.

## Target SLOs

From `observability/slo-catalog.json`:

| SLI | Lab objective |
| --- | --- |
| Availability | 99% successful requests |
| Latency p95 | ≤ 500 ms |

## Endpoints under test

| Method | Path | Weight | Notes |
| --- | --- | --- | --- |
| GET | `/healthz` | 10% | Liveness; cheap |
| GET | `/readyz` | 10% | Readiness |
| GET | `/api/smoke` | 80% | Primary smoke contract path |

Base URL: in-cluster `http://continuityops-lab:8080` or port-forward to localhost.

## Traffic profile

| Phase | Duration | Virtual users | Ramp | Description |
| --- | --- | --- | --- | --- |
| Warm-up | 2 min | 5 → 20 | linear | Stabilize JVM/Node cold start |
| Steady | 10 min | 50 | — | Nominal lab load |
| Spike | 3 min | 50 → 150 | step | Simulate post-recovery catch-up |
| Cool-down | 2 min | 150 → 0 | linear | Observe recovery |

Total duration: **17 minutes**.

## Success criteria

- Error rate < 1% during steady and spike phases
- p95 latency ≤ 500 ms during steady phase
- p99 latency ≤ 1000 ms during spike phase
- No pod restarts attributable to OOM or crash loop during run

## Tooling (lab)

Any HTTP load generator is acceptable. Example with `k6` (not pinned in repo):

```javascript
// Synthetic sketch — run outside repo in drill environment
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 20 },
    { duration: '10m', target: 50 },
    { duration: '3m', target: 150 },
    { duration: '2m', target: 0 },
  ],
};

const BASE = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
  const r = Math.random();
  const path = r < 0.1 ? '/healthz' : r < 0.2 ? '/readyz' : '/api/smoke';
  const res = http.get(`${BASE}${path}`);
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(0.1);
}
```

## Output

Emit results JSON conforming to `results.schema.json`. Compare against
`baseline-results.json` and document regressions in the change record.

## When to run

- After `CH-backup-restore` verification checklist item 8
- After resource right-sizing per `docs/decisions/finops.md`
- After bottleneck remediation documented in `bottleneck-before-after.md`
