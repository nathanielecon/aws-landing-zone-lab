#!/usr/bin/env bash
# Capture AWS CLI evidence for the single-account LZ lab into EVIDENCE.capture.md
set -euo pipefail
export AWS_REGION="${AWS_REGION:-us-east-1}"
OUT="${1:-$(dirname "$0")/EVIDENCE.capture.md}"
{
  echo "# Capture $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo '## sts get-caller-identity'
  echo '```json'
  aws sts get-caller-identity
  echo '```'
  echo
  echo '## operator user/role'
  echo '```'
  aws iam get-user --user-name project-a-lzlab-operator 2>&1 || true
  aws iam get-role --role-name project-a-lzlab-operator --query 'Role.[RoleName,Arn,CreateDate]' 2>&1 || true
  echo '```'
  echo
  echo '## cloudtrail'
  echo '```'
  aws cloudtrail get-trail-status --name project-a-lzlab-trail 2>&1 || true
  aws cloudtrail describe-trails --trail-name-list project-a-lzlab-trail 2>&1 || true
  echo '```'
  echo
  echo '## archive bucket encryption / public access'
  ACCT=$(aws sts get-caller-identity --query Account --output text)
  BUCKET="project-a-lzlab-archive-${ACCT}"
  echo "bucket=$BUCKET"
  echo '```'
  aws s3api get-bucket-encryption --bucket "$BUCKET" 2>&1 || true
  aws s3api get-public-access-block --bucket "$BUCKET" 2>&1 || true
  aws s3api get-bucket-versioning --bucket "$BUCKET" 2>&1 || true
  echo '```'
  echo
  echo '## vpc + flow logs'
  echo '```'
  VPC=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=project-a-nonproduction-vpc --query 'Vpcs[0].VpcId' --output text 2>&1 || true)
  echo "vpc=$VPC"
  aws ec2 describe-flow-logs --filter Name=resource-id,Values="$VPC" 2>&1 || true
  echo '```'
  echo
  echo '## identity role + oidc'
  echo '```'
  aws iam get-role --role-name workload-audit-writer --query 'Role.[RoleName,Arn,PermissionsBoundary.PermissionsBoundaryArn]' 2>&1 || true
  aws iam list-open-id-connect-providers 2>&1 || true
  echo '```'
} > "$OUT"
echo "wrote $OUT"
