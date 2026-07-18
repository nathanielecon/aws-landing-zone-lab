#!/usr/bin/env bash
# Paste/run in AWS CloudShell (account <AWS_ACCOUNT_ID>) — NOT in Cursor Cloud Agent.
# Creates/updates continuityops-gha for GitHub Actions OIDC (immutable sub).
set -euo pipefail

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
OIDC_ARN="arn:aws:iam::${ACCOUNT}:oidc-provider/token.actions.githubusercontent.com"
ROLE_NAME="continuityops-gha"
OWNER_ID="177059064"
REPO_ID="1296742987"
TRUST_FILE=$(mktemp)
POLICY_FILE=$(mktemp)

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
          "token.actions.githubusercontent.com:repository_id": "${REPO_ID}",
          "token.actions.githubusercontent.com:repository_owner_id": "${OWNER_ID}"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:nathanielecon@${OWNER_ID}/*@${REPO_ID}:ref:refs/heads/main",
            "repo:nathanielecon@${OWNER_ID}/*@${REPO_ID}:pull_request",
            "repo:nathanielecon@${OWNER_ID}/*@${REPO_ID}:ref:refs/heads/cursor/*",
            "repo:nathanielecon@${OWNER_ID}/*@${REPO_ID}:environment:continuityops",
            "repo:nathanielecon@${OWNER_ID}/*@${REPO_ID}:environment:continuityops-staging",
            "repo:nathanielecon@${OWNER_ID}/*@${REPO_ID}:environment:continuityops-recovery-lab"
          ]
        }
      }
    }
  ]
}
EOF

cat > "$POLICY_FILE" <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CoreLabServices",
      "Effect": "Allow",
      "Action": [
        "iam:*", "s3:*", "kms:*", "ec2:*", "eks:*", "ecr:*", "lambda:*",
        "logs:*", "cloudwatch:*", "events:*", "sns:*", "sqs:*", "dynamodb:*",
        "sts:GetCallerIdentity", "sts:AssumeRole", "sts:TagSession"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DenyOrgMemberCreates",
      "Effect": "Deny",
      "Action": [
        "organizations:CreateAccount",
        "organizations:InviteAccountToOrganization"
      ],
      "Resource": "*"
    }
  ]
}
EOF

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "== update trust on existing ${ROLE_NAME} =="
  aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "file://${TRUST_FILE}"
else
  echo "== create ${ROLE_NAME} =="
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "file://${TRUST_FILE}" \
    --description "GitHub Actions OIDC role for ContinuityOps lab plan/apply" \
    --tags Key=Project,Value=continuityops Key=ManagedBy,Value=cloudshell
fi

echo "== put inline policy =="
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "${ROLE_NAME}" \
  --policy-document "file://${POLICY_FILE}"

rm -f "$TRUST_FILE" "$POLICY_FILE"

echo "== current trust =="
aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json
echo "ok — role arn: arn:aws:iam::${ACCOUNT}:role/${ROLE_NAME}"
echo "dispatch ContinuityOps Terraform plan on aws-landing-zone-lab"
