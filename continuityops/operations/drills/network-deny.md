# Drill: network policy deny egress

**Type:** Lab verify (`kubernetes/scenarios/networkpolicy-deny-inject.sh`)  
**Misleading symptoms:** No  
**Environment:** `continuityops-lab`, `networkPolicy.enabled: true`  
**Related runbooks:** `security-boundary-checks.md`, `dns-tls-checks.md`

## Scenario

Application cannot reach a new analytics endpoint or public API. Logs show
connection timeout. DNS resolution succeeds. Other HTTPS calls to allowlisted
lab CIDRs may still work.

## Hypothesis

Default-deny egress NetworkPolicy blocks traffic to destination outside chart
`egressAllowlist` (CIDR + port). Recent feature added outbound call without
policy update.

## First-five-minute checks

1. Confirm DNS works; failure is TCP connection to specific host:port.
2. Compare destination IP/CIDR to `values.yaml` `egressAllowlist`.
3. Test blocked vs allowlisted destination from same pod.
4. Review recent Helm diff for `networkPolicy` section.
5. Rule out corporate proxy requirement (lab chart assumes direct egress).

## Commands

```bash
# Blocked destination (drill)
cd continuityops/kubernetes/scenarios && ./networkpolicy-deny-inject.sh

kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  wget -qO- --timeout=5 https://1.1.1.1/ 2>&1 | head -5 || echo "expected: blocked"

# Allowlisted lab upstream
kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  wget -qO- --timeout=5 https://staging.continuityops.lab/healthz 2>&1 | head -5

# DNS still OK
kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  nslookup kubernetes.default.svc.cluster.local

kubectl -n continuityops-lab get networkpolicy -o yaml

helm -n continuityops-lab get values continuityops-lab -o yaml | grep -A20 egressAllowlist

cd continuityops/kubernetes/scenarios && ./networkpolicy-deny-restore.sh
```

## Timeline (example)

| Time (UTC) | Event |
| --- | --- |
| T+0 | New integration deployed; timeouts in logs |
| T+6 | DNS OK; HTTPS to new host times out |
| T+11 | Destination IP outside `10.0.0.0/8` allowlist |
| T+20 | Change record: add CIDR to allowlist via Helm |
| T+28 | Connectivity verified |

## Ruled-out causes

- DNS failure (resolver succeeds)
- Ingress ingress-side block (egress from pod)
- IAM or application auth errors (connection never established)
- Image pull or pod not Running

## Root cause

Chart NetworkPolicy implements default-deny egress except DNS and explicit
`egressAllowlist`. New outbound dependency used hostname resolving to public IP
outside allowlisted CIDRs.

## Recovery choice

**Chosen:** Add minimal CIDR/port to `egressAllowlist` via approved change;
`helm upgrade` and verify from pod.

**Not chosen:** Disable NetworkPolicy globally — violates security baseline.

## Verification

- Connection to new endpoint succeeds from app pod
- Denied destinations still blocked (regression test with 1.1.1.1 drill)
- `app-smoke.md` passes; no egress timeout logs 30 minutes

## User impact draft

```text
Subject: Lab integration delays

A lab integration experienced outbound connection failures between {start} and
{end} UTC due to network policy configuration. Core API remained available.
Policy has been updated to allow the required destination.
```

## Follow-up

- Require NetworkPolicy review in PR template for new external dependencies
- Document allowlist ownership (S2 + S6)
- Automate egress test in staging deploy pipeline
