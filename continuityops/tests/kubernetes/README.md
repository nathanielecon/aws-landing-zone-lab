# ContinuityOps Kubernetes chart tests

Validates S2 chart structure and required values without a live cluster.

```bash
pwsh -NoLogo -NoProfile -File continuityops/tests/kubernetes/Test-ContinuityOpsChart.ps1
```

When Helm is installed, also run:

```bash
cd continuityops/kubernetes/chart && helm lint .
```
