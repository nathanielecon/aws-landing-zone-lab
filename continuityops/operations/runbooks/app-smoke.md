# Runbook: application smoke tests

End-to-end HTTP validation after mitigation, deploy, or drill restore. Contract
defined in `continuityops/app-contract/openapi-smoke.yaml`.

## Scope

Paths: `/healthz`, `/readyz`, `/version`, `/api/smoke` on port 8080.

## Do not do this yet

- **Do not** treat smoke pass as full recovery if DLQ depth, error rate, or SLO
  burn is still elevated — check observability dashboards.
- **Do not** run load tests from this runbook during active SEV-1 — use single
  synthetic requests only.
- **Do not** smoke test against production URLs from unapproved networks.
- **Do not** mark incident resolved on `/healthz` alone when user reports cite
  `/api/smoke` or async worker failures.

## First-five-minute checks

1. Confirm target URL (port-forward, in-cluster Service, or ingress host).
2. Baseline: capture status codes before change when possible.
3. Check `/readyz` not only `/healthz` — liveness can pass while not serving.
4. Note release version from `/version` for rollback correlation.
5. If HTTP green but users still impacted, pivot to serverless/SLO runbooks.

## Commands

### Port-forward (local)

```bash
kubectl -n continuityops-lab port-forward svc/continuityops-lab 8080:8080 &
sleep 2
BASE=http://127.0.0.1:8080
```

### In-cluster (preferred for lab)

```bash
kubectl -n continuityops-lab run smoke --rm -it --restart=Never \
  --image=curlimages/curl:8.5.0 -- sh -c '
    BASE=http://continuityops-lab:8080
    for path in /healthz /readyz /version /api/smoke; do
      code=$(curl -sS -o /dev/null -w "%{http_code}" "$BASE$path")
      echo "$path $code"
    done
  '
```

### External ingress

```bash
HOST=https://lab.continuityops.local
for path in /healthz /readyz /version /api/smoke; do
  curl -sS -o /dev/null -w "${path} %{http_code}\n" "${HOST}${path}"
done
```

### JSON body spot-check

```bash
curl -sS http://127.0.0.1:8080/api/smoke | head -c 500
```

Expected: HTTP 200 on all paths; `/readyz` must not be 503 after recovery.

## Interpretation

| Result | Meaning |
| --- | --- |
| `/healthz` 200, `/readyz` 503 | Dependency not ready — keep traffic drained |
| All 200 but stale `/version` | Wrong image still running — check rollout |
| `/api/smoke` fails, probes pass | Business path broken — not infra-only |
| Intermittent 502 external only | LB/ingress — see `lb-target-health.md` |

## Stop / escalation

**Stop** declaring victory and escalate when:

- Smoke passes but SLO error budget still burning
- `/api/smoke` fails consistently after two rollbacks
- Version string does not match approved change record
- Async pipeline still failing (check S3 worker metrics and DLQ)

Escalate to service owner with curl output, `/version` body, and correlation
with last deploy time.

## Post-smoke

- Record results in incident or change record
- Watch dashboards 30 minutes (SEV-2) or 60 minutes (SEV-1)
- Close only after IC confirms customer impact cleared
