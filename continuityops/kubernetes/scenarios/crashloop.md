# CrashLoopBackOff drill

Simulate a failing container entrypoint and verify alerting, restart backoff,
and restore to healthy `/healthz` and `/readyz` responses.

## Prerequisites

- Chart installed: `helm upgrade --install continuityops-lab ./chart -n continuityops-lab --create-namespace`
- `kubectl` context pointed at lab cluster (kind preflight or EKS evidence)

## Inject

```bash
./crashloop-inject.sh
```

Or manually patch the deployment to run a failing command:

```bash
kubectl -n continuityops-lab patch deployment continuityops-lab \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/command","value":["/bin/sh","-c","exit 1"]}]'
```

## Verify failure

```bash
kubectl -n continuityops-lab get pods -w
kubectl -n continuityops-lab describe pod -l app.kubernetes.io/name=continuityops-lab | grep -A5 "State:"
kubectl -n continuityops-lab get events --sort-by=.lastTimestamp | tail -20
```

Expected: pods enter `CrashLoopBackOff`, readiness fails, Service endpoints drop.

## Restore

```bash
./crashloop-restore.sh
```

Or roll back the Helm release:

```bash
helm -n continuityops-lab rollback continuityops-lab
```

## Verify recovery

```bash
kubectl -n continuityops-lab rollout status deployment/continuityops-lab
kubectl -n continuityops-lab run curl --rm -it --restart=Never \
  --image=curlimages/curl:8.5.0 -- \
  curl -sf "http://continuityops-lab:8080/healthz"
```

Expected: all replicas Ready, endpoints restored, HTTP 200 from health check.
