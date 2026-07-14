#!/usr/bin/env bash
# Shared AWS env bootstrap for LZ lab scripts.
# Prefer ambient credentials (GitHub Actions OIDC or local assumed role).
# CURSOR_AWS_ASSUME_IAM_ROLE_ARN remains supported but is not required.
set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_SDK_LOAD_CONFIG="${AWS_SDK_LOAD_CONFIG:-1}"

EXPECTED_GHA_ROLE='project-a-lzlab-gha'
EXPECTED_CURSOR_ROLE_ARN='arn:aws:iam::<AWS_ACCOUNT_ID>:role/CursorCloudAgent'

if [[ -z "${AWS_PROFILE:-}" ]]; then
  if [[ -n "${CURSOR_AWS_ASSUME_IAM_ROLE_ARN:-}" ]] || \
     aws configure list-profiles 2>/dev/null | grep -qx 'cursor-cloud-agent'; then
    export AWS_PROFILE=cursor-cloud-agent
  fi
fi

if ! aws sts get-caller-identity >/tmp/lzlab-sts.json 2>/tmp/lzlab-sts.err; then
  echo "AWS credentials not available in this environment." >&2
  echo "Expected one of:" >&2
  echo "  - GitHub Actions OIDC role ${EXPECTED_GHA_ROLE} (preferred)" >&2
  echo "  - CURSOR_AWS_ASSUME_IAM_ROLE_ARN=${EXPECTED_CURSOR_ROLE_ARN} (legacy Cloud Agent)" >&2
  echo "  - Local non-root credentials able to apply the lab" >&2
  echo "Debug: AWS_PROFILE=${AWS_PROFILE:-<unset>} AWS_CONFIG_FILE=${AWS_CONFIG_FILE:-<unset>} CURSOR_AWS_ASSUME_IAM_ROLE_ARN=${CURSOR_AWS_ASSUME_IAM_ROLE_ARN:-<unset>}" >&2
  cat /tmp/lzlab-sts.err >&2 || true
  exit 3
fi
