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
STATE_KEY=$(aws kms list-aliases --region "$REGION" --query \
  "Aliases[?AliasName=='alias/${PREFIX}-tfstate'].TargetKeyId | [0]" --output text)
[[ "$STATE_KEY" != "None" ]] || { printf 'Retained state KMS alias is unavailable.\n' >&2; exit 1; }
aws s3api head-object --bucket "$STATE_BUCKET" --key "$RETAINED_STATE_KEY" >/dev/null

write_backend_config "$OUT/lab.backend.hcl" "$LAB_STATE_KEY" "$ACCOUNT" "$STATE_KEY"
write_backend_config "$OUT/retained.backend.hcl" "$RETAINED_STATE_KEY" "$ACCOUNT" "$STATE_KEY"

export TF_DATA_DIR="$RUNNER_TEMP/project-a-retained-tfdata"
run_quietly "Initialize retained-evidence state" terraform -chdir="$RETAINED_ROOT" init -reconfigure \
  -backend-config="$OUT/retained.backend.hcl" -input=false -lockfile=readonly
set +e
terraform -chdir="$RETAINED_ROOT" plan -detailed-exitcode -no-color \
  -out="$OUT/retained.plan" >"$OUT/retained-plan.txt" 2>"$OUT/retained-plan.err"
RETAINED_EXIT=$?
set -e
[[ $RETAINED_EXIT -eq 0 ]] || {
  printf 'Retained-evidence root is not zero-change; teardown refused.\n' >&2
  exit 1
}
printf 'Retained-evidence zero-change gate passed.\n'

export TF_DATA_DIR="$RUNNER_TEMP/project-a-lab-tfdata"
run_quietly "Initialize remaining lab state" terraform -chdir="$LAB_ROOT" init -reconfigure \
  -backend-config="$OUT/lab.backend.hcl" -input=false -lockfile=readonly
terraform -chdir="$LAB_ROOT" state pull >"$OUT/lab-pre-destroy.tfstate"
run_quietly "Create final constrained destruction plan" terraform -chdir="$LAB_ROOT" plan \
  -destroy -input=false -no-color -out="$OUT/lab-destroy.plan"
terraform -chdir="$LAB_ROOT" show -json "$OUT/lab-destroy.plan" >"$OUT/lab-destroy-plan.json"
jq '[.resource_changes[]? | {mode,type,address,actions:.change.actions}]' \
  "$OUT/lab-destroy-plan.json" >"$OUT/lab-destroy-summary.json"
if jq -e 'any(.[]; (.actions | any(. == "create" or . == "update")))' \
  "$OUT/lab-destroy-summary.json" >/dev/null; then
  printf 'Final lab plan contains a non-delete action; teardown refused.\n' >&2
  exit 1
fi
if jq -e 'any(.[]; .address | test("aws_s3_bucket|aws_kms_key|aws_kms_alias"))' \
  "$OUT/lab-destroy-summary.json" >/dev/null; then
  printf 'Final lab plan contains a retained S3/KMS resource; teardown refused.\n' >&2
  exit 1
fi

run_quietly "Destroy Terraform-owned lab writers and infrastructure" terraform \
  -chdir="$LAB_ROOT" apply -input=false -auto-approve "$OUT/lab-destroy.plan"

# Remove any prefixed superseded trail that was not present in current state.
aws ec2 describe-regions --all-regions --query \
  'Regions[?OptInStatus!=`not-opted-in`].RegionName' --output text | tr '\t' '\n' >"$OUT/regions.txt"
while IFS= read -r region; do
  mapfile -t trails < <(aws cloudtrail describe-trails --region "$region" \
    --no-include-shadow-trails --query "trailList[?starts_with(Name, '${PREFIX}-')].Name" --output text | tr '\t' '\n')
  for trail in "${trails[@]}"; do
    [[ -n "$trail" ]] || continue
    aws cloudtrail stop-logging --region "$region" --name "$trail" >/dev/null 2>&1 || true
    run_quietly "Delete superseded Project A trail" aws cloudtrail delete-trail \
      --region "$region" --name "$trail"
  done
done <"$OUT/regions.txt"

find "$OUT" -type f -exec chmod 600 {} +
printf 'Project A billable lab infrastructure and authorized writers were removed.\n'
