#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/common.sh"
exec 2> >(sanitize_error >&2)

OUT=${1:?private output directory required}
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
LAB_ROOT="$REPO_ROOT/platform/sandbox/landing-zone-lab/lab"
RETAINED_ROOT="$REPO_ROOT/platform/sandbox/landing-zone-lab/retained-evidence"
mkdir -p "$OUT"
require_role "${PREFIX}-teardown"

ACCOUNT=$(private_account)
STATE_BUCKET="${PREFIX}-tfstate-${ACCOUNT}"
ARCHIVE_BUCKET="${PREFIX}-archive-${ACCOUNT}"
AUDIT_KEY=$(aws kms list-aliases --region "$REGION" --query \
  "Aliases[?AliasName=='alias/${PREFIX}-audit'].TargetKeyId | [0]" --output text)
STATE_KEY=$(aws kms list-aliases --region "$REGION" --query \
  "Aliases[?AliasName=='alias/${PREFIX}-tfstate'].TargetKeyId | [0]" --output text)
[[ "$AUDIT_KEY" != "None" && "$STATE_KEY" != "None" ]] || {
  printf 'Retained KMS aliases are unavailable; no state operation attempted.\n' >&2
  exit 1
}

write_backend_config "$OUT/lab.backend.hcl" "$LAB_STATE_KEY" "$ACCOUNT" "$STATE_KEY"
write_backend_config "$OUT/retained.backend.hcl" "$RETAINED_STATE_KEY" "$ACCOUNT" "$STATE_KEY"

export TF_DATA_DIR="$RUNNER_TEMP/project-a-lab-tfdata"
run_quietly "Initialize lab state" terraform -chdir="$LAB_ROOT" init -reconfigure \
  -backend-config="$OUT/lab.backend.hcl" -input=false -lockfile=readonly
terraform -chdir="$LAB_ROOT" state pull >"$OUT/lab-before.tfstate"

export TF_DATA_DIR="$RUNNER_TEMP/project-a-retained-tfdata"
run_quietly "Initialize retained-evidence state" terraform -chdir="$RETAINED_ROOT" init -reconfigure \
  -backend-config="$OUT/retained.backend.hcl" -input=false -lockfile=readonly

import_if_missing() {
  local address=$1 import_id=$2
  if terraform -chdir="$RETAINED_ROOT" state show "$address" >/dev/null 2>&1; then
    printf 'Retained state already owns %s.\n' "$address"
  else
    run_quietly "Import $address" terraform -chdir="$RETAINED_ROOT" import \
      -input=false "$address" "$import_id"
  fi
}

import_if_missing aws_s3_bucket.archive "$ARCHIVE_BUCKET"
import_if_missing aws_s3_bucket_versioning.archive "$ARCHIVE_BUCKET"
import_if_missing aws_s3_bucket_server_side_encryption_configuration.archive "$ARCHIVE_BUCKET"
import_if_missing aws_s3_bucket_public_access_block.archive "$ARCHIVE_BUCKET"
import_if_missing aws_s3_bucket_lifecycle_configuration.archive "$ARCHIVE_BUCKET"
import_if_missing aws_s3_bucket_policy.archive "$ARCHIVE_BUCKET"
import_if_missing aws_kms_key.audit "$AUDIT_KEY"
import_if_missing aws_kms_alias.audit "alias/${PREFIX}-audit"
import_if_missing aws_s3_bucket.state "$STATE_BUCKET"
import_if_missing aws_s3_bucket_versioning.state "$STATE_BUCKET"
import_if_missing aws_s3_bucket_server_side_encryption_configuration.state "$STATE_BUCKET"
import_if_missing aws_s3_bucket_public_access_block.state "$STATE_BUCKET"
import_if_missing aws_s3_bucket_ownership_controls.state "$STATE_BUCKET"
import_if_missing aws_kms_key.state "$STATE_KEY"
import_if_missing aws_kms_alias.state "alias/${PREFIX}-tfstate"

set +e
terraform -chdir="$RETAINED_ROOT" plan -detailed-exitcode -no-color \
  -out="$OUT/retained.plan" >"$OUT/retained-plan.txt" 2>"$OUT/retained-plan.err"
PLAN_EXIT=$?
set -e
if [[ $PLAN_EXIT -ne 0 ]]; then
  if [[ $PLAN_EXIT -eq 2 ]]; then
    printf 'Retained-evidence plan is not zero-change; lab state ownership was not removed.\n' >&2
    jq -n '{zero_change:false}' >"$OUT/retained-plan-summary.json"
    exit 1
  fi
  fail_sanitized "Retained-evidence plan" "$OUT/retained-plan.err"
fi
jq -n '{zero_change:true}' >"$OUT/retained-plan-summary.json"
terraform -chdir="$RETAINED_ROOT" state pull >"$OUT/retained-after-import.tfstate"
printf 'Retained-evidence state produced the required zero-change plan.\n'

export TF_DATA_DIR="$RUNNER_TEMP/project-a-lab-tfdata"
for address in \
  module.audit.aws_s3_bucket.archive \
  module.audit.aws_s3_bucket_versioning.archive \
  module.audit.aws_s3_bucket_server_side_encryption_configuration.archive \
  module.audit.aws_s3_bucket_public_access_block.archive \
  module.audit.aws_s3_bucket_lifecycle_configuration.archive \
  module.audit.aws_s3_bucket_policy.archive \
  module.audit.aws_kms_key.audit \
  module.audit.aws_kms_alias.audit; do
  if terraform -chdir="$LAB_ROOT" state show "$address" >/dev/null 2>&1; then
    run_quietly "Transfer ownership of $address" terraform -chdir="$LAB_ROOT" state rm "$address"
  fi
done
terraform -chdir="$LAB_ROOT" state pull >"$OUT/lab-after-transfer.tfstate"

run_quietly "Create constrained lab destruction plan" terraform -chdir="$LAB_ROOT" plan \
  -destroy -input=false -no-color -out="$OUT/lab-destroy.plan"
terraform -chdir="$LAB_ROOT" show -json "$OUT/lab-destroy.plan" >"$OUT/lab-destroy-plan.json"
jq '[.resource_changes[]? | {mode,type,address,actions:.change.actions}]' \
  "$OUT/lab-destroy-plan.json" >"$OUT/lab-destroy-summary.json"
if jq -e 'any(.[]; (.actions | any(. == "create" or . == "update")))' \
  "$OUT/lab-destroy-summary.json" >/dev/null; then
  printf 'Constrained lab plan contains a non-delete action.\n' >&2
  exit 1
fi
if jq -e 'any(.[]; .address | test("aws_s3_bucket|aws_kms_key|aws_kms_alias"))' \
  "$OUT/lab-destroy-summary.json" >/dev/null; then
  printf 'Constrained lab plan unexpectedly includes a retained S3/KMS resource.\n' >&2
  exit 1
fi

find "$OUT" -type f -exec chmod 600 {} +
printf 'State transfer complete: retained root is zero-change; lab plan is delete-only.\n'
