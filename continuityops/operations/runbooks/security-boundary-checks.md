# Runbook: security boundary checks

NetworkPolicy egress/ingress denial, service account boundaries, and suspected
unauthorized connectivity for ContinuityOps lab workloads.

## Scope

- Chart NetworkPolicy (`networkPolicy.enabled: true`)
- Default deny egress except DNS and `egressAllowlist` CIDRs
- Pod security context (non-root, read-only root FS)
- No live IAM keys in cluster Secrets — reference names only

## Do not do this yet

- **Do not** set `networkPolicy.enabled: false` in production/staging without
  emergency change approval and time-bounded exception.
- **Do not** add `0.0.0.0/0` to egress allowlist to "fix" outbound calls.
- **Do not** exec into pods and install debugging packages that violate image
  policy — use ephemeral debug containers if cluster policy allows.
- **Do not** share kubeconfig or cloud console sessions in incident channels.

## First-five-minute checks

1. Is failure egress (app → upstream) or ingress (client → app)?
2. Did a new upstream hostname or port appear (not on allowlist)?
3. Recent Helm values change to `egressAllowlist` or `networkPolicy`?
4. Single workload or cluster-wide CNI/plugin issue?
5. Any security scanner or WAF change in the same window?

## Commands

```bash
# Policies affecting the workload
kubectl -n continuityops-lab get networkpolicy
kubectl -n continuityops-lab describe networkpolicy

# Test denied destination (lab drill uses blocked public IP)
kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  wget -qO- --timeout=5 https://1.1.1.1/ 2>&1 | head -3 || echo "expected: blocked"

# Test allowlisted path (replace with lab upstream)
kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  wget -qO- --timeout=5 https://staging.continuityops.lab/healthz 2>&1 | head -3

# DNS still allowed
kubectl -n continuityops-lab exec deploy/continuityops-lab -- \
  nslookup kubernetes.default.svc.cluster.local

# Pod security context
kubectl -n continuityops-lab get deploy continuityops-lab \
  -o jsonpath='{.spec.template.spec.securityContext}{"\n"}{.spec.template.spec.containers[0].securityContext}{"\n"}'
```

## Interpretation

| Symptom | Likely cause |
| --- | --- |
| Timeout to external API | Egress CIDR/port not on allowlist |
| DNS works, HTTPS fails | Wrong port (443 vs 8443) or IP outside CIDR |
| Ingress works, egress fails | NetworkPolicy egress only |
| Sudden deny after deploy | Values overlay narrowed `egressAllowlist` |

## Stop / escalation

**Stop** and escalate when:

- Suspected intrusion, data exfiltration, or compromised service account
- Need to open broad egress for unknown dependency — requires architecture review
- NetworkPolicy change did not restore traffic — possible CNI bug
- Cross-namespace lateral movement suspected

Escalate to S6 security + S2 Kubernetes. Preserve pod logs and NetworkPolicy
YAML; open security incident if compromise suspected.

## Related drills

- `drills/network-deny.md`
- `kubernetes/scenarios/networkpolicy-deny.md`

Document any allowlist change in `changes/TEMPLATE.md` with rollback plan.
