# CI bootstrap (GitHub OIDC)

One-time root in this account. Creates:

- IAM OIDC provider for `token.actions.githubusercontent.com`
- IAM role `project-a-lzlab-gha` for GitHub Actions plan/apply

Default trust pins GitHub **`repository_id=1296742987`** (this repo) and
**`repository_owner_id=177059064`** (`nathanielecon`).

**Important (2026-07-15+):** GitHub renames adopt **immutable subject claims**:
`repo:OWNER@OWNER_ID/REPO@REPO_ID:...`. Name-only `repo:OWNER/REPO:...` subs no
longer match. Trust uses:

`repo:nathanielecon@177059064/*@1296742987:(main|pull_request|cursor/*|environment:lab)`

Live AWS resource name prefixes such as `project-a-lzlab-*` are unchanged.

## Apply once (local break-glass)

```powershell
cd platform/sandbox/landing-zone-lab/ci-bootstrap
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve
terraform output gha_role_arn
```

Then set the repo variable `AWS_ROLE_ARN_LZ_LAB` to that ARN (or rely on the
workflow default if it matches).

## After renaming GitHub (OIDC outage)

If Actions fails at **Configure AWS credentials (OIDC)** after a rename,
self-heal from GHA cannot run (needs the role). Fix in **AWS CloudShell**
(Linux paths — do not use `C:\...`), account `283077380808`.

```bash
bash platform/sandbox/landing-zone-lab/ci-bootstrap/fix-oidc-trust-cloudshell.sh
# or: terraform apply in this directory (same trust shape)
```

Inline paste (CloudShell) — immutable `sub` format:

```bash
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
OIDC_ARN="arn:aws:iam::${ACCOUNT}:oidc-provider/token.actions.githubusercontent.com"
cat > /tmp/trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "GitHubActionsOidc",
    "Effect": "Allow",
    "Principal": { "Federated": "${OIDC_ARN}" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:repository_id": "1296742987",
        "token.actions.githubusercontent.com:repository_owner_id": "177059064"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": [
          "repo:nathanielecon@177059064/*@1296742987:ref:refs/heads/main",
          "repo:nathanielecon@177059064/*@1296742987:pull_request",
          "repo:nathanielecon@177059064/*@1296742987:ref:refs/heads/cursor/*",
          "repo:nathanielecon@177059064/*@1296742987:environment:lab"
        ]
      }
    }
  }]
}
EOF
aws iam update-assume-role-policy --role-name project-a-lzlab-gha \
  --policy-document file:///tmp/trust.json
aws iam get-role --role-name project-a-lzlab-gha \
  --query 'Role.AssumeRolePolicyDocument' --output json
```

Then dispatch **Landing Zone lab (Terraform)** → `plan` and confirm the OIDC
step is green. Cloud Agents do **not** hold apply credentials for this step.

The lab root **reads** this OIDC provider via a data source; it does not create
a second one.
<!-- oidc-verify 2026-07-15T21:37:32Z -->
