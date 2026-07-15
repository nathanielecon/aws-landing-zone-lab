#!/usr/bin/env bash
# Restore readiness probe — ContinuityOps lab drill stub.
set -euo pipefail

NAMESPACE="${NAMESPACE:-continuityops-lab}"
RELEASE="${RELEASE:-continuityops-lab}"

helm -n "${NAMESPACE}" rollback "${RELEASE}" 0 2>/dev/null || \
  kubectl -n "${NAMESPACE}" patch deployment "${RELEASE}" \
    --type='json' \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/readyz"}]'
kubectl -n "${NAMESPACE}" rollout status deployment/"${RELEASE}"
echo "Readiness probe restored to /readyz."
