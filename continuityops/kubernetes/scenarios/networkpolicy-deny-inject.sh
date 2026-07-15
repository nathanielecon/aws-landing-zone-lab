#!/usr/bin/env bash
# Verify NetworkPolicy denies non-allowlisted egress — ContinuityOps lab stub.
set -euo pipefail

NAMESPACE="${NAMESPACE:-continuityops-lab}"
RELEASE="${RELEASE:-continuityops-lab}"

echo "Attempting blocked egress from deployment/${RELEASE}..."
if kubectl -n "${NAMESPACE}" exec deploy/"${RELEASE}" -- \
  wget -qO- --timeout=5 https://1.1.1.1/ 2>/dev/null; then
  echo "UNEXPECTED: egress to 1.1.1.1 succeeded — review NetworkPolicy."
  exit 1
else
  echo "Expected: egress to 1.1.1.1 blocked or timed out."
fi
