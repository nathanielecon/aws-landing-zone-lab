# Runbook: DNS and TLS checks

Resolver, Kubernetes service discovery, and TLS handshake failures for
ContinuityOps workloads.

## Scope

- In-cluster DNS (CoreDNS / kube-dns)
- Service names: `continuityops-lab.continuityops-lab.svc.cluster.local`
- External upstream HTTPS allowlisted in chart `egressAllowlist`
- Ingress TLS when `ingress.enabled: true`

## Do not do this yet

- **Do not** edit NetworkPolicy egress rules until in-cluster DNS succeeds for
  `kubernetes.default.svc.cluster.local`.
- **Do not** disable TLS verification (`curl -k`) except in isolated debug pods —
  document and delete debug pods immediately.
- **Do not** change ingress TLS certificates during active SEV-1 without rollback
  plan and IC approval.
- **Do not** point production DNS to a lab load balancer without a change record.

## First-five-minute checks

1. Failing hostname: cluster DNS name vs external FQDN.
2. Error type: NXDOMAIN, timeout, connection refused, TLS handshake alert.
3. Single pod vs all pods (NetworkPolicy vs global DNS outage).
4. Recent chart or ingress annotation changes.
5. Certificate expiry on ingress secret (if external HTTPS failing).

## Commands

### In-cluster DNS

```bash
kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  nslookup kubernetes.default.svc.cluster.local

kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  nslookup continuityops-lab.continuityops-lab.svc.cluster.local

# Short name resolution inside namespace
kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  getent hosts continuityops-lab
```

### Upstream HTTPS (allowlisted)

```bash
kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  wget -qO- --timeout=5 https://staging.continuityops.lab/healthz 2>&1 | head -5
```

### TLS from debug pod (ingress)

```bash
kubectl -n continuityops-lab run tls-check --rm -it --restart=Never \
  --image=curlimages/curl:8.5.0 -- \
  curl -vI --max-time 10 https://lab.continuityops.local/healthz 2>&1 | \
  grep -E 'SSL|subject|expire|HTTP/'
```

### NetworkPolicy / DNS path

```bash
kubectl -n continuityops-lab get networkpolicy -o yaml | head -80
kubectl -n continuityops-lab get endpoints kube-dns -n kube-system 2>/dev/null || \
  kubectl -n kube-system get endpoints -l k8s-app=kube-dns
```

## Interpretation

| Symptom | Likely cause |
| --- | --- |
| DNS timeout | NetworkPolicy blocking UDP/TCP 53 to kube-dns |
| NXDOMAIN for cluster service | Wrong namespace or service deleted |
| TLS certificate expired | Ingress secret rotation missed |
| TLS unknown CA | Wrong cert chain or internal CA not trusted in client |
| HTTP works in-cluster, fails via ingress | Ingress rules, backend protocol, or cert mismatch |

## Stop / escalation

**Stop** and escalate when:

- CoreDNS pods unhealthy cluster-wide
- TLS failure affects all external customers (SEV-1)
- DNS change required in corporate/registrar zone — needs platform team
- Suspected MITM or cert substitution

Escalate to S2 (Kubernetes/network) with resolver output, `curl -v` handshake
line, and NetworkPolicy name.

## Related drills

- `drills/dns-discovery.md`
- `kubernetes/scenarios/dns-fail.md`

Verify recovery: in-cluster `nslookup` OK, external smoke via `app-smoke.md`.
