#!/usr/bin/env bash
# Shared AWS env bootstrap for LZ lab scripts.
# Prefer Cursor Cloud Agent IAM-role injection; fail fast if missing.
set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_SDK_LOAD_CONFIG="${AWS_SDK_LOAD_CONFIG:-1}"

EXPECTED_ROLE_ARN='arn:aws:iam::283077380808:role/CursorCloudAgent'

if [[ -z "${AWS_PROFILE:-}" ]]; then
  if [[ -n "${CURSOR_AWS_ASSUME_IAM_ROLE_ARN:-}" ]] || \
     aws configure list-profiles 2>/dev/null | grep -qx 'cursor-cloud-agent'; then
    export AWS_PROFILE=cursor-cloud-agent
  fi
fi

if ! aws sts get-caller-identity >/tmp/lzlab-sts.json 2>/tmp/lzlab-sts.err; then
  echo "AWS credentials not available in this environment." >&2
  echo "Required Cloud Agents secret:" >&2
  echo "  CURSOR_AWS_ASSUME_IAM_ROLE_ARN=${EXPECTED_ROLE_ARN}" >&2
  echo "Then start a NEW Cloud Agent (pods started before the secret will not" >&2
  echo "receive AWS_PROFILE=cursor-cloud-agent / AWS_CONFIG_FILE injection)." >&2
  echo "Debug: AWS_PROFILE=${AWS_PROFILE:-<unset>} AWS_CONFIG_FILE=${AWS_CONFIG_FILE:-<unset>} CURSOR_AWS_ASSUME_IAM_ROLE_ARN=${CURSOR_AWS_ASSUME_IAM_ROLE_ARN:-<unset>}" >&2
  cat /tmp/lzlab-sts.err >&2 || true
  exit 3
fi
