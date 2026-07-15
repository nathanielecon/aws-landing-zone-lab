#!/usr/bin/env bash
# Restore resource defaults — ContinuityOps lab drill stub.
set -euo pipefail

NAMESPACE="${NAMESPACE:-continuityops-lab}"
RELEASE="${RELEASE:-continuityops-lab}"
CHART_DIR="${CHART_DIR:-$(cd "$(dirname "$0")/../chart" && pwd)}"

helm -n "${NAMESPACE}" upgrade "${RELEASE}" "${CHART_DIR}" --reuse-values
kubectl -n "${NAMESPACE}" rollout status deployment/"${RELEASE}"
echo "Chart defaults re-applied for resources."
