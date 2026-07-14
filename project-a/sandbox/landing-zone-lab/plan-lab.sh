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

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
STATE_BUCKET="project-a-lzlab-tfstate-${ACCOUNT}"

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
if [[ ! -f backend.hcl ]]; then
  cat > backend.hcl <<EOF
bucket       = "${STATE_BUCKET}"
key          = "lab/landing-zone-lab.tfstate"
region       = "${AWS_REGION}"
encrypt      = true
use_lockfile = true
EOF
  echo "Wrote provisional lab/backend.hcl"
  cat backend.hcl
fi

if aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
  terraform init -backend-config=backend.hcl -input=false -reconfigure
  terraform plan -input=false -no-color
else
  echo "State bucket ${STATE_BUCKET} not present yet; validate only (apply state-bootstrap first)."
  terraform init -backend=false -input=false -reconfigure
  terraform validate
fi

echo "plan-ok"
