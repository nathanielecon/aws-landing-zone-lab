# Drill: DNS and service discovery failure

**Type:** Lab inject (`kubernetes/scenarios/dns-fail-inject.sh`)  
**Misleading symptoms:** No  
**Environment:** `continuityops-lab`  
**Related runbooks:** `dns-tls-checks.md`, `security-boundary-checks.md`

## Scenario

Application logs show resolver errors; calls to
`continuityops-lab.continuityops-lab.svc.cluster.local` or external hostnames
fail. Readiness may flip to 503 if dependencies use DNS names.

## Hypothesis

Cluster DNS unreachable from workload pods due to NetworkPolicy blocking egress
to kube-dns on UDP/TCP 53, or CoreDNS overload/unavailable.

## First-five-minute checks

1. `nslookup kubernetes.default.svc.cluster.local` from app pod.
2. Compare working vs failing namespace (policy drift).
3. CoreDNS pod status in `kube-system`.
4. Recent NetworkPolicy or Helm `networkPolicy.dns` change.
5. Distinguish in-cluster DNS from external DNS (upstream may still fail
   differently).

## Commands

```bash
# Inject (lab only)
cd continuityops/kubernetes/scenarios && ./dns-fail-inject.sh

# From workload
kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  nslookup kubernetes.default.svc.cluster.local

kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  nslookup continuityops-lab.continuityops-lab.svc.cluster.local

# CoreDNS
kubectl -n kube-system get pods -l k8s-app=kube-dns
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=30

# Policy
kubectl -n continuityops-lab get networkpolicy -o yaml | grep -A30 'port: 53'

# App logs
kubectl -n continuityops-lab logs -l app.kubernetes.io/name=continuityops-lab --tail=50

# Restore
cd continuityops/kubernetes/scenarios && ./dns-fail-restore.sh
```

## Timeline (example)

| Time (UTC) | Event |
| --- | --- |
| T+0 | Error rate spike; logs show `NXDOMAIN` / i/o timeout |
| T+4 | DNS lookup fails from app pod |
| T+9 | Restrictive NetworkPolicy from drill identified |
| T+12 | Restore script applied |
| T+16 | DNS succeeds; readiness recovers |

## Ruled-out causes

- Application code regression (fails only when policy injected)
- TLS issues (failures at resolver, not handshake)
- Service deleted (short name fails but `kubernetes.default` also fails)
- Ingress misconfiguration (in-cluster DNS fails independent of ingress)

## Root cause

Drill NetworkPolicy denied DNS egress to kube-dns labels. Production analog:
values overlay removed `networkPolicy.dns` stanza or wrong `namespaceSelector`.

## Recovery choice

**Chosen:** Restore chart-default NetworkPolicy allowing DNS to kube-dns;
`helm upgrade` with validated values if drifted.

**Not chosen:** `hostAliases` hack in Deployment — hides misconfiguration.

## Verification

- `nslookup kubernetes.default` and service name succeed from app pod
- `/readyz` 200 via `app-smoke.md`
- CoreDNS pods healthy, no DNS timeout in logs 15 minutes

## User impact draft

```text
Subject: Lab service discovery disruption

Lab workloads could not resolve internal service names between {start} and {end}
UTC. External customer systems were not affected. Service restored after network
policy correction.
```

## Follow-up

- Policy diff in code review for `egress` and `dns` blocks
- Alert on DNS error log rate per deployment
- Re-run drill quarterly with on-call
