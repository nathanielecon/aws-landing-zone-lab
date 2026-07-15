# continuityops-lab Helm chart

Production-style lab chart for ContinuityOps S2. Images must be pinned by
**digest** (`image.repository@image.digest`). Lab images are ContinuityOps-owned
artifacts — not Project A/C production releases.

## Features

| Area | Default |
| --- | --- |
| Image | Digest pin field (`image.digest`) |
| Security | `runAsNonRoot`, `readOnlyRootFilesystem`, drop ALL caps |
| Scheduling | `topologySpreadConstraints` (zone + hostname) |
| Availability | PDB (`minAvailable: 1`), HPA (CPU 80%) |
| Network | Default-deny egress; DNS + allowlist CIDRs |
| Ingress | Disabled (`ingress.enabled: false`) |
| Secrets | `secretName` reference only; no real values in chart |

## Quick start

```bash
helm lint .
helm template release . -n continuityops-lab \
  --set image.digest=sha256:YOUR_BUILD_DIGEST
```

Before install, create the referenced Secret:

```bash
kubectl -n continuityops-lab create secret generic continuityops-lab-secrets \
  --from-literal=API_TOKEN=lab-placeholder
```

## Key values

See `values.yaml` for probes, resources, `networkPolicy.egressAllowlist`, and
optional ingress TLS hosts.
