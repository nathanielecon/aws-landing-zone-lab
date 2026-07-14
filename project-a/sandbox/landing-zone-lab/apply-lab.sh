#!/usr/bin/env bash
# Apply sequence for single-account Landing Zone lab (us-east-1).
# Preferred: GitHub Actions OIDC role project-a-lzlab-gha (see ci-bootstrap/).
# Legacy: CURSOR_AWS_ASSUME_IAM_ROLE_ARN → CursorCloudAgent.
# Do NOT use account root.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=aws-env.sh
source "$ROOT/aws-env.sh"

echo "== caller (must be non-root CI/lab role) =="
aws sts get-caller-identity
CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text)
case "$CALLER_ARN" in
  *[:/]root) echo "Refusing to apply as account root: $CALLER_ARN" >&2; exit 2 ;;
esac
case "$CALLER_ARN" in
  *project-a-lzlab-gha*|*CursorCloudAgent*|*assumed-role*) ;;
  *)
    echo "Warning: caller is not clearly a lab CI role: $CALLER_ARN" >&2
    echo "Expected assumed-role/project-a-lzlab-gha (GitHub OIDC) or CursorCloudAgent." >&2
    ;;
esac

echo "== operator IAM (lab non-root principal resources) =="
cd "$ROOT/operator"
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve
terraform output -json > /tmp/lzlab-operator-outputs.json
chmod 600 /tmp/lzlab-operator-outputs.json

echo "== state-bootstrap =="
cd "$ROOT/state-bootstrap"
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve
terraform output -raw backend_hcl > "$ROOT/lab/backend.hcl"

echo "== lab (identity + network + audit) =="
cd "$ROOT/lab"
terraform init -backend-config=backend.hcl -input=false -reconfigure
terraform apply -input=false -auto-approve
terraform output -json > /tmp/lzlab-lab-outputs.json

echo "== capture evidence =="
bash "$ROOT/capture-evidence.sh" "$ROOT/EVIDENCE.capture.md"
echo "done"
