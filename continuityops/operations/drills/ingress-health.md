# Drill: ingress and front-door health

**Type:** Lab / staging tabletop  
**Misleading symptoms:** No  
**Environment:** `continuityops-lab` with `ingress.enabled: true`  
**Related runbooks:** `lb-target-health.md`, `app-smoke.md`

## Scenario

External users receive HTTP 502/503 on `https://lab.continuityops.local` while
internal cluster checks against the Service still return 200. Status page shows
"degraded" for lab only.

## Hypothesis

Ingress controller misconfiguration, expired TLS certificate, or empty backends
because readiness fails — traffic stops at the ingress/LB layer while pods may
still pass liveness.

## First-five-minute checks

1. External vs in-cluster curl to `/readyz` (split path diagnosis).
2. Ingress backend references correct Service port name `http`.
3. Endpoints count matches ready pods.
4. Ingress controller pods running; recent cert rotation.
5. Annotation changes (timeouts, SSL redirect).

## Commands

```bash
# Split path
kubectl -n continuityops-lab run curl-int --rm -it --restart=Never \
  --image=curlimages/curl:8.5.0 -- \
  curl -sS -o /dev/null -w "internal:%{http_code}\n" \
  http://continuityops-lab:8080/readyz

curl -sS -o /dev/null -w "external:%{http_code}\n" \
  https://lab.continuityops.local/readyz

# Ingress and endpoints
kubectl -n continuityops-lab get ingress,svc,endpoints
kubectl -n continuityops-lab describe ingress continuityops-lab

# Controller health
kubectl -n ingress-nginx get pods 2>/dev/null || \
  kubectl get pods -A -l app.kubernetes.io/name=ingress-nginx

# TLS cert expiry (ingress secret)
kubectl -n continuityops-lab get secret -o name | grep tls
kubectl -n continuityops-lab describe ingress continuityops-lab | grep -i tls

# Simulate readiness fail (lab)
cd continuityops/kubernetes/scenarios && ./readiness-fail-inject.sh
kubectl -n continuityops-lab get endpoints continuityops-lab
cd continuityops/kubernetes/scenarios && ./readiness-fail-restore.sh
```

## Timeline (example)

| Time (UTC) | Event |
| --- | --- |
| T+0 | External monitor 503; internal monitor green |
| T+5 | Endpoints show 0 ready addresses |
| T+10 | Readiness probe path wrong after inject |
| T+14 | Restore readiness path |
| T+20 | External 200 confirmed |

## Ruled-out causes

- Complete app crash (pods Running, liveness OK)
- DNS public zone (external host resolves; HTTP fails at LB)
- NetworkPolicy ingress (in-cluster Service works from same namespace)
- Upstream dependency (in-cluster `/api/smoke` OK)

## Root cause

Readiness probe pointed at `/not-ready` after drill inject (or analog: ingress
`path` typo routing to non-existent backend). Ingress had no healthy upstreams.

## Recovery choice

**Chosen:** Restore readiness probe path via `readiness-fail-restore.sh` or Helm
rollback; verify endpoints before closing incident.

**Not chosen:** Bypass readiness and force endpoints — sends traffic to broken pods.

## Verification

- External `/healthz`, `/readyz`, `/api/smoke` return 200
- Ingress events show successful sync
- Endpoints stable ≥ ready replicas for 15 minutes

## User impact draft

```text
Subject: Lab HTTPS endpoint unavailable

The lab HTTPS endpoint returned errors between {start} and {end} UTC while
internal health checks recovered earlier/later. No production traffic uses this
hostname. Service has been restored.
```

## Follow-up

- Dual monitor: external + in-cluster on `/readyz`
- Cert expiry alert 30 days before ingress TLS secret
- Document ingress port naming in chart README
