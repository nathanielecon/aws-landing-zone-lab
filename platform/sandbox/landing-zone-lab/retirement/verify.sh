#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/common.sh"
exec 2> >(sanitize_error >&2)

OUT=${1:?private output directory required}
mkdir -p "$OUT/regions"
require_role "${PREFIX}-teardown"
ACCOUNT=$(private_account)
STATE_BUCKET="${PREFIX}-tfstate-${ACCOUNT}"
ARCHIVE_BUCKET="${PREFIX}-archive-${ACCOUNT}"

aws ec2 describe-regions --all-regions --query \
  'Regions[?OptInStatus!=`not-opted-in`].RegionName' --output json >"$OUT/enabled-regions.json"
FAILED=0
while IFS= read -r region; do
  region_out="$OUT/regions/$region.json"
  vpcs=$(aws ec2 describe-vpcs --region "$region" --filters Name=tag:Project,Values=project-a --query 'length(Vpcs)' --output text)
  subnets=$(aws ec2 describe-subnets --region "$region" --filters Name=tag:Project,Values=project-a --query 'length(Subnets)' --output text)
  routes=$(aws ec2 describe-route-tables --region "$region" --filters Name=tag:Project,Values=project-a --query 'length(RouteTables)' --output text)
  groups=$(aws ec2 describe-security-groups --region "$region" --filters Name=tag:Project,Values=project-a --query 'length(SecurityGroups)' --output text)
  flows=$(aws ec2 describe-flow-logs --region "$region" --filter Name=tag:Project,Values=project-a --query 'length(FlowLogs)' --output text)
  trails=$(aws cloudtrail describe-trails --region "$region" --no-include-shadow-trails \
    --query "length(trailList[?starts_with(Name, '${PREFIX}-')])" --output text)
  recorders=$(aws configservice describe-configuration-recorders --region "$region" \
    --query "length(ConfigurationRecorders[?starts_with(name, '${PREFIX}-')])" --output text)
  channels=$(aws configservice describe-delivery-channels --region "$region" \
    --query "length(DeliveryChannels[?starts_with(name, '${PREFIX}-')])" --output text)
  jq -n --argjson vpcs "$vpcs" --argjson subnets "$subnets" --argjson routes "$routes" \
    --argjson groups "$groups" --argjson flows "$flows" --argjson trails "$trails" \
    --argjson recorders "$recorders" --argjson channels "$channels" \
    '{vpcs:$vpcs,subnets:$subnets,route_tables:$routes,security_groups:$groups,flow_logs:$flows,trails:$trails,config_recorders:$recorders,config_channels:$channels}' \
    >"$region_out"
  if jq -e 'any(.[]; . != 0)' "$region_out" >/dev/null; then FAILED=1; fi
done < <(jq -r '.[]' "$OUT/enabled-regions.json")

aws s3api head-bucket --bucket "$ARCHIVE_BUCKET" >/dev/null
aws s3api head-bucket --bucket "$STATE_BUCKET" >/dev/null
aws s3api get-bucket-lifecycle-configuration --bucket "$ARCHIVE_BUCKET" \
  --output json >"$OUT/archive-lifecycle.json"
jq -e '.Rules[] | select(.Status=="Enabled" and .Expiration.Days==90 and .NoncurrentVersionExpiration.NoncurrentDays==90)' \
  "$OUT/archive-lifecycle.json" >/dev/null
aws s3api head-object --bucket "$STATE_BUCKET" --key "$LAB_STATE_KEY" >/dev/null
aws s3api head-object --bucket "$STATE_BUCKET" --key "$RETAINED_STATE_KEY" >/dev/null

for alias in "alias/${PREFIX}-audit" "alias/${PREFIX}-tfstate"; do
  key=$(aws kms list-aliases --region "$REGION" --query \
    "Aliases[?AliasName=='${alias}'].TargetKeyId | [0]" --output text)
  [[ "$key" != "None" ]] || { printf 'Expected retained KMS alias is absent.\n' >&2; exit 1; }
  aws kms describe-key --region "$REGION" --key-id "$key" --query 'KeyMetadata.KeyState' \
    --output text >"$OUT/$(basename "$alias")-state.txt"
  grep -qx Enabled "$OUT/$(basename "$alias")-state.txt"
done

START=$(date -u -d '30 days ago' +%F)
END=$(date -u -d 'tomorrow' +%F)
aws ce get-cost-and-usage --time-period "Start=$START,End=$END" --granularity DAILY \
  --metrics UnblendedCost --group-by Type=DIMENSION,Key=SERVICE \
  --output json >"$OUT/cost-after-teardown-pending-lag.json"

jq -n --argjson regions "$(jq length "$OUT/enabled-regions.json")" \
  --argjson clear "$((1-FAILED))" \
  '{enabled_regions_checked:$regions,lab_resources_absent:($clear==1),retained_archive_readable:true,retained_state_readable:true,retained_lifecycle_days:90,cost_comparison_status:"pending Cost Explorer reporting delay"}' \
  >"$OUT/verification-summary.json"
find "$OUT" -type f -exec chmod 600 {} +
[[ $FAILED -eq 0 ]] || { printf 'One or more enabled regions still contains a Project A resource.\n' >&2; exit 1; }
printf 'Verified all enabled regions clear; retained S3/KMS evidence remains readable.\n'
