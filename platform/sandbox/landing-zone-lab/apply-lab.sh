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

echo "== caller (must be non-root CI/lab role) =="
aws sts get-caller-identity
CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text)
case "$CALLER_ARN" in
  *[:/]root) echo "Refusing to apply as account root: $CALLER_ARN" >&2; exit 2 ;;
esac
case "$CALLER_ARN" in
  *project-a-lzlab-gha*) ;;
  *project-a-lzlab-operator*|*assumed-role*)
    echo "Warning: caller is not GHA OIDC role project-a-lzlab-gha: $CALLER_ARN" >&2
    echo "Preferred scored path is assumed-role/project-a-lzlab-gha via GitHub Actions." >&2
    ;;
  *)
    echo "Warning: caller is not clearly a lab CI role: $CALLER_ARN" >&2
    echo "Expected assumed-role/project-a-lzlab-gha (GitHub OIDC)." >&2
    ;;
esac

# Retarget GHA OIDC trust (immutable sub after 2026-07-15 renames; idempotent).
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
ROLE_NAME="project-a-lzlab-gha"
TRUST_FILE=$(mktemp)
cat > "$TRUST_FILE" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitHubActionsOidc",
      "Effect": "Allow",
      "Principal": { "Federated": "${OIDC_ARN}" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:repository_id": "1296742987",
          "token.actions.githubusercontent.com:repository_owner_id": "177059064"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:nathanielecon@177059064/*@1296742987:ref:refs/heads/main",
            "repo:nathanielecon@177059064/*@1296742987:pull_request",
            "repo:nathanielecon@177059064/*@1296742987:ref:refs/heads/cursor/*",
            "repo:nathanielecon@177059064/*@1296742987:environment:lab"
          ]
        }
      }
    }
  ]
}
EOF
echo "== retarget OIDC trust on ${ROLE_NAME} =="
aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "file://${TRUST_FILE}"
rm -f "$TRUST_FILE"


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
