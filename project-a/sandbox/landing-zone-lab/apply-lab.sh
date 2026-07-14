#!/usr/bin/env bash
# Apply sequence for single-account Landing Zone lab (us-east-1).
# Preferred control plane: GitHub Actions OIDC (workflow landing-zone-lab.yml).
# This script is for one-off local bootstrap / apply after aws login.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=aws-env.sh
source "$ROOT/aws-env.sh"

echo "== caller (must not be account root) =="
aws sts get-caller-identity
CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text)
case "$CALLER_ARN" in
  *[:/]root) echo "Refusing to apply as account root: $CALLER_ARN" >&2; exit 2 ;;
esac

echo "== github-oidc (OIDC provider + GitHubActionsLZLab role) =="
cd "$ROOT/github-oidc"
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve
terraform output

echo "== operator IAM (lab non-root principal resources) =="
cd "$ROOT/operator"
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve

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
bash "$ROOT/render-evidence.sh" "$ROOT/EVIDENCE.capture.md" "$ROOT/EVIDENCE.md"
echo "done — prefer future applies via GitHub Actions OIDC workflow"
