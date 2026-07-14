#!/usr/bin/env bash
# Apply sequence for single-account Landing Zone lab (us-east-1).
# Cloud Agents: use injected cursor-cloud-agent profile via
# CURSOR_AWS_ASSUME_IAM_ROLE_ARN → arn:aws:iam::283077380808:role/CursorCloudAgent.
# Do NOT run aws login or wait on code.txt.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_SDK_LOAD_CONFIG="${AWS_SDK_LOAD_CONFIG:-1}"
if aws configure list-profiles 2>/dev/null | grep -qx 'cursor-cloud-agent'; then
  export AWS_PROFILE="${AWS_PROFILE:-cursor-cloud-agent}"
fi

echo "== caller (must not be account root) =="
aws sts get-caller-identity
CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text)
case "$CALLER_ARN" in
  *[:/]root) echo "Refusing to apply as account root: $CALLER_ARN" >&2; exit 2 ;;
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
