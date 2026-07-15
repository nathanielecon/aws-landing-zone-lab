# Drill: pod startup and configuration failure

**Type:** Lab inject (config/Secret)  
**Misleading symptoms:** No  
**Environment:** `continuityops-lab`  
**Related runbooks:** `kubectl-first-five.md`, `process-logs-in-container.md`

## Scenario

After a values change, new pods stay `CrashLoopBackOff` or never become Ready.
Older replicas may still serve traffic until rollout completes, then endpoints
drain to zero.

## Hypothesis

Startup failure caused by missing or invalid configuration: ConfigMap key typo,
referenced Secret not mounted, or `API_TOKEN` key absent from
`continuityops-lab-secrets`.

## First-five-minute checks

1. `kubectl describe pod` for `CreateContainerConfigError`, `FailedMount`, probe
   failures.
2. Compare Helm values `config` and `secret.keys` to live ConfigMap/Secret.
3. Read `--previous` logs for panic on missing env var.
4. Check `startupProbe` vs slow start (less common than missing Secret).
5. Confirm change record for the deploy that triggered rollout.

## Commands

```bash
kubectl -n continuityops-lab get pods -l app.kubernetes.io/name=continuityops-lab
kubectl -n continuityops-lab get events --sort-by=.lastTimestamp | tail -25

POD=$(kubectl -n continuityops-lab get pod \
  -l app.kubernetes.io/name=continuityops-lab \
  -o jsonpath='{.items[0].metadata.name}')
kubectl -n continuityops-lab describe pod "$POD"

kubectl -n continuityops-lab logs "$POD" --previous --tail=60 2>/dev/null

kubectl -n continuityops-lab get configmap -l app.kubernetes.io/name=continuityops-lab -o yaml | head -50
kubectl -n continuityops-lab get secret continuityops-lab-secrets -o jsonpath='{.data}' 2>&1 | head -5

helm -n continuityops-lab get values continuityops-lab | grep -A10 'config:\|secret:'
```

## Timeline (example)

| Time (UTC) | Event |
| --- | --- |
| T+0 | Deploy pipeline applies Helm upgrade |
| T+2 | New ReplicaSet pods CrashLoop |
| T+5 | Endpoints drop as old pods terminated |
| T+8 | `FailedMount` on Secret key `API_TOKEN` identified |
| T+15 | Secret key restored (out-of-band value, not committed) |
| T+18 | Rollout completes; pods Ready |

## Ruled-out causes

- Image pull failure (events show mount/config, not `ErrImagePull`)
- NetworkPolicy (pods fail before network test)
- OOMKilled (memory within limits at crash)
- Liveness killing healthy slow start (startup never reaches listen)

## Root cause

Helm upgrade referenced `secret.keys` including `API_TOKEN` but the Secret object
in the namespace was missing that key after a manual Secret edit. Chart expects
`secret.create: false` and external Secret management.

## Recovery choice

**Chosen:** Patch Secret in namespace with required keys (values from vault, not
git); `kubectl rollout restart deployment/continuityops-lab` if needed.

**Not chosen:** Disable Secret mount or run without auth — violates lab security
baseline.

## Verification

- All pods `Running` and `Ready`
- `kubectl get endpoints` shows expected ready addresses
- `app-smoke.md` all paths 200
- No `CreateContainerConfigError` in events for 30 minutes

## User impact draft

```text
Subject: Lab API unavailable during deployment

The ContinuityOps lab API was temporarily unavailable between {start} and {end}
UTC while a configuration update rolled out. The issue was caused by a missing
configuration reference and has been corrected. Staging/production were not
affected.
```

## Follow-up

- Pre-deploy check: Secret keys exist (`kubectl describe secret`)
- Add CI check for required Secret keys in lab namespace
- Document Secret ownership in change template
- Optional: use `secret.create: true` only in ephemeral kind clusters
