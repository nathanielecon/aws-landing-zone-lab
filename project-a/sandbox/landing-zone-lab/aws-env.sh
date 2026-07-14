#!/usr/bin/env bash
# Shared AWS env bootstrap for LZ lab scripts.
# Primary path: GitHub Actions OIDC (credentials already in env).
# Local one-off: aws login / default credential chain for bootstrap only.
# Do NOT chase CURSOR_AWS_ASSUME_IAM_ROLE_ARN for this lab goal.
set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_SDK_LOAD_CONFIG="${AWS_SDK_LOAD_CONFIG:-1}"

if ! aws sts get-caller-identity >/tmp/lzlab-sts.json 2>/tmp/lzlab-sts.err; then
  echo "AWS credentials not available." >&2
  echo "Preferred: GitHub Actions OIDC role GitHubActionsLZLab (see github-oidc/)." >&2
  echo "One-off local bootstrap: aws login, then apply github-oidc + state-bootstrap." >&2
  echo "Do not use CURSOR_AWS_ASSUME_IAM_ROLE_ARN for this lab." >&2
  cat /tmp/lzlab-sts.err >&2 || true
  exit 3
fi
