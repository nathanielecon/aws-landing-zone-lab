#!/usr/bin/env bash
# Inject resource pressure — ContinuityOps lab drill stub.
set -euo pipefail

NAMESPACE="${NAMESPACE:-continuityops-lab}"
RELEASE="${RELEASE:-continuityops-lab}"

kubectl -n "${NAMESPACE}" patch deployment "${RELEASE}" \
  --type='json' \
  -p='[
    {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"32Mi"},
    {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"10m"}
  ]'
echo "Memory limit lowered to 32Mi. Watch for OOMKilled / throttling."
