# Kubernetes policies (S2)

Admission and runtime constraint examples for the ContinuityOps lab chart.

| File | Purpose |
| --- | --- |
| `require-digest.yaml` | Kyverno — reject tag-only image references |
| `require-nonroot.yaml` | Kyverno — enforce `runAsNonRoot: true` |
| `deny-latest-tag.yaml` | Kyverno — block `:latest` tags |

These are **policy YAML examples** for preflight and negative testing. Apply
only in lab clusters with Kyverno installed. They complement chart defaults
(network policy, PDB, HPA, securityContext) but do not replace live admission
evidence on managed EKS (Phase 2 / gate H2).

Negative tests: attempt to deploy a Pod with `:latest` or without digest and
confirm admission denies the request before any live reliability claim.
