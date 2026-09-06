#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/common.sh"
exec 2> >(sanitize_error >&2)

OUT=${1:?private output directory required}
mkdir -p "$OUT"
require_role "${PREFIX}-gha"

ACCOUNT=$(private_account)
STATE_BUCKET="${PREFIX}-tfstate-${ACCOUNT}"
STATE_SNAPSHOT=$(mktemp)
trap 'rm -f "$STATE_SNAPSHOT"' EXIT
OIDC_ARN=$(aws iam list-open-id-connect-providers --query \
  'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn | [0]' \
  --output text)
OLD_ROLE="${PREFIX}-gha"
TEARDOWN_ROLE="${PREFIX}-teardown"
TEARDOWN_ROLE_ARN="arn:aws:iam::${ACCOUNT}:role/${TEARDOWN_ROLE}"
OLD_ROLE_ARN="arn:aws:iam::${ACCOUNT}:role/${OLD_ROLE}"

if [[ -z "$OIDC_ARN" || "$OIDC_ARN" == "None" ]]; then
  printf 'Expected account-wide GitHub OIDC provider was not found.\n' >&2
  exit 1
fi

cat >"$OUT/teardown-trust.json" <<EOF
{"Version":"2012-10-17","Statement":[{"Sid":"ProtectedGitHubEnvironment","Effect":"Allow","Principal":{"Federated":"${OIDC_ARN}"},"Action":"sts:AssumeRoleWithWebIdentity","Condition":{"StringEquals":{"token.actions.githubusercontent.com:aud":"sts.amazonaws.com","token.actions.githubusercontent.com:repository_id":"1296742987","token.actions.githubusercontent.com:repository_owner_id":"177059064"},"StringLike":{"token.actions.githubusercontent.com:sub":"repo:nathanielecon@177059064/*@1296742987:environment:lab-teardown"}}}]}
EOF

cat >"$OUT/lab-trust.json" <<EOF
{"Version":"2012-10-17","Statement":[{"Sid":"ProtectedGitHubEnvironment","Effect":"Allow","Principal":{"Federated":"${OIDC_ARN}"},"Action":"sts:AssumeRoleWithWebIdentity","Condition":{"StringEquals":{"token.actions.githubusercontent.com:aud":"sts.amazonaws.com","token.actions.githubusercontent.com:repository_id":"1296742987","token.actions.githubusercontent.com:repository_owner_id":"177059064"},"StringLike":{"token.actions.githubusercontent.com:sub":"repo:nathanielecon@177059064/*@1296742987:environment:lab"}}}]}
EOF

aws ec2 describe-regions --all-regions --query \
  'Regions[?OptInStatus!=`not-opted-in`].RegionName' --output json >"$OUT/regions.json"

# Live inventory is authoritative for extant resources, but Terraform can still
# need delete permissions for state-owned objects that disappeared or stopped
# matching their tags between inventory and apply. Include only the exact EC2
# resources recorded in the lab state so a partial destroy can be resumed
# without introducing wildcard write access.
aws s3api get-object --bucket "$STATE_BUCKET" \
  --key lab/landing-zone-lab.tfstate "$STATE_SNAPSHOT" >/dev/null
