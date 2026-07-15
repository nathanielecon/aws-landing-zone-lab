# Runbook: load balancer and target health

Ingress controller, Service endpoints, and load-balancer target health for HTTP
502/503, uneven traffic, or draining backends.

## Scope

- Kubernetes Service `continuityops-lab` (ClusterIP → Endpoints)
- Ingress when enabled (`lab.continuityops.local`)
- Cloud LB target groups (staging EKS — describe via cloud console or CLI; no
  live ARNs in repo)

## Do not do this yet

- **Do not** delete Ingress or Service objects until endpoints are understood —
  causes immediate customer-facing outage.
- **Do not** manually register/unregister LB targets without matching Kubernetes
  readiness state.
- **Do not** disable health checks on the load balancer to "green" the target.
- **Do not** increase ingress timeout above SLO budget without performance
  investigation.

## First-five-minute checks

1. Customer symptom: 502, 503, timeout, or partial region only.
2. Ingress controller pods healthy in `ingress-nginx` or equivalent namespace.
3. Service endpoints count vs ready pod count.
4. Readiness probe failures on backends.
5. Recent deployment or HPA event.

## Commands

```bash
# Backends
kubectl -n continuityops-lab get pods -l app.kubernetes.io/name=continuityops-lab
kubectl -n continuityops-lab get endpoints continuityops-lab -o wide
kubectl -n continuityops-lab get svc continuityops-lab -o yaml | grep -A20 'ports:'

# Ingress
kubectl -n continuityops-lab get ingress -o wide
kubectl -n continuityops-lab describe ingress continuityops-lab 2>/dev/null | tail -40

# Ingress controller (adjust namespace/label for your install)
kubectl -n ingress-nginx get pods 2>/dev/null || \
  kubectl get pods -A -l app.kubernetes.io/name=ingress-nginx

# In-cluster path (bypasses external LB)
kubectl -n continuityops-lab run curl-lb --rm -it --restart=Never \
  --image=curlimages/curl:8.5.0 -- \
  curl -sS -o /dev/null -w "cluster:%{http_code}\n" \
  http://continuityops-lab:8080/readyz

# External path (when DNS and ingress exist)
curl -sS -o /dev/null -w "external:%{http_code}\n" \
  https://lab.continuityops.local/readyz
```

## Interpretation

| Signal | Likely cause |
| --- | --- |
| Endpoints < ready replicas | Readiness failing — app not accepting traffic |
| Endpoints empty | All pods not Ready or selector mismatch |
| In-cluster 200, external 503 | Ingress, LB, or TLS front door |
| Uneven endpoint ages | Rolling update stuck, PDB blocking |
| 502 with healthy pods | Ingress upstream timeout, wrong port name |

## Stop / escalation

**Stop** and escalate when:

- Ingress controller CrashLoop or multi-cluster ingress failure
- Cloud LB shows all targets unhealthy but pods pass in-cluster probes
- DDoS or WAF block suspected (traffic spike with 403/503 at edge)
- Need emergency DNS or WAF rule change

Escalate to S2 + platform networking with endpoint snapshot, ingress events,
and external vs internal curl results.

## Related drills

- `drills/ingress-health.md`
- `drills/bad-release-rollback.md`

After fix: external `/healthz` and `/readyz` 200, endpoints stable 10+ minutes.
