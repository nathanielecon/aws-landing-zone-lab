#!/usr/bin/env bash
# Restore from CrashLoopBackOff drill — ContinuityOps lab drill stub.
set -euo pipefail

NAMESPACE="${NAMESPACE:-continuityops-lab}"
RELEASE="${RELEASE:-continuityops-lab}"

echo "Rolling back Helm release ${RELEASE} in ${NAMESPACE}..."
helm -n "${NAMESPACE}" rollback "${RELEASE}" 0 2>/dev/null || \
  kubectl -n "${NAMESPACE}" rollout undo deployment/"${RELEASE}"
kubectl -n "${NAMESPACE}" rollout status deployment/"${RELEASE}"
echo "Restore complete."
