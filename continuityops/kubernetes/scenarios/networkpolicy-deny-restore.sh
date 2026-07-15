#!/usr/bin/env bash
# Confirm allowlisted egress after NetworkPolicy deny drill — stub.
set -euo pipefail

NAMESPACE="${NAMESPACE:-continuityops-lab}"
RELEASE="${RELEASE:-continuityops-lab}"

kubectl -n "${NAMESPACE}" exec deploy/"${RELEASE}" -- \
  nslookup kubernetes.default.svc.cluster.local
echo "DNS allowlist path verified."
