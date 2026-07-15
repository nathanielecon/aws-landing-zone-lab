# ContinuityOps Kubernetes (S2)

Helm chart, admission policy examples, and failure drills for the pinned lab
application artifact. **kind is preflight only** — managed EKS evidence requires
Phase 2 / gate H2.

## Layout

```text
kubernetes/
  chart/                 Helm chart (digest pin, HPA, PDB, NetworkPolicy)
  policies/              Kyverno policy YAML examples
  scenarios/             Failure drill guides + inject/restore shell stubs
  README.md
```

## Local validation (no cluster required)

Install [Helm 3](https://helm.sh/docs/intro/install/) if not present, then:

```bash
cd continuityops/kubernetes/chart

# Syntax and schema checks
helm lint .

# Render manifests (replace digest before any apply)
helm template continuityops-lab . \
  --namespace continuityops-lab \
  --set image.digest=sha256:0000000000000000000000000000000000000000000000000000000000000000 \
  > /tmp/continuityops-lab-rendered.yaml

# Optional: chart unit test hook manifest
helm template continuityops-lab . \
  --show-only templates/tests/test-connection.yaml \
  --set image.digest=sha256:0000000000000000000000000000000000000000000000000000000000000000
```

Repo tests (no Helm binary required):

```bash
pwsh -NoLogo -NoProfile -File continuityops/tests/kubernetes/Test-ContinuityOpsChart.ps1
```

## kind preflight (optional)

kind confirms chart installability and basic probes — not production SLO proof.

```bash
kind create cluster --name continuityops-preflight
kubectl create namespace continuityops-lab
kubectl -n continuityops-lab create secret generic continuityops-lab-secrets \
  --from-literal=API_TOKEN=lab-placeholder

helm upgrade --install continuityops-lab ./chart \
  -n continuityops-lab \
  --set image.digest=sha256:0000000000000000000000000000000000000000000000000000000000000000

helm -n continuityops-lab test continuityops-lab
```

## Secrets

The chart references `secret.secretName` and never ships real credentials. Create
secrets out-of-band (External Secrets, Sealed Secrets, or `kubectl create secret`).

## Policies and drills

- `policies/` — Kyverno examples: digest pin, non-root, deny `:latest`
- `scenarios/` — CrashLoop, readiness, DNS, NetworkPolicy, resource pressure

Each drill documents inject, verify, restore, and recovery checks.
