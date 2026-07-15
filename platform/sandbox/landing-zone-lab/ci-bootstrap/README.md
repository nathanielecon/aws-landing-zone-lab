# CI bootstrap (GitHub OIDC)

One-time root in this account. Creates:

- IAM OIDC provider for `token.actions.githubusercontent.com`
- IAM role `project-a-lzlab-gha` for GitHub Actions plan/apply

Default trust is for repository **`nathanielecon/aws-landing-zone-lab`**
(`github_repository` variable). Live AWS resource name prefixes such as
`project-a-lzlab-*` are unchanged.

## Apply once (local break-glass)

```powershell
cd platform/sandbox/landing-zone-lab/ci-bootstrap
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve
terraform output gha_role_arn
```

Then set the repo variable `AWS_ROLE_ARN_LZ_LAB` to that ARN (or rely on the
workflow default if it matches).

## After renaming GitHub `cloud` → `aws-landing-zone-lab`

OIDC `sub` trust is repo-name specific. Re-apply this root so the role accepts
tokens from the new repository (and remove the old `cloud` subjects if Terraform
replaces the trust policy):

```powershell
cd platform/sandbox/landing-zone-lab/ci-bootstrap
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve \
  -var="github_repository=aws-landing-zone-lab"
```

Cloud Agents do **not** hold apply credentials for this step.

The lab root **reads** this OIDC provider via a data source; it does not create
a second one.
