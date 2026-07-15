# Kubernetes failure scenarios (S2)

Drills for CrashLoopBackOff, readiness failure, DNS egress denial,
NetworkPolicy default-deny, and resource pressure. Each scenario includes
inject/restore shell stubs and verification steps.

| Scenario | Guide | Inject | Restore |
| --- | --- | --- | --- |
| CrashLoopBackOff | `crashloop.md` | `crashloop-inject.sh` | `crashloop-restore.sh` |
| Readiness fail | `readiness-fail.md` | `readiness-fail-inject.sh` | `readiness-fail-restore.sh` |
| DNS fail | `dns-fail.md` | `dns-fail-inject.sh` | `dns-fail-restore.sh` |
| NetworkPolicy deny | `networkpolicy-deny.md` | `networkpolicy-deny-inject.sh` | `networkpolicy-deny-restore.sh` |
| Resource pressure | `resource-pressure.md` | `resource-pressure-inject.sh` | `resource-pressure-restore.sh` |

Environment overrides: `NAMESPACE`, `RELEASE`, `CHART_DIR`.

Every drill must restore verified business behavior (health/readiness endpoints,
DNS, allowlisted egress) before closing evidence.
