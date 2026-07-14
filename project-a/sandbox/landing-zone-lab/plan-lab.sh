#!/usr/bin/env bash
# Plan-only sequence for CI PRs (no apply).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=aws-env.sh
source "$ROOT/aws-env.sh"

echo "== caller =="
aws sts get-caller-identity
CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text)
case "$CALLER_ARN" in
  *[:/]root) echo "Refusing to plan as account root: $CALLER_ARN" >&2; exit 2 ;;
esac

echo "== operator plan =="
cd "$ROOT/operator"
terraform init -backend=false -input=false
terraform plan -input=false -no-color

echo "== state-bootstrap plan =="
cd "$ROOT/state-bootstrap"
terraform init -backend=false -input=false
terraform plan -input=false -no-color

echo "== lab plan =="
cd "$ROOT/lab"
if [[ -f backend.hcl ]]; then
  terraform init -backend-config=backend.hcl -input=false -reconfigure
else
  # Before first apply, state backend may not exist yet — validate/plan local-only.
  terraform init -backend=false -input=false
fi
terraform plan -input=false -no-color
echo "plan-ok"
