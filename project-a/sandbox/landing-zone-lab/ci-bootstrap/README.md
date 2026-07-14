# CI bootstrap (GitHub OIDC)

One-time root in this account. Creates:

- IAM OIDC provider for `token.actions.githubusercontent.com`
- IAM role `project-a-lzlab-gha` for GitHub Actions plan/apply

## Apply once (local break-glass)

```powershell
cd project-a/sandbox/landing-zone-lab/ci-bootstrap
terraform init -backend=false -input=false
terraform apply -input=false -auto-approve
terraform output gha_role_arn
```

Then set the repo variable `AWS_ROLE_ARN_LZ_LAB` to that ARN (or rely on the
workflow default if it matches).

The lab root **reads** this OIDC provider via a data source; it does not create
a second one.
