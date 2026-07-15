# NetworkPolicy deny drill

Confirm default-deny egress blocks traffic outside the chart allowlist (DNS +
configured CIDRs). Attempts to reach a blocked destination should fail.

## Prerequisites

- `networkPolicy.enabled: true` in values
- A blocked test target (example uses `1.1.1.1:443` outside allowlist)

## Inject

No chart change required — the chart already default-denies non-allowlisted
egress. This drill **verifies** denial:

```bash
./networkpolicy-deny-inject.sh
```

Runs a one-off curl from an app pod to a destination outside the allowlist.

## Verify failure

```bash
kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  wget -qO- --timeout=5 https://1.1.1.1/ 2>&1 || echo "expected: connection blocked or timed out"
```

Expected: connection timeout or policy denial (no successful response).

## Restore

```bash
./networkpolicy-deny-restore.sh
```

No persistent inject state — restore confirms allowlisted egress still works.

## Verify recovery

```bash
# DNS should work (allowlisted via chart policy)
kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  nslookup kubernetes.default.svc.cluster.local
```

Expected: DNS succeeds; only non-allowlisted destinations remain blocked.
