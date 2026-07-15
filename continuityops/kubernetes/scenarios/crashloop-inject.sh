#!/usr/bin/env bash
# Inject CrashLoopBackOff — ContinuityOps lab drill stub.
set -euo pipefail

NAMESPACE="${NAMESPACE:-continuityops-lab}"
RELEASE="${RELEASE:-continuityops-lab}"
DEPLOY="${RELEASE}"

echo "Patching deployment/${DEPLOY} in namespace ${NAMESPACE} to crash on start..."
kubectl -n "${NAMESPACE}" patch deployment "${DEPLOY}" \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/command","value":["/bin/sh","-c","echo crashloop inject; exit 1"]}]'
echo "Inject complete. Watch: kubectl -n ${NAMESPACE} get pods -w"
