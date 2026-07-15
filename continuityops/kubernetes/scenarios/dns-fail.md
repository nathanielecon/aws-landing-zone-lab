# DNS resolution failure drill

Block cluster DNS egress for the workload and observe failed upstream lookups.
Restores default chart NetworkPolicy egress rules afterward.

## Prerequisites

- Chart installed with `networkPolicy.enabled: true`
- CoreDNS/kube-dns reachable under default cluster labels

## Inject

```bash
./dns-fail-inject.sh
```

Applies a restrictive NetworkPolicy that denies DNS egress (overrides chart policy
for the drill namespace).

## Verify failure

```bash
kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  nslookup kubernetes.default.svc.cluster.local || true
kubectl -n continuityops-lab logs -l app.kubernetes.io/name=continuityops-lab --tail=50
```

Expected: DNS lookups time out or fail; app logs show resolver errors if it
calls external hostnames.

## Restore

```bash
./dns-fail-restore.sh
```

## Verify recovery

```bash
kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  nslookup kubernetes.default.svc.cluster.local
```

Expected: DNS resolves; application resumes normal outbound behavior.
