#!/usr/bin/env bash
# Apply sequence for single-account Landing Zone lab (us-east-1).
# Scored control plane: GitHub Actions OIDC role project-a-lzlab-gha
# (see ci-bootstrap/ + .github/workflows/landing-zone-lab.yml).
# Do NOT use account root. Do NOT chase CURSOR_AWS_ASSUME_IAM_ROLE_ARN
# for this lab — Cloud Agents edit PRs; GHA applies.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=aws-env.sh
source "$ROOT/aws-env.sh"

CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text)
case "$CALLER_ARN" in
  *assumed-role/project-a-lzlab-gha/*) ;;
  *) echo "Refusing to apply outside the expected non-root OIDC role." >&2; exit 2 ;;
esac
echo "Verified expected non-root OIDC role."


ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
OPERATOR_ROLE='project-a-lzlab-operator'
STATE_BUCKET="project-a-lzlab-tfstate-${ACCOUNT}"

echo "== operator IAM (lab non-root principal resources) =="
cd "$ROOT/operator"
terraform init -backend=false -input=false
if aws iam get-role --role-name "$OPERATOR_ROLE" >/dev/null 2>&1; then
  echo "Operator role already exists; skipping apply (CI uses ephemeral local state)."
  # Still emit placeholder outputs file for evidence scripts if missing.
  if [[ ! -f /tmp/lzlab-operator-outputs.json ]]; then
    printf '%s\n' "{\"operator_role_arn\":{\"value\":\"arn:aws:iam::${ACCOUNT}:role/${OPERATOR_ROLE}\"}}" \
      > /tmp/lzlab-operator-outputs.json
    chmod 600 /tmp/lzlab-operator-outputs.json
  fi
else
  terraform apply -input=false -auto-approve
  terraform output -json > /tmp/lzlab-operator-outputs.json
  chmod 600 /tmp/lzlab-operator-outputs.json
fi

echo "== state-bootstrap =="
cd "$ROOT/state-bootstrap"
terraform init -backend=false -input=false
if aws s3api head-bucket --bucket "$STATE_BUCKET" >/dev/null 2>&1; then
  echo "State bucket ${STATE_BUCKET} already exists; writing backend.hcl from known values."
  KMS_ALIAS_ARN=$(aws kms describe-key --key-id "alias/project-a-lzlab-tfstate" --query 'KeyMetadata.Arn' --output text)
  cat > "$ROOT/lab/backend.hcl" <<EOF
bucket       = "${STATE_BUCKET}"
key          = "lab/landing-zone-lab.tfstate"
region       = "${AWS_REGION}"
encrypt      = true
kms_key_id   = "${KMS_ALIAS_ARN}"
use_lockfile = true
EOF
else
  terraform apply -input=false -auto-approve
  terraform output -raw backend_hcl > "$ROOT/lab/backend.hcl"
fi

echo "== lab (identity + network + audit) =="
cd "$ROOT/lab"
terraform init -backend-config=backend.hcl -input=false -reconfigure
terraform apply -input=false -auto-approve
terraform output -json > /tmp/lzlab-lab-outputs.json

echo "== capture evidence =="
bash "$ROOT/capture-evidence.sh" "$ROOT/EVIDENCE.capture.md"
echo "done"
