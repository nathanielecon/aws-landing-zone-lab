#!/usr/bin/env bash
# Inject DNS egress deny — ContinuityOps lab drill stub.
set -euo pipefail

NAMESPACE="${NAMESPACE:-continuityops-lab}"
POLICY_NAME="continuityops-dns-deny-drill"

cat <<EOF | kubectl -n "${NAMESPACE}" apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${POLICY_NAME}
  labels:
    continuityops.io/drill: dns-fail
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: continuityops-lab
  policyTypes:
    - Egress
  egress:
    # Allow HTTPS only — DNS to kube-dns deliberately omitted.
    - to:
        - ipBlock:
            cidr: 10.0.0.0/8
      ports:
        - protocol: TCP
          port: 443
EOF

echo "Applied ${POLICY_NAME}. DNS egress should now fail for app pods."
