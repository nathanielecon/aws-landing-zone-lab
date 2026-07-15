#!/usr/bin/env bash
# Paste/run in AWS CloudShell (or break-glass CLI) — NOT in Cursor Cloud Agent.
# Restores GitHub Actions OIDC trust for project-a-lzlab-gha after a GitHub rename.
# Rename-resilient: locks repository_id / owner_id; allows nathanielecon/* sub shapes.
set -euo pipefail

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
OIDC_ARN="arn:aws:iam::${ACCOUNT}:oidc-provider/token.actions.githubusercontent.com"
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
            "repo:nathanielecon/*:ref:refs/heads/main",
            "repo:nathanielecon/*:pull_request",
            "repo:nathanielecon/*:ref:refs/heads/cursor/*",
            "repo:nathanielecon/*:environment:lab"
          ]
        }
      }
    }
  ]
}
EOF

echo "== update trust on ${ROLE_NAME} (account ${ACCOUNT}) =="
aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "file://${TRUST_FILE}"
rm -f "$TRUST_FILE"

echo "== current trust =="
aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json
echo "ok — dispatch Landing Zone lab (Terraform) plan on aws-landing-zone-lab"
