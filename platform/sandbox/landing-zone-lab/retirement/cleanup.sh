#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/common.sh"
exec 2> >(sanitize_error >&2)
require_role "${PREFIX}-teardown"

delete_user() {
  local user=$1
  aws iam get-user --user-name "$user" >/dev/null 2>&1 || return 0
  mapfile -t policies < <(aws iam list-attached-user-policies --user-name "$user" --query 'AttachedPolicies[].PolicyArn' --output text | tr '\t' '\n')
  for policy in "${policies[@]}"; do [[ -z "$policy" ]] || aws iam detach-user-policy --user-name "$user" --policy-arn "$policy" >/dev/null; done
  mapfile -t inline < <(aws iam list-user-policies --user-name "$user" --query 'PolicyNames[]' --output text | tr '\t' '\n')
  for policy in "${inline[@]}"; do [[ -z "$policy" ]] || aws iam delete-user-policy --user-name "$user" --policy-name "$policy" >/dev/null; done
  aws iam delete-login-profile --user-name "$user" >/dev/null 2>&1 || true
  aws iam delete-user-permissions-boundary --user-name "$user" >/dev/null 2>&1 || true
  run_quietly "Delete Project A operator user" aws iam delete-user --user-name "$user"
}

delete_role() {
  local role=$1
  aws iam get-role --role-name "$role" >/dev/null 2>&1 || return 0
  mapfile -t policies < <(aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text | tr '\t' '\n')
  for policy in "${policies[@]}"; do [[ -z "$policy" ]] || aws iam detach-role-policy --role-name "$role" --policy-arn "$policy" >/dev/null; done
  mapfile -t inline < <(aws iam list-role-policies --role-name "$role" --query 'PolicyNames[]' --output text | tr '\t' '\n')
  for policy in "${inline[@]}"; do [[ -z "$policy" ]] || aws iam delete-role-policy --role-name "$role" --policy-name "$policy" >/dev/null; done
  aws iam delete-role-permissions-boundary --role-name "$role" >/dev/null 2>&1 || true
  run_quietly "Delete Project A role" aws iam delete-role --role-name "$role"
}

delete_managed_policy() {
  local arn=$1
  aws iam get-policy --policy-arn "$arn" >/dev/null 2>&1 || return 0
  mapfile -t versions < <(aws iam list-policy-versions --policy-arn "$arn" \
    --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text | tr '\t' '\n')
  for version in "${versions[@]}"; do [[ -z "$version" ]] || aws iam delete-policy-version --policy-arn "$arn" --version-id "$version" >/dev/null; done
  run_quietly "Delete Project A managed policy" aws iam delete-policy --policy-arn "$arn"
}

mapfile -t users < <(aws iam list-users --query \
  "Users[?starts_with(UserName, '${PREFIX}-')].UserName" --output text | tr '\t' '\n')
for user in "${users[@]}"; do [[ -z "$user" ]] || delete_user "$user"; done

mapfile -t roles < <(aws iam list-roles --query \
  "Roles[?(starts_with(RoleName, '${PREFIX}-') || starts_with(RoleName, 'workload-audit-')) && RoleName!='${PREFIX}-teardown'].RoleName" \
  --output text | tr '\t' '\n')
for role in "${roles[@]}"; do [[ -z "$role" ]] || delete_role "$role"; done

mapfile -t policies < <(aws iam list-policies --scope Local --query \
  "Policies[?starts_with(PolicyName, '${PREFIX}-') || starts_with(PolicyName, 'workload-audit-')].Arn" \
  --output text | tr '\t' '\n')
for policy in "${policies[@]}"; do [[ -z "$policy" ]] || delete_managed_policy "$policy"; done

# Delete the short-lived role last. Current STS credentials remain valid long
# enough for the job to finish, while no principal can start another session.
aws iam delete-role-policy --role-name "${PREFIX}-teardown" \
  --policy-name ProjectARetirement >/dev/null
aws iam delete-role --role-name "${PREFIX}-teardown" >/dev/null
printf 'Removed Project A operator, legacy CI, and short-lived teardown IAM. OIDC provider preserved.\n'
