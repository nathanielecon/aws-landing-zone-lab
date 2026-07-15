#!/usr/bin/env bash
# Restore DNS egress — ContinuityOps lab drill stub.
set -euo pipefail

NAMESPACE="${NAMESPACE:-continuityops-lab}"
POLICY_NAME="continuityops-dns-deny-drill"

kubectl -n "${NAMESPACE}" delete networkpolicy "${POLICY_NAME}" --ignore-not-found
echo "Removed drill NetworkPolicy. Re-apply chart policy if needed:"
echo "  helm upgrade --install continuityops-lab ./chart -n ${NAMESPACE}"
