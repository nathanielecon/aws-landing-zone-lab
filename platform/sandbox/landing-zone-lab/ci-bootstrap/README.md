# CI bootstrap (GitHub OIDC)

One-time root in this account. Creates:

- IAM OIDC provider for `token.actions.githubusercontent.com`
- IAM role `project-a-lzlab-gha` for GitHub Actions plan/apply

Default trust pins GitHub **`repository_id=1296742987`** (this repo) and
**`repository_owner_id=177059064`** (`nathanielecon`), with `sub` patterns
`repo:nathanielecon/*:(main|pull_request|cursor/*|environment:lab)` so a GitHub
rename does not brick OIDC. Live AWS resource name prefixes such as
`project-a-lzlab-*` are unchanged.

**Status (2026-07-15):** Live trust on `project-a-lzlab-gha` was restored via
CloudShell to the rename-resilient shape above. Re-apply this directory when
convenient so Terraform state matches IAM.

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

The repo is private — do **not** rely on `curl` from raw.githubusercontent.com.
Paste the contents of [`fix-oidc-trust-cloudshell.sh`](./fix-oidc-trust-cloudshell.sh)
into CloudShell (or clone this branch and run it):

```bash
bash platform/sandbox/landing-zone-lab/ci-bootstrap/fix-oidc-trust-cloudshell.sh
# or: terraform apply in this directory (same trust shape)
```

Inline paste (CloudShell):

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
          "repo:nathanielecon/*:ref:refs/heads/main",
          "repo:nathanielecon/*:pull_request",
          "repo:nathanielecon/*:ref:refs/heads/cursor/*",
          "repo:nathanielecon/*:environment:lab"
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
