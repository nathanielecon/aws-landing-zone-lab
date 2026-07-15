#!/usr/bin/env bash
# Shared AWS env bootstrap for LZ lab scripts.
# Prefer ambient credentials from GitHub Actions OIDC (project-a-lzlab-gha).
# Cursor Cloud Agent assume-role is not the scored control plane for this lab.
set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_SDK_LOAD_CONFIG="${AWS_SDK_LOAD_CONFIG:-1}"

EXPECTED_GHA_ROLE='project-a-lzlab-gha'

# Do not auto-select cursor-cloud-agent for this lab. Ambient GHA OIDC (or an
# explicit operator/break-glass profile set by the caller) is required.

if ! aws sts get-caller-identity >/tmp/lzlab-sts.json 2>/tmp/lzlab-sts.err; then
  echo "AWS credentials not available in this environment." >&2
  echo "Expected:" >&2
  echo "  - GitHub Actions OIDC role ${EXPECTED_GHA_ROLE} (scored control plane)" >&2
  echo "  - or explicit non-root operator/break-glass credentials for local bootstrap" >&2
  echo "Do not chase CURSOR_AWS_ASSUME_IAM_ROLE_ARN for this lab apply path." >&2
  echo "Debug: AWS_PROFILE=${AWS_PROFILE:-<unset>} AWS_CONFIG_FILE=${AWS_CONFIG_FILE:-<unset>}" >&2
  cat /tmp/lzlab-sts.err >&2 || true
  exit 3
fi
