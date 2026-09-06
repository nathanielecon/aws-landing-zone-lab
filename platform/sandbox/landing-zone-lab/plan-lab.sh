#!/usr/bin/env bash
# Protected, manually dispatched live plan. Pull requests use offline validation.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=aws-env.sh
source "$ROOT/aws-env.sh"

CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text)
case "$CALLER_ARN" in
  *assumed-role/project-a-lzlab-gha/*) ;;
  *) echo "Refusing to plan outside the expected non-root OIDC role." >&2; exit 2 ;;
esac
echo "Verified expected non-root OIDC role."

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
STATE_BUCKET="project-a-lzlab-tfstate-${ACCOUNT}"

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
  echo "Prepared ephemeral backend configuration."
fi

if aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
  PLAN_DIR=$(mktemp -d)
  PLAN_FILE="$PLAN_DIR/tfplan"
  PLAN_LOG="$PLAN_DIR/terraform.log"
  trap 'rm -rf "$PLAN_DIR"' EXIT
  if ! terraform init -backend-config=backend.hcl -input=false -reconfigure >"$PLAN_LOG" 2>&1; then
    echo "Terraform backend initialization failed; raw output withheld to protect live identifiers." >&2
    exit 1
  fi
  if ! terraform plan -input=false -lock=false -no-color -out="$PLAN_FILE" >"$PLAN_LOG" 2>&1; then
    echo "Terraform plan failed; raw output withheld to protect live identifiers." >&2
    exit 1
  fi
  terraform show -json "$PLAN_FILE" | jq -r '
    [.resource_changes[]?.change.actions] |
    {create: map(select(index("create"))) | length,
     update: map(select(index("update"))) | length,
     delete: map(select(index("delete"))) | length,
     no_op: map(select(index("no-op"))) | length} |
    "Plan summary: create=\(.create) update=\(.update) delete=\(.delete) unchanged=\(.no_op)"'
else
  echo "Expected remote state is unavailable; refusing to produce a speculative live plan." >&2
  exit 1
fi

echo "plan-ok"
