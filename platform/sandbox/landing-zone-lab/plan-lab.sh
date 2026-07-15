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

# Retarget GHA OIDC trust to aws-landing-zone-lab (idempotent; safe after rename).
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
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:nathanielecon/aws-landing-zone-lab:ref:refs/heads/main",
            "repo:nathanielecon/aws-landing-zone-lab:pull_request",
            "repo:nathanielecon/aws-landing-zone-lab:ref:refs/heads/cursor/*",
            "repo:nathanielecon/aws-landing-zone-lab:environment:lab"
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
