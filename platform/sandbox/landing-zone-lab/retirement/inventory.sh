#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/common.sh"
exec 2> >(sanitize_error >&2)

OUT=${1:?private output directory required}
mkdir -p "$OUT/regions"

require_role "${PREFIX}-gha"

aws sts get-caller-identity --output json >"$OUT/caller.json"
ACCOUNT=$(jq -r .Account "$OUT/caller.json")
STATE_BUCKET="project-a-lzlab-tfstate-${ACCOUNT}"
STATE_KEY="lab/landing-zone-lab.tfstate"

aws ec2 describe-regions --all-regions \
  --query 'Regions[?OptInStatus!=`not-opted-in`].[RegionName,OptInStatus]' \
  --output json >"$OUT/enabled-regions.json"

mapfile -t REGIONS < <(jq -r '.[][0]' "$OUT/enabled-regions.json")
for region in "${REGIONS[@]}"; do
  region_dir="$OUT/regions/$region"
  mkdir -p "$region_dir"

  aws ec2 describe-vpcs --region "$region" \
    --filters Name=tag:Project,Values=project-a --output json >"$region_dir/vpcs.json"
  jq -r '.Vpcs[].VpcId' "$region_dir/vpcs.json" >"$region_dir/vpc-ids.txt"

  aws ec2 describe-subnets --region "$region" \
    --filters Name=tag:Project,Values=project-a --output json >"$region_dir/subnets.json"
  aws ec2 describe-route-tables --region "$region" \
    --filters Name=tag:Project,Values=project-a --output json >"$region_dir/route-tables.json"
  aws ec2 describe-security-groups --region "$region" \
    --filters Name=tag:Project,Values=project-a --output json >"$region_dir/security-groups.json"

  if [[ -s "$region_dir/vpc-ids.txt" ]]; then
    mapfile -t VPC_IDS <"$region_dir/vpc-ids.txt"
    aws ec2 describe-flow-logs --region "$region" \
      --filter "Name=resource-id,Values=$(IFS=,; echo "${VPC_IDS[*]}")" \
      --output json >"$region_dir/flow-logs.json"
  else
    printf '{"FlowLogs":[]}\n' >"$region_dir/flow-logs.json"
  fi

  aws cloudtrail describe-trails --region "$region" --no-include-shadow-trails \
    --output json >"$region_dir/trails.json"
  aws configservice describe-configuration-recorders --region "$region" \
    --output json >"$region_dir/config-recorders.json"
  aws configservice describe-delivery-channels --region "$region" \
    --output json >"$region_dir/config-channels.json"
done

aws s3api list-buckets --query \
  'Buckets[?starts_with(Name, `project-a-lzlab-`)]' --output json >"$OUT/s3-buckets.json"
aws kms list-aliases --region us-east-1 --query \
  'Aliases[?starts_with(AliasName, `alias/project-a-lzlab-`)]' \
  --output json >"$OUT/kms-aliases.json"
aws iam list-roles --query \
  'Roles[?starts_with(RoleName, `project-a-lzlab-`) || starts_with(RoleName, `workload-audit-`)]' \
  --output json >"$OUT/iam-roles.json"
aws iam list-users --query \
  'Users[?starts_with(UserName, `project-a-lzlab-`)]' \
  --output json >"$OUT/iam-users.json"
aws iam list-policies --scope Local --query \
  'Policies[?starts_with(PolicyName, `project-a-lzlab-`) || starts_with(PolicyName, `workload-audit-`)]' \
  --output json >"$OUT/iam-policies.json"

if ! aws s3api head-object --bucket "$STATE_BUCKET" --key "$STATE_KEY" >/dev/null 2>&1; then
  echo "Expected Terraform state object is unavailable." >&2
  exit 1
fi
aws s3api get-object --bucket "$STATE_BUCKET" --key "$STATE_KEY" \
  "$OUT/landing-zone-lab.tfstate" >/dev/null
aws s3api list-object-versions --bucket "$STATE_BUCKET" --prefix "$STATE_KEY" \
  --output json >"$OUT/state-object-versions.json"

if aws ce get-cost-and-usage --time-period \
  "Start=$(date -u -d '30 days ago' +%F),End=$(date -u -d 'tomorrow' +%F)" \
  --granularity DAILY --metrics UnblendedCost --group-by Type=DIMENSION,Key=SERVICE \
  --output json >"$OUT/cost-baseline.json" 2>"$OUT/cost-baseline-error.txt"; then
  rm -f "$OUT/cost-baseline-error.txt"
else
  printf '{"status":"not-authorized","required_action":"ce:GetCostAndUsage"}\n' \
    >"$OUT/cost-baseline.json"
  sed -E 's/[0-9]{12}/<AWS_ACCOUNT_ID>/g; s/arn:aws[^ ]+/<AWS_ARN>/g' \
    "$OUT/cost-baseline-error.txt" >"$OUT/cost-baseline-error.sanitized.txt"
  rm -f "$OUT/cost-baseline-error.txt"
fi

jq -n \
  --arg captured_at "$(date -u +%FT%TZ)" \
  --arg state_sha256 "$(sha256sum "$OUT/landing-zone-lab.tfstate" | cut -d' ' -f1)" \
  --argjson region_count "${#REGIONS[@]}" \
  '{captured_at:$captured_at, enabled_region_count:$region_count, state_sha256:$state_sha256}' \
  >"$OUT/manifest.json"

find "$OUT" -type f -exec chmod 600 {} +
echo "Private inventory captured for ${#REGIONS[@]} enabled regions; live identifiers withheld from logs."
