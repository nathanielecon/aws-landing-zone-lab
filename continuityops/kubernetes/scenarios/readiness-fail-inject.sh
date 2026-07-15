#!/usr/bin/env bash
# Inject readiness probe failure — ContinuityOps lab drill stub.
set -euo pipefail

NAMESPACE="${NAMESPACE:-continuityops-lab}"
RELEASE="${RELEASE:-continuityops-lab}"

kubectl -n "${NAMESPACE}" patch deployment "${RELEASE}" \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/not-ready"}]'
echo "Readiness probe pointed at /not-ready. Verify endpoints shrink."
