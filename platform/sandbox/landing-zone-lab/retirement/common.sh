#!/usr/bin/env bash
set -euo pipefail

export AWS_PAGER=""
export TF_IN_AUTOMATION=1
export TF_INPUT=false

PREFIX=project-a-lzlab
REGION=us-east-1
LAB_STATE_KEY=lab/landing-zone-lab.tfstate
RETAINED_STATE_KEY=retained-evidence/terraform.tfstate

sanitize_error() {
  sed -E \
    -e 's/[0-9]{12}/<AWS_ACCOUNT_ID>/g' \
    -e "s#arn:(aws|aws-us-gov|aws-cn):[^[:space:]\"]+#<AWS_ARN>#g" \
    -e 's/\b(vpc|subnet|sg|fl|rtb|igw|eni)-[0-9a-f]+\b/<AWS_RESOURCE_ID>/g' \
    -e 's/\b[0-9a-f]{8}-[0-9a-f-]{27,}\b/<AWS_RESOURCE_ID>/g'
}

fail_sanitized() {
  local operation=$1
  local error_file=$2
  printf '%s failed. Sanitized diagnostic:\n' "$operation" >&2
  sanitize_error <"$error_file" >&2
  exit 1
}

require_role() {
  local expected=$1 caller
  caller=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)
  case "$caller" in
    *"assumed-role/${expected}/"*) ;;
    *) printf 'Refusing operation outside the expected protected non-root role.\n' >&2; exit 2 ;;
  esac
  printf 'Verified protected non-root role for this operation.\n'
}

private_account() {
  aws sts get-caller-identity --query Account --output text
}

write_backend_config() {
  local destination=$1 key=$2 account=$3 state_key_id=$4
  cat >"$destination" <<EOF
bucket       = "${PREFIX}-tfstate-${account}"
key          = "${key}"
region       = "${REGION}"
encrypt      = true
kms_key_id   = "${state_key_id}"
use_lockfile = true
EOF
  chmod 600 "$destination"
}

run_quietly() {
  local operation=$1
  shift
  local error_file
  error_file=$(mktemp)
  if "$@" >/dev/null 2>"$error_file"; then
    rm -f "$error_file"
    printf '%s succeeded.\n' "$operation"
  else
    fail_sanitized "$operation" "$error_file"
  fi
}
