# Readiness probe failure drill

Force readiness checks to fail while the process stays running. Verifies
traffic is removed from failing pods without full crash loops.

## Prerequisites

Same as `crashloop.md`.

## Inject

```bash
./readiness-fail-inject.sh
```

Patches `readinessProbe.httpGet.path` to `/not-ready` so probes fail.

## Verify failure

```bash
kubectl -n continuityops-lab get pods
kubectl -n continuityops-lab get endpoints continuityops-lab -o yaml
```

Expected: pods Running but not Ready; endpoints exclude failing pods.

## Restore

```bash
./readiness-fail-restore.sh
```

## Verify recovery

```bash
kubectl -n continuityops-lab wait --for=condition=ready pod \
  -l app.kubernetes.io/name=continuityops-lab --timeout=120s
kubectl -n continuityops-lab get endpoints continuityops-lab
```

Expected: all pods Ready, endpoints match replica count.