jq --arg partition aws --arg region "$REGION" --arg account "$ACCOUNT" '
  [.resources[]? as $resource
   | $resource.instances[]?.attributes as $attributes
   | if $resource.type == "aws_flow_log" then
       ($attributes.arn // "arn:\($partition):ec2:\($region):\($account):vpc-flow-log/\($attributes.id)")
     elif $resource.type == "aws_route_table" then
       "arn:\($partition):ec2:\($region):\($account):route-table/\($attributes.id)"
     elif $resource.type == "aws_route_table_association" then
       "arn:\($partition):ec2:\($region):\($account):subnet/\($attributes.subnet_id)"
     elif $resource.type == "aws_subnet" then
       "arn:\($partition):ec2:\($region):\($account):subnet/\($attributes.id)"
     elif $resource.type == "aws_security_group" then
       "arn:\($partition):ec2:\($region):\($account):security-group/\($attributes.id)"
     elif $resource.type == "aws_vpc" then
       "arn:\($partition):ec2:\($region):\($account):vpc/\($attributes.id)"
     else empty end] | unique' "$STATE_SNAPSHOT" >"$OUT/state-ec2-resources.json"

printf '[]\n' >"$OUT/ec2-resources.json"
printf '[]\n' >"$OUT/trail-resources.json"
while IFS= read -r region; do
  aws ec2 describe-vpcs --region "$region" --filters Name=tag:Project,Values=project-a \
    --query 'Vpcs[].VpcId' --output json >"$OUT/vpcs.json"
  aws ec2 describe-subnets --region "$region" --filters Name=tag:Project,Values=project-a \
    --query 'Subnets[].SubnetId' --output json >"$OUT/subnets.json"
  aws ec2 describe-route-tables --region "$region" --filters Name=tag:Project,Values=project-a \
    --query 'RouteTables[].RouteTableId' --output json >"$OUT/routes.json"
  aws ec2 describe-security-groups --region "$region" --filters Name=tag:Project,Values=project-a \
    --query 'SecurityGroups[].GroupId' --output json >"$OUT/groups.json"
  aws ec2 describe-flow-logs --region "$region" --filter Name=tag:Project,Values=project-a \
    --query 'FlowLogs[].FlowLogId' --output json >"$OUT/flows.json"
  jq -s --arg partition aws --arg region "$region" --arg account "$ACCOUNT" \
    '.[0] + ([.[1][] | "arn:\($partition):ec2:\($region):\($account):vpc/\(.)"]) +
     ([.[2][] | "arn:\($partition):ec2:\($region):\($account):subnet/\(.)"]) +
     ([.[3][] | "arn:\($partition):ec2:\($region):\($account):route-table/\(.)"]) +
     ([.[4][] | "arn:\($partition):ec2:\($region):\($account):security-group/\(.)"]) +
     ([.[5][] | "arn:\($partition):ec2:\($region):\($account):vpc-flow-log/\(.)"]) | unique' \
    "$OUT/ec2-resources.json" "$OUT/vpcs.json" "$OUT/subnets.json" \
    "$OUT/routes.json" "$OUT/groups.json" "$OUT/flows.json" >"$OUT/ec2-resources.next.json"
  mv "$OUT/ec2-resources.next.json" "$OUT/ec2-resources.json"

  aws cloudtrail describe-trails --region "$region" --no-include-shadow-trails \
    --query "trailList[?starts_with(Name, '${PREFIX}-')].TrailARN" --output json \
    >"$OUT/trails.json"
  jq -s 'add | unique' "$OUT/trail-resources.json" "$OUT/trails.json" \
    >"$OUT/trail-resources.next.json"
  mv "$OUT/trail-resources.next.json" "$OUT/trail-resources.json"
done < <(jq -r '.[]' "$OUT/regions.json")
jq -s 'add | unique' "$OUT/ec2-resources.json" "$OUT/state-ec2-resources.json" \
  >"$OUT/ec2-resources.next.json"
mv "$OUT/ec2-resources.next.json" "$OUT/ec2-resources.json"

aws iam list-roles --query \
  "Roles[?starts_with(RoleName, '${PREFIX}-') || starts_with(RoleName, 'workload-audit-')].Arn" \
  --output json >"$OUT/role-resources.json"
aws iam list-users --query "Users[?starts_with(UserName, '${PREFIX}-')].Arn" \
  --output json >"$OUT/user-resources.json"
aws iam list-policies --scope Local --query \
  "Policies[?starts_with(PolicyName, '${PREFIX}-') || starts_with(PolicyName, 'workload-audit-')].Arn" \
  --output json >"$OUT/policy-resources.json"

printf '[]\n' >"$OUT/instance-profile-resources.json"
while IFS= read -r role_arn; do
  role_name=${role_arn##*/}
  aws iam list-instance-profiles-for-role --role-name "$role_name" \
    --query 'InstanceProfiles[].Arn' --output json >"$OUT/instance-profiles.json"
  jq -s 'add | unique' "$OUT/instance-profile-resources.json" \
    "$OUT/instance-profiles.json" >"$OUT/instance-profile-resources.next.json"
  mv "$OUT/instance-profile-resources.next.json" "$OUT/instance-profile-resources.json"
done < <(jq -r '.[]' "$OUT/role-resources.json")

printf '[]\n' >"$OUT/group-resources.json"
while IFS= read -r user_arn; do
  user_name=${user_arn##*/}
  aws iam list-groups-for-user --user-name "$user_name" \
    --query 'Groups[].Arn' --output json >"$OUT/user-groups.json"
  jq -s 'add | unique' "$OUT/group-resources.json" "$OUT/user-groups.json" \
    >"$OUT/group-resources.next.json"
  mv "$OUT/group-resources.next.json" "$OUT/group-resources.json"
done < <(jq -r '.[]' "$OUT/user-resources.json")

ARCHIVE_BUCKET="${PREFIX}-archive-${ACCOUNT}"
AUDIT_KEY=$(aws kms list-aliases --region "$REGION" --query \
  "Aliases[?AliasName=='alias/${PREFIX}-audit'].TargetKeyId | [0]" --output text)
STATE_KEY=$(aws kms list-aliases --region "$REGION" --query \
  "Aliases[?AliasName=='alias/${PREFIX}-tfstate'].TargetKeyId | [0]" --output text)
if [[ "$AUDIT_KEY" == "None" || "$STATE_KEY" == "None" ]]; then
  printf 'Expected retained KMS aliases are unavailable.\n' >&2
  exit 1
fi
printf '["arn:aws:kms:%s:%s:key/%s","arn:aws:kms:%s:%s:key/%s","arn:aws:kms:%s:%s:alias/%s-audit","arn:aws:kms:%s:%s:alias/%s-tfstate"]\n' \
  "$REGION" "$ACCOUNT" "$AUDIT_KEY" "$REGION" "$ACCOUNT" "$STATE_KEY" \
  "$REGION" "$ACCOUNT" "$PREFIX" "$REGION" "$ACCOUNT" "$PREFIX" \
  >"$OUT/kms-resources.json"

jq -n \
  --arg old_role "$OLD_ROLE_ARN" \
  --arg teardown_role "$TEARDOWN_ROLE_ARN" \
  --arg oidc "$OIDC_ARN" \
  --arg account "$ACCOUNT" \
  --arg archive_bucket "arn:aws:s3:::${ARCHIVE_BUCKET}" \
  --arg state_bucket "arn:aws:s3:::${STATE_BUCKET}" \
  --slurpfile ec2 "$OUT/ec2-resources.json" \
  --slurpfile trails "$OUT/trail-resources.json" \
  --slurpfile roles "$OUT/role-resources.json" \
  --slurpfile users "$OUT/user-resources.json" \
  --slurpfile policies "$OUT/policy-resources.json" \
  --slurpfile instance_profiles "$OUT/instance-profile-resources.json" \
  --slurpfile groups "$OUT/group-resources.json" \
  --slurpfile keys "$OUT/kms-resources.json" \
  '{Version:"2012-10-17",Statement:[
    {Sid:"IdentityAndInventoryRead",Effect:"Allow",Action:[
      "sts:GetCallerIdentity","ce:GetCostAndUsage","ec2:DescribeAvailabilityZones","ec2:DescribeFlowLogs",
      "ec2:DescribeNetworkAcls","ec2:DescribeNetworkInterfaces","ec2:DescribeRegions","ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroupRules","ec2:DescribeSecurityGroups","ec2:DescribeSubnets","ec2:DescribeTags",
      "ec2:DescribeVpcAttribute","ec2:DescribeVpcs",
      "cloudtrail:DescribeTrails","cloudtrail:ListChannels","cloudtrail:ListTrails",
      "config:DescribeConfigurationRecorderStatus","config:DescribeConfigurationRecorders",
      "config:DescribeDeliveryChannelStatus","config:DescribeDeliveryChannels",
      "iam:ListOpenIDConnectProviders","iam:ListPolicies","iam:ListRoles","iam:ListUsers","kms:ListAliases"
    ],Resource:"*"},
    {Sid:"ReadInventoriedTrails",Effect:"Allow",Action:[
      "cloudtrail:GetEventSelectors","cloudtrail:GetInsightSelectors","cloudtrail:GetTrail",
      "cloudtrail:GetTrailStatus","cloudtrail:ListTags"
    ],Resource:$trails[0]},
    {Sid:"ReadInventoriedIam",Effect:"Allow",Action:[
      "iam:GetPolicy","iam:GetPolicyVersion","iam:GetRole","iam:GetRolePolicy","iam:GetUser",
      "iam:ListAttachedRolePolicies","iam:ListAttachedUserPolicies","iam:ListEntitiesForPolicy",
      "iam:ListGroupsForUser","iam:ListInstanceProfilesForRole","iam:ListPolicyTags","iam:ListPolicyVersions",
      "iam:ListRolePolicies","iam:ListRoleTags","iam:ListUserPolicies","iam:ListUserTags"
    ],Resource:(($roles[0]+$users[0]+$policies[0]+[$old_role,$teardown_role])|unique)},
    {Sid:"ReadPreservedOidcProvider",Effect:"Allow",Action:"iam:GetOpenIDConnectProvider",Resource:$oidc},
    {Sid:"DeleteInventoriedFlowLogs",Effect:"Allow",Action:"ec2:DeleteFlowLogs",
      Resource:([$ec2[0][] | select(contains(":vpc-flow-log/"))] | unique)},
    {Sid:"DeleteInventoriedRouteTables",Effect:"Allow",Action:"ec2:DeleteRouteTable",
      Resource:([$ec2[0][] | select(contains(":route-table/"))] | unique)},
    {Sid:"DisassociateInventoriedRouteTables",Effect:"Allow",Action:"ec2:DisassociateRouteTable",
      Resource:([$ec2[0][] | select(contains(":route-table/") or contains(":subnet/"))] | unique)},
    {Sid:"DeleteInventoriedSecurityGroups",Effect:"Allow",Action:"ec2:DeleteSecurityGroup",
      Resource:([$ec2[0][] | select(contains(":security-group/"))] | unique)},
    {Sid:"DeleteInventoriedSubnets",Effect:"Allow",Action:"ec2:DeleteSubnet",
      Resource:([$ec2[0][] | select(contains(":subnet/"))] | unique)},
    {Sid:"DeleteInventoriedVpcs",Effect:"Allow",Action:"ec2:DeleteVpc",
      Resource:([$ec2[0][] | select(contains(":vpc/"))] | unique)},
    {Sid:"DeleteInventoriedTrails",Effect:"Allow",Action:["cloudtrail:DeleteTrail","cloudtrail:StopLogging"],Resource:$trails[0]},
    {Sid:"RetireConfig",Effect:"Allow",Action:["config:DeleteConfigurationRecorder","config:DeleteDeliveryChannel","config:StopConfigurationRecorder"],Resource:"*"},
    {Sid:"RetireInventoriedPolicies",Effect:"Allow",
      Action:["iam:DeletePolicy","iam:DeletePolicyVersion"],Resource:($policies[0]|unique)},
    {Sid:"RetireInventoriedRoles",Effect:"Allow",Action:[
      "iam:DeleteRole","iam:DeleteRolePermissionsBoundary","iam:DeleteRolePolicy","iam:DetachRolePolicy"
    ],Resource:(($roles[0]+[$old_role,$teardown_role])|unique)},
    {Sid:"RetireInventoriedUsers",Effect:"Allow",Action:[
      "iam:DeleteUser","iam:DeleteUserPermissionsBoundary","iam:DeleteUserPolicy",
      "iam:DeleteLoginProfile","iam:DetachUserPolicy"
    ],Resource:($users[0]|unique)},
    {Sid:"DetachInventoriedInstanceProfiles",Effect:"Allow",
      Action:"iam:RemoveRoleFromInstanceProfile",Resource:($instance_profiles[0]|unique)},
    {Sid:"RemoveInventoriedGroupMemberships",Effect:"Allow",
      Action:"iam:RemoveUserFromGroup",Resource:($groups[0]|unique)},
    {Sid:"ReadRetainedBuckets",Effect:"Allow",Action:[
      "s3:GetAccelerateConfiguration","s3:GetBucketAcl","s3:GetBucketCORS","s3:GetBucketLocation",
      "s3:GetBucketLogging","s3:GetBucketObjectLockConfiguration","s3:GetBucketPolicy",
      "s3:GetBucketNotification","s3:GetBucketOwnershipControls","s3:GetBucketPolicyStatus",
      "s3:GetBucketPublicAccessBlock","s3:GetBucketRequestPayment","s3:GetBucketTagging",
      "s3:GetBucketVersioning","s3:GetBucketWebsite","s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration","s3:GetReplicationConfiguration","s3:ListBucket","s3:ListBucketVersions"
    ],Resource:[$archive_bucket,$state_bucket]},
    {Sid:"UseStateObjects",Effect:"Allow",Action:["s3:DeleteObject","s3:GetObject","s3:PutObject"],Resource:[
      $state_bucket+"/lab/landing-zone-lab.tfstate",$state_bucket+"/lab/landing-zone-lab.tfstate.tflock",
      $state_bucket+"/retained-evidence/terraform.tfstate",$state_bucket+"/retained-evidence/terraform.tfstate.tflock"
    ]},
    {Sid:"ReadAndUseRetainedKeys",Effect:"Allow",Action:[
      "kms:Decrypt","kms:DescribeKey","kms:Encrypt","kms:GenerateDataKey","kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus","kms:ListResourceTags"
    ],Resource:$keys[0]},
    {Sid:"ProtectRetainedEvidence",Effect:"Deny",Action:[
      "kms:DeleteAlias","kms:DisableKey","kms:ScheduleKeyDeletion","s3:DeleteBucket","s3:DeleteBucketPolicy"
    ],Resource:(([$archive_bucket,$state_bucket]+$keys[0])|unique)}
  ] | map(select((.Resource|type)!="array" or (.Resource|length)>0))}' >"$OUT/teardown-policy.json"

# Validate every action name against AWS's machine-readable Service
# Authorization Reference before the policy can be created.
mkdir -p "$OUT/sar"
jq -r '[.Statement[].Action] | flatten | .[]' "$OUT/teardown-policy.json" | sort -u \
  >"$OUT/policy-actions.txt"
for prefix in sts ce ec2 cloudtrail config iam kms s3; do
  curl --fail --silent --show-error \
    "https://servicereference.us-east-1.amazonaws.com/v1/${prefix}/${prefix}.json" \
    -o "$OUT/sar/${prefix}.json"
done
while IFS=: read -r prefix action; do
  action=${action%$'\r'}
  jq -e --arg action "$action" '.Actions[].Name | select(. == $action)' \
    "$OUT/sar/${prefix}.json" >/dev/null || {
      printf 'Policy action failed Service Authorization Reference validation: %s:%s.\n' \
        "$prefix" "$action" >&2
      exit 1
    }
done <"$OUT/policy-actions.txt"
printf 'Every policy action passed the AWS Service Authorization Reference check.\n'

# Simulation is read-only. The API caps each policy input at 2,000 characters,
# so evaluate every exact generated statement independently against its exact
# resource set, assert that every action reaches the statement's intended
# decision, and retain all raw results in the private artifact.
STATEMENT_COUNT=$(jq '.Statement | length' "$OUT/teardown-policy.json")
for ((index=0; index<STATEMENT_COUNT; index++)); do
  chunk=$((index + 1))
  jq -c --argjson index "$index" \
    '{Version:"2012-10-17",Statement:[.Statement[$index]]}' \
    "$OUT/teardown-policy.json" >"$OUT/policy-statement-${chunk}.json"
  if [[ $(wc -c <"$OUT/policy-statement-${chunk}.json") -gt 2000 ]]; then
    printf 'Generated policy statement exceeds the simulation API limit.\n' >&2
    exit 1
  fi
  mapfile -t ACTIONS < <(jq -r '.Statement[0].Action | if type=="array" then .[] else . end' \
    "$OUT/policy-statement-${chunk}.json")
  mapfile -t RESOURCES < <(jq -r '.Statement[0].Resource | if type=="array" then .[] else . end' \
    "$OUT/policy-statement-${chunk}.json")
  EFFECT=$(jq -r '.Statement[0].Effect' "$OUT/policy-statement-${chunk}.json")
  if [[ "$EFFECT" == "Allow" ]]; then
    EXPECTED_DECISION=allowed
  elif [[ "$EFFECT" == "Deny" ]]; then
    EXPECTED_DECISION=explicitDeny
  else
    printf 'Generated policy statement has an unsupported effect.\n' >&2
    exit 1
  fi

  SIMULATION_ARGS=(
    --policy-input-list "$(<"$OUT/policy-statement-${chunk}.json")"
    --action-names "${ACTIONS[@]}"
  )
  if (( ${#RESOURCES[@]} != 1 )) || [[ "${RESOURCES[0]}" != "*" ]]; then
    SIMULATION_ARGS+=(--resource-arns "${RESOURCES[@]}")
  fi
  aws iam simulate-custom-policy "${SIMULATION_ARGS[@]}" --output json \
    >"$OUT/policy-simulation-${chunk}.json"

  jq -e --arg expected "$EXPECTED_DECISION" \
    --slurpfile statement "$OUT/policy-statement-${chunk}.json" '
      . as $simulation
      | ($statement[0].Statement[0].Action
          | if type == "array" then . else [.] end) as $actions
      | all($actions[];
          . as $action
          | any($simulation.EvaluationResults[];
              .EvalActionName == $action and .EvalDecision == $expected))
    ' "$OUT/policy-simulation-${chunk}.json" >/dev/null || {
      printf 'Policy statement %s failed exact-resource simulation.\n' "$chunk" >&2
      exit 1
    }
done
printf 'Exact generated teardown policy simulation passed.\n'

if aws iam get-role --role-name "$TEARDOWN_ROLE" >/dev/null 2>&1; then
  run_quietly "Update dedicated teardown role trust" aws iam update-assume-role-policy \
    --role-name "$TEARDOWN_ROLE" --policy-document "file://$OUT/teardown-trust.json"
else
  run_quietly "Create dedicated teardown role" aws iam create-role \
    --role-name "$TEARDOWN_ROLE" --description "Short-lived Project A retirement role" \
    --assume-role-policy-document "file://$OUT/teardown-trust.json" \
    --tags Key=Project,Value=project-a Key=Purpose,Value=retirement
fi
run_quietly "Attach exact generated teardown policy" aws iam put-role-policy \
  --role-name "$TEARDOWN_ROLE" --policy-name ProjectARetirement \
  --policy-document "file://$OUT/teardown-policy.json"
run_quietly "Narrow legacy role trust to the protected lab environment" \
  aws iam update-assume-role-policy --role-name "$OLD_ROLE" \
  --policy-document "file://$OUT/lab-trust.json"

jq -n --arg role_arn "$TEARDOWN_ROLE_ARN" \
  --argjson inventory_regions "$(jq length "$OUT/regions.json")" \
  '{teardown_role_arn:$role_arn,enabled_region_count:$inventory_regions,policy_action_count:0}' \
  >"$OUT/bootstrap-result.json"
jq --argjson count "$(wc -l <"$OUT/policy-actions.txt")" '.policy_action_count=$count' \
  "$OUT/bootstrap-result.json" >"$OUT/bootstrap-result.next.json"
mv "$OUT/bootstrap-result.next.json" "$OUT/bootstrap-result.json"
find "$OUT" -type f -exec chmod 600 {} +
printf 'Bootstrap complete: dedicated environment-only role created; legacy trust narrowed.\n'
