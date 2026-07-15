# Resource pressure drill

Simulate CPU/memory pressure via low limits and bursty workload. Verifies
HPA/restarts, OOM behavior, and restore to chart defaults.

## Prerequisites

- Metrics server or equivalent for HPA (optional)
- Chart installed with default `resources` limits

## Inject

```bash
./resource-pressure-inject.sh
```

Lowers memory limit and adds a stress side-effect via env (lab stub).

## Verify failure

```bash
kubectl -n continuityops-lab top pods 2>/dev/null || true
kubectl -n continuityops-lab get pods -w
kubectl -n continuityops-lab describe pod -l app.kubernetes.io/name=continuityops-lab | grep -i oom
```

Expected: pods may restart under OOMKilled or show high CPU throttling; readiness
may flap.

## Restore

```bash
./resource-pressure-restore.sh
```

## Verify recovery

```bash
helm -n continuityops-lab get values continuityops-lab
kubectl -n continuityops-lab rollout status deployment/continuityops-lab
kubectl -n continuityops-lab get hpa continuityops-lab 2>/dev/null || true
```

Expected: resources match chart defaults; stable Ready replicas; HPA within min/max.
