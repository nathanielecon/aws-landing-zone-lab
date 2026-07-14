#!/usr/bin/env bash
# Apply sequence for single-account Landing Zone lab (us-east-1).
# Expects AWS credentials for account 283077380808.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"

echo "== caller =="
aws sts get-caller-identity

echo "== operator =="
cd "$ROOT/operator"
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve
terraform output -json > /tmp/lzlab-operator-outputs.json
chmod 600 /tmp/lzlab-operator-outputs.json

if command -v jq >/dev/null; then
  aws configure set aws_access_key_id "$(jq -r .operator_access_key_id.value /tmp/lzlab-operator-outputs.json)" --profile lzlab-operator
  aws configure set aws_secret_access_key "$(jq -r .operator_secret_access_key.value /tmp/lzlab-operator-outputs.json)" --profile lzlab-operator
  aws configure set region "$AWS_REGION" --profile lzlab-operator
  export AWS_PROFILE=lzlab-operator
  echo "== switched to non-root operator =="
  aws sts get-caller-identity
fi

echo "== state-bootstrap =="
cd "$ROOT/state-bootstrap"
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve
terraform output -raw backend_hcl > "$ROOT/lab/backend.hcl"

echo "== lab =="
cd "$ROOT/lab"
terraform init -backend-config=backend.hcl -input=false -reconfigure
terraform apply -input=false -auto-approve
terraform output -json > /tmp/lzlab-lab-outputs.json

echo "== done; capture CLI evidence into EVIDENCE.md =="
